import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/models/json_fields.dart';
import 'package:megrim/models/med_entry.dart';
import 'package:megrim/services/export_service.dart';
import 'package:megrim/services/import_service.dart';

MegrimDatabase freshDb() => MegrimDatabase.forTesting(NativeDatabase.memory());

Future<void> seed(MegrimDatabase db) async {
  await db.setSetting('home_location',
      jsonEncode({'lat': 39.96, 'lon': -105.05, 'label': 'Boulder'}));

  final now = DateTime.utc(2024, 6, 1, 8, 30);
  await db.into(db.migraineEvents).insert(MigraineEventsCompanion.insert(
        id: 'evt-1',
        startedAt: DateTime.utc(2024, 6, 1, 9),
        endedAt: Value(DateTime.utc(2024, 6, 1, 13)),
        severity: const Value(7),
        locationHead: Value(encodeStringList(['Left temple', 'Forehead'])),
        auraPresent: const Value(true),
        auraDescription: const Value('shimmering'),
        medsTaken: Value(encodeMeds([
          const MedEntry(name: 'Sumatriptan', dose: '50mg', helped: true),
        ])),
        triggersSuspected: Value(encodeStringList(['Stress', 'Caffeine'])),
        sleepHoursPrior: const Value(5.5),
        stressLevel: const Value(4),
        foodsNotable: Value(encodeStringList(['Cheese'])),
        notes: const Value('rough one, with a comma, and "quotes"'),
        geoLat: const Value(39.96),
        geoLon: const Value(-105.05),
        geoLabel: const Value('Boulder'),
        createdAt: now,
        updatedAt: now,
      ));
  await db.into(db.derivedFactors).insert(DerivedFactorsCompanion(
        eventId: const Value('evt-1'),
        dayOfWeek: const Value(5),
        season: const Value('Summer'),
        timeOfDayBucket: const Value('morning'),
        daylightHours: const Value(14.9),
        sunriseUtc: Value(DateTime.utc(2024, 6, 1, 11, 32)),
        sunsetUtc: Value(DateTime.utc(2024, 6, 2, 2, 28)),
        moonPhase: const Value('Waning Crescent'),
        moonIllumination: const Value(0.12),
        tempC: const Value(22.5),
        humidityPct: const Value(40),
        pressureHpa: const Value(1012.3),
        precipitationMm: const Value(0),
        pressureDelta24h: const Value(-6.2),
        pressureDelta48h: const Value(-3.1),
        aqi: const Value(35),
        enrichedAt: Value(now),
      ));

  // A second event with almost everything null (ongoing, no derived).
  await db.into(db.migraineEvents).insert(MigraineEventsCompanion.insert(
        id: 'evt-2',
        startedAt: DateTime.utc(2024, 6, 10, 22),
        createdAt: now,
        updatedAt: now,
      ));
}

/// Export map with the volatile export timestamp removed, for identity comparison.
Future<Map<String, dynamic>> stableExport(MegrimDatabase db) async {
  final m = await ExportService(db: db).buildExport();
  m.remove('exported_at');
  return m;
}

void main() {
  test('round-trip: DB -> JSON -> fresh DB is identity', () async {
    final src = freshDb();
    await seed(src);
    final json = await ExportService(db: src).toJsonString();
    final before = await stableExport(src);

    final dst = freshDb();
    final result = await ImportService(dst).importJsonString(json, replace: true);
    expect(result.imported, 2);

    final after = await stableExport(dst);
    expect(jsonEncode(after), jsonEncode(before));

    await src.close();
    await dst.close();
  });

  test('merge skips events whose id already exists', () async {
    final src = freshDb();
    await seed(src);
    final json = await ExportService(db: src).toJsonString();

    final dst = freshDb();
    await ImportService(dst).importJsonString(json); // first import (merge)
    final second =
        await ImportService(dst).importJsonString(json); // again
    expect(second.imported, 0);
    expect(second.skipped, 2);
    expect(await dst.select(dst.migraineEvents).get(), hasLength(2));

    await src.close();
    await dst.close();
  });

  test('replace wipes existing data first', () async {
    final src = freshDb();
    await seed(src);
    final json = await ExportService(db: src).toJsonString();

    final dst = freshDb();
    await dst.into(dst.migraineEvents).insert(MigraineEventsCompanion.insert(
          id: 'stale',
          startedAt: DateTime.utc(2020, 1, 1),
          createdAt: DateTime.utc(2020, 1, 1),
          updatedAt: DateTime.utc(2020, 1, 1),
        ));
    await ImportService(dst).importJsonString(json, replace: true);
    final ids =
        (await dst.select(dst.migraineEvents).map((e) => e.id).get()).toSet();
    expect(ids, {'evt-1', 'evt-2'});

    await src.close();
    await dst.close();
  });

  test('rejects wrong format and unsupported version', () async {
    final db = freshDb();
    final svc = ImportService(db);
    expect(() => svc.importJson({'format': 'nope', 'format_version': 1}),
        throwsA(isA<ImportException>()));
    expect(
        () => svc.importJson(
            {'format': 'megrim-export', 'format_version': 999, 'events': []}),
        throwsA(isA<ImportException>()));
    await db.close();
  });

  test('CSV export has a header row and one row per event', () async {
    final db = freshDb();
    await seed(db);
    final csv = await ExportService(db: db).toCsv();
    final lines = csv.trim().split('\n');
    expect(lines.first, startsWith('id,started_at,ended_at'));
    expect(lines, hasLength(3)); // header + 2 events
    // The notes field with commas/quotes is RFC-4180 escaped.
    expect(csv, contains('"rough one, with a comma, and ""quotes"""'));
    await db.close();
  });
}
