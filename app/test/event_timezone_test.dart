import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/analytics/correlations.dart';
import 'package:megrim/analytics/dashboard.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/models/event_time.dart';
import 'package:megrim/repositories/megrim_repository.dart';
import 'package:megrim/screens/event_detail_screen.dart';
import 'package:megrim/screens/history_screen.dart';
import 'package:megrim/services/export_service.dart';
import 'package:megrim/services/import_service.dart';

/// Issue #17: an event belongs to the zone it was logged in. These tests run under both TZ=UTC and
/// TZ=America/Denver in CI and must give identical answers — that is the whole point.
///
/// Reference event: 18:00Z on 2024-06-10 logged at UTC+9 (Tokyo) is Tuesday 2024-06-11 03:00
/// there. In Denver it is Monday 12:00; in London Monday 19:00.
final tokyo = DateTime.utc(2024, 6, 10, 18);
const tokyoOffset = 9 * 60;

void main() {
  group('wall-clock helpers', () {
    test('wallClock/wallDate read the event in its own zone', () {
      final w = wallClock(tokyo, tokyoOffset);
      expect([w.year, w.month, w.day, w.hour, w.weekday], [2024, 6, 11, 3, DateTime.tuesday]);
      expect(wallDate(tokyo, tokyoOffset), DateTime(2024, 6, 11));
    });
    test('null offset is the phone zone (pre-v2 behaviour)', () {
      expect(wallDate(tokyo, null), DateTime(tokyo.toLocal().year, tokyo.toLocal().month, tokyo.toLocal().day));
    });
    test('instantOf inverts wallClockNaive', () {
      final naive = wallClockNaive(tokyo, tokyoOffset);
      expect(naive, DateTime(2024, 6, 11, 3, 0));
      expect(instantOf(naive, tokyoOffset), tokyo);
      expect(instantOf(DateTime(2024, 1, 1, 8, 30), -7 * 60), DateTime.utc(2024, 1, 1, 15, 30));
    });
  });

  group('analytics bucket by the event zone regardless of the phone zone', () {
    test('correlations: the migraine-day is the Tokyo date', () {
      // Five Tokyo-logged events on consecutive days, all 18:00Z = 03:00 next day in Tokyo.
      final starts = [for (var i = 0; i < 5; i++) tokyo.add(Duration(days: i))];
      final r = computeCorrelations(
        eventStarts: starts,
        startOffsets: List.filled(5, tokyoOffset),
        homeLat: 35.7,
        homeLon: 139.7,
      );
      // Tokyo dates: Tue 11 .. Sat 15 June → one migraine-day each on Tue/Wed/Thu/Fri/Sat, none Mon.
      final dow = {for (final row in r.factors['Day of week']!) row.bucket: row.migraineDays};
      expect(dow['Mon'], anyOf(isNull, 0));
      expect(dow['Tue'], 1);
      expect(dow['Sat'], 1);
      expect(r.totalMigraineDays, 5);
      expect(r.totalDaysInRange, 5);
    });
    test('dashboard: by-year and summary dates follow the event zone', () {
      // 2023-12-31 20:00Z at UTC+9 is 2024-01-01 05:00 → counts in 2024.
      final ny = DateTime.utc(2023, 12, 31, 20);
      final d = computeDashboard([
        EventStat(startedAt: ny, severity: 4, startOffsetMin: tokyoOffset),
        EventStat(startedAt: ny.add(const Duration(days: 40)), severity: 6, startOffsetMin: tokyoOffset),
      ]);
      expect(d.byYear.map((y) => '${y.year}:${y.count}'), ['2024:2']);
      expect(d.summary.firstEvent, DateTime(2024, 1, 1));
      expect(d.calendar.first.date, DateTime(2024, 1, 1));
    });
    test('History calendar days come from the event zone', () {
      final e = MigraineEvent(
        id: 'x',
        startedAt: tokyo,
        endedAt: tokyo.add(const Duration(hours: 2)),
        startedAtOffsetMin: tokyoOffset,
        endedAtOffsetMin: tokyoOffset,
        createdAt: tokyo,
        updatedAt: tokyo,
      );
      expect(localDaysSpanned(e), [DateTime(2024, 6, 11)]);
    });
  });

  group('storage, export and import', () {
    late MegrimDatabase db;
    late MegrimRepository repo;
    setUp(() {
      db = MegrimDatabase.forTesting(NativeDatabase.memory());
      repo = MegrimRepository(db: db);
    });
    tearDown(() => db.close());

    test('live start/end capture the phone offset', () async {
      final id = await repo.startEvent();
      await repo.endEvent(id);
      final e = (await repo.getEvent(id))!;
      expect(e.startedAtOffsetMin, offsetMinutesOf());
      expect(e.endedAtOffsetMin, offsetMinutesOf());
    });

    test('offsets round-trip through JSON and CSV; import honours an explicit ISO offset', () async {
      await db.into(db.migraineEvents).insert(MigraineEventsCompanion.insert(
          id: 'tk', startedAt: tokyo, startedAtOffsetMin: const Value(tokyoOffset), createdAt: tokyo, updatedAt: tokyo));
      final json = await ExportService(db: db).toJsonString();
      final ev = (jsonDecode(json)['events'] as List).single as Map<String, dynamic>;
      expect(ev['started_at_offset_minutes'], tokyoOffset);
      expect(ev['ended_at_offset_minutes'], isNull);
      final csv = await ExportService(db: db).toCsv();
      expect(csv.split('\n').first, endsWith('started_at_offset_minutes,ended_at_offset_minutes'));

      final dst = MegrimDatabase.forTesting(NativeDatabase.memory());
      await ImportService(dst).importJsonString(json, replace: true);
      expect((await dst.select(dst.migraineEvents).get()).single.startedAtOffsetMin, tokyoOffset);

      // An external file with no offset field but an explicit +09:00 in the timestamp.
      final external = jsonEncode({
        'format': 'megrim-export', 'format_version': 1,
        'events': [
          {'id': 'ext1', 'started_at': '2024-06-11T03:00:00+09:00'},
          {'id': 'ext2', 'started_at': '2024-06-11T03:00:00Z'},
          {'id': 'ext3', 'started_at': '2024-06-11T03:00:00-06:30'},
        ],
      });
      await ImportService(dst).importJsonString(external, replace: true);
      final rows = {for (final e in await dst.select(dst.migraineEvents).get()) e.id: e};
      expect(rows['ext1']!.startedAtOffsetMin, 540);
      expect(rows['ext1']!.startedAt.toUtc(), tokyo);
      expect(rows['ext2']!.startedAtOffsetMin, isNull);
      expect(rows['ext3']!.startedAtOffsetMin, -390);
      await dst.close();
    });

    test('the analytics export block says how days were bucketed', () async {
      final block = await repo.analyticsForExport();
      expect(block['bucketing'], 'event-offset');
    });
  });

  test('schema v1 → v2 migration adds the columns and keeps rows', () async {
    final dir = Directory.systemTemp.createTempSync('megrim-mig');
    final file = File('${dir.path}/v1.sqlite');
    // Build a v2 database, then demote it to v1 by hand (SQLite ≥ 3.35 DROP COLUMN).
    final v2 = MegrimDatabase.forTesting(NativeDatabase(file));
    await v2.into(v2.migraineEvents).insert(MigraineEventsCompanion.insert(
        id: 'old', startedAt: tokyo, createdAt: tokyo, updatedAt: tokyo));
    await v2.customStatement('ALTER TABLE migraine_events DROP COLUMN started_at_offset_min');
    await v2.customStatement('ALTER TABLE migraine_events DROP COLUMN ended_at_offset_min');
    await v2.customStatement('PRAGMA user_version = 1');
    await v2.setSetting('schema_version', '1');
    await v2.close();

    final upgraded = MegrimDatabase.forTesting(NativeDatabase(file));
    final old = (await upgraded.select(upgraded.migraineEvents).get()).single;
    expect(old.id, 'old');
    expect(old.startedAtOffsetMin, isNull, reason: 'pre-v2 rows stay unpinned');
    await upgraded.into(upgraded.migraineEvents).insert(MigraineEventsCompanion.insert(
        id: 'new', startedAt: tokyo, startedAtOffsetMin: const Value(tokyoOffset), createdAt: tokyo, updatedAt: tokyo));
    expect((await upgraded.getSetting('schema_version')), '2');
    await upgraded.close();
    dir.deleteSync(recursive: true);
  });

  testWidgets('Event Detail shows and keeps the entry in its own zone', (tester) async {
    final db = MegrimDatabase.forTesting(NativeDatabase.memory());
    final repo = MegrimRepository(db: db);
    await db.into(db.migraineEvents).insert(MigraineEventsCompanion.insert(
        id: 'tk', startedAt: tokyo, endedAt: Value(tokyo.add(const Duration(hours: 2))),
        startedAtOffsetMin: const Value(tokyoOffset), endedAtOffsetMin: const Value(tokyoOffset),
        createdAt: tokyo, updatedAt: tokyo));
    await tester.pumpWidget(MaterialApp(home: EventDetailScreen(repo: repo, eventId: 'tk')));
    await tester.pumpAndSettle();
    // Tokyo wall clock, whatever zone the test host is in.
    expect(find.text('Tue 11 Jun 2024, 03:00'), findsOneWidget);
    expect(find.text('Tue 11 Jun 2024, 05:00'), findsOneWidget);

    // Saving untouched keeps the instant and the zone.
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();
    final e = (await repo.getEvent('tk'))!;
    expect(e.startedAt.toUtc(), tokyo);
    expect(e.startedAtOffsetMin, tokyoOffset);
    expect(e.endedAtOffsetMin, tokyoOffset);
    await db.close();
  });
}
