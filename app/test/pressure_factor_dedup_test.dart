import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:megrim/analytics/pressure_baseline.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/repositories/megrim_repository.dart';

MegrimDatabase freshDb() => MegrimDatabase.forTesting(NativeDatabase.memory());

Future<void> _insertEvent(
    MegrimDatabase db, String id, DateTime startedAtUtc, double? delta) async {
  await db.into(db.migraineEvents).insert(MigraineEventsCompanion.insert(
        id: id,
        startedAt: startedAtUtc,
        createdAt: startedAtUtc,
        updatedAt: startedAtUtc,
      ));
  await db.into(db.derivedFactors).insert(DerivedFactorsCompanion(
        eventId: Value(id),
        pressureDelta24h: Value(delta),
        enrichedAt: Value(delta != null ? startedAtUtc : null),
      ));
}

void main() {
  test('pressure factor counts one delta per migraine day, not per event',
      () async {
    final db = freshDb();
    await db.setSetting('home_location',
        jsonEncode({'lat': 40.0, 'lon': -105.0, 'label': 'Home'}));

    // Day 2024-06-01: two events, deltas fall in DIFFERENT buckets. The earlier event (08:00)
    // must be the one that counts; the later one (18:00) must be dropped by the dedup.
    await _insertEvent(db, 'd1a', DateTime.utc(2024, 6, 1, 8), -8); // '-10 to -5'
    await _insertEvent(db, 'd1b', DateTime.utc(2024, 6, 1, 18), 8); // '5 to 10'
    // A migraine day with no pressure data at all: counts toward totalMigraine, contributes
    // nothing to any pressure bucket.
    await _insertEvent(db, 'd2', DateTime.utc(2024, 6, 2, 12), null);
    // Three more distinct migraine days, one delta each, each in its own bucket.
    await _insertEvent(db, 'd3', DateTime.utc(2024, 6, 3, 12), 2); // '0 to 5'
    await _insertEvent(db, 'd4', DateTime.utc(2024, 6, 4, 12), -3); // '-5 to 0'
    await _insertEvent(db, 'd5', DateTime.utc(2024, 6, 5, 12), 12); // '> 10'

    // Pre-seed the cached baseline (matching repo.correlations()'s exact tag) so getOrBuild
    // returns it without any network call.
    final tag =
        pressureBaselineTag(DateTime(2024, 6, 1), DateTime(2024, 6, 5), 40.0, -105.0);
    const baselineHist = {
      '< -10': 3,
      '-10 to -5': 5,
      '-5 to 0': 6,
      '0 to 5': 6,
      '5 to 10': 5,
      '> 10': 3,
    };
    await db.setSetting(
        'pressure_baseline', jsonEncode(PressureBaseline(tag, baselineHist).toJson()));

    final baselineService = PressureBaselineService(
      db: db,
      httpClient: MockClient((req) async =>
          throw StateError('network should not be hit: the cache should already match')),
    );

    final repo = MegrimRepository(db: db);
    final corr = await repo.correlations(baselineService: baselineService);

    expect(corr.available, isTrue);
    final rows = corr.factors['Pressure Δ 24h (hPa)'];
    expect(rows, isNotNull);

    final summedMigraineDays = rows!.fold<int>(0, (s, r) => s + r.migraineDays);
    // 4 distinct migraine days carried pressure data (the 2024-06-01 duplicate collapses to one);
    // pre-fix (one delta per event) this would sum to 5.
    expect(summedMigraineDays, 4);
    for (final r in rows) {
      expect(r.migraineDays, lessThanOrEqualTo(r.totalDays));
    }

    await db.close();
  });
}
