import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/analytics/checkins.dart';
import 'package:megrim/analytics/correlations.dart' show oddsRatio;
import 'package:megrim/analytics/dashboard.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/models/json_fields.dart';
import 'package:megrim/repositories/megrim_repository.dart';
import 'package:megrim/services/export_service.dart';
import 'package:megrim/services/import_service.dart';

/// Backlog #16: "No migraine today" check-ins (schema v6), days tracked, and the self-reported
/// factors compared between migraine days and clear days.

/// "Today" for the counting tests.
final now = DateTime(2026, 10, 30, 12);

DateTime day(int month, int d) => DateTime(2026, month, d);

/// A 3-hour attack starting at 10:00 local on [d].
EventStat attack(
  DateTime d, {
  List<String> triggers = const [],
  double? sleep,
  int? stress,
  int hours = 3,
}) => EventStat(
  startedAt: DateTime(d.year, d.month, d.day, 10).toUtc(),
  endedAt: DateTime(d.year, d.month, d.day, 10 + hours).toUtc(),
  triggers: triggers,
  sleepHoursPrior: sleep,
  stressLevel: stress,
);

void main() {
  group('schema v6', () {
    test('v5 -> v6 creates the table and keeps rows', () async {
      final dir = Directory.systemTemp.createTempSync('megrim-v6');
      final file = File('${dir.path}/v5.sqlite');
      final t0 = DateTime.utc(2026, 10, 1, 9);
      final cur = MegrimDatabase.forTesting(NativeDatabase(file));
      await cur
          .into(cur.migraineEvents)
          .insert(
            MigraineEventsCompanion.insert(
              id: 'old',
              startedAt: t0,
              severity: const Value(6),
              createdAt: t0,
              updatedAt: t0,
            ),
          );
      await cur.customStatement('DROP TABLE day_checkins');
      await cur.customStatement('PRAGMA user_version = 5');
      await cur.close();

      final upgraded = MegrimDatabase.forTesting(NativeDatabase(file));
      expect((await upgraded.select(upgraded.migraineEvents).get()).single.severity, 6);
      expect(await upgraded.select(upgraded.dayCheckins).get(), isEmpty);
      expect(await upgraded.getSetting('schema_version'), '6');
      await upgraded.close();
      dir.deleteSync(recursive: true);
    });
  });

  group('repository', () {
    late MegrimDatabase db;
    late MegrimRepository repo;
    setUp(() {
      db = MegrimDatabase.forTesting(NativeDatabase.memory());
      repo = MegrimRepository(db: db);
    });
    tearDown(() => db.close());

    test('check in, add details, check in again keeps them, remove and restore', () async {
      await repo.checkIn(day(10, 5));
      var c = (await repo.checkinOn(day(10, 5)))!;
      expect(c.localDate, '2026-10-05');
      expect(c.offsetMin, DateTime(2026, 10, 5, 12).timeZoneOffset.inMinutes);
      expect(c.triggersSuspected, isNull);

      await repo.saveCheckinDetails(
        day(10, 5),
        triggers: ['Stress'],
        sleepHours: 6.5,
        stress: 4,
        foods: ['Cheese'],
      );
      await repo.checkIn(day(10, 5));
      c = (await repo.checkinOn(day(10, 5)))!;
      expect(decodeStringList(c.triggersSuspected), ['Stress']);
      expect(c.sleepHoursPrior, 6.5);
      expect(c.stressLevel, 4);

      final removed = await repo.removeCheckin(day(10, 5));
      expect(await repo.checkinOn(day(10, 5)), isNull);
      await repo.restoreCheckins([removed!]);
      expect((await repo.checkinOn(day(10, 5)))!.stressLevel, 4);
    });

    test('an entry removes the check-ins on the days it covers', () async {
      for (final d in [4, 5, 6, 7]) {
        await repo.checkIn(day(10, d));
      }
      final id = await repo.insertEvent(
        MigraineEventsCompanion(
          startedAt: Value(DateTime(2026, 10, 5, 22).toUtc()),
          endedAt: Value(DateTime(2026, 10, 6, 8).toUtc()),
        ),
      );
      final removed = await repo.removeCheckinsCoveredBy(id);
      expect(removed.map((r) => r.localDate), unorderedEquals(['2026-10-05', '2026-10-06']));
      expect(
        (await repo.checkins()).map((r) => r.localDate),
        unorderedEquals(['2026-10-04', '2026-10-07']),
      );
    });

    test('export and import round-trip; merge keeps existing dates', () async {
      await repo.saveCheckinDetails(day(10, 5), triggers: ['Stress'], sleepHours: 7, stress: 2);
      await repo.checkIn(day(10, 6));
      final doc = await ExportService(db: db).buildExport();
      final json = jsonDecode(jsonEncode(doc)) as Map<String, dynamic>;
      expect((json['checkins'] as List).first, containsPair('triggers_suspected', ['Stress']));

      final other = MegrimDatabase.forTesting(NativeDatabase.memory());
      final otherRepo = MegrimRepository(db: other);
      await otherRepo.saveCheckinDetails(day(10, 5), stress: 5);
      await ImportService(other).importJson(json);
      expect(
        (await otherRepo.checkinOn(day(10, 5)))!.stressLevel,
        5,
        reason: 'merge leaves an existing check-in alone',
      );
      expect(await otherRepo.checkinOn(day(10, 6)), isNotNull);

      await ImportService(other).importJson(json, replace: true);
      expect((await otherRepo.checkinOn(day(10, 5)))!.stressLevel, 2);
      expect(await other.select(other.dayCheckins).get(), hasLength(2));
      await other.close();
    });

    test('import drops a check-in without a valid date, and a stress level out of range', () async {
      await ImportService(db).importJson({
        'format': 'megrim-export',
        'format_version': 1,
        'events': [],
        'checkins': [
          {'local_date': 'not a date'},
          {'local_date': '2026-10-05', 'stress_level': 9},
        ],
      });
      final rows = await repo.checkins();
      expect(rows.single.localDate, '2026-10-05');
      expect(rows.single.stressLevel, isNull);
    });
  });

  group('days tracked', () {
    test('null without a check-in', () {
      expect(trackedDays([attack(day(10, 1))], const [], now), isNull);
    });

    test('counts entry days and clear days; an entry wins over a check-in', () {
      final t = trackedDays(
        [attack(day(10, 10)), attack(day(10, 20), hours: 30), attack(day(9, 1))],
        [
          CheckinStat(day: day(10, 10)), // the entry wins
          CheckinStat(day: day(10, 11)),
          CheckinStat(day: day(10, 12)),
          CheckinStat(day: day(9, 15)),
        ],
        now,
      )!;
      // Last 30 days: Oct 1..30. Migraine days 10, 20, 21; clear 11, 12.
      expect(t.migraineLast30, 3);
      expect(t.clearLast30, 2);
      expect(t.last30, 5);
      // Since Sep 15: those 5, plus the Sep 15 check-in; Sep 1 is before the first check-in.
      expect(t.sinceFirstCheckin, 6);
      expect(t.firstCheckin, day(9, 15));
      expect(t.daysSinceFirstCheckin, 46);
    });
  });

  group('tracked factors', () {
    /// One check-in on Aug 1, then [mig] migraine days, then the other [clear] - 1 check-ins, each
    /// with sleep recorded; [migTrigger] / [clearTrigger] of them tagged "Bright light". The
    /// check-in comes first because migraines before the first check-in aren't compared.
    ({List<EventStat> events, List<CheckinStat> checkins}) planted(
      int mig,
      int clear,
      int migTrigger,
      int clearTrigger,
    ) {
      var d = 1;
      final events = <EventStat>[];
      final checkins = <CheckinStat>[
        CheckinStat(
          day: day(8, 1),
          triggers: clearTrigger > 0 ? ['Bright light'] : const [],
          sleepHours: 7,
        ),
      ];
      clear--;
      clearTrigger = clearTrigger > 0 ? clearTrigger - 1 : 0;
      for (var i = 0; i < mig; i++) {
        events.add(
          attack(day(8, 1 + d++), triggers: i < migTrigger ? ['Bright light'] : const [], sleep: 7),
        );
      }
      for (var i = 0; i < clear; i++) {
        checkins.add(
          CheckinStat(
            day: day(8, 1 + d++),
            triggers: i < clearTrigger ? ['Bright light'] : const [],
            sleepHours: 7,
          ),
        );
      }
      return (events: events, checkins: checkins);
    }

    test('hidden until 30 tracked days with 5 migraine and 5 clear days', () {
      var p = planted(5, 24, 5, 0);
      expect(computeTrackedFactors(p.events, p.checkins).available, isFalse);
      p = planted(4, 30, 4, 0);
      final r = computeTrackedFactors(p.events, p.checkins);
      expect(r.available, isFalse);
      expect(r.reason, contains('4 migraine'));
      p = planted(5, 25, 5, 0);
      expect(computeTrackedFactors(p.events, p.checkins).available, isTrue);
    });

    test('the odds ratio matches a hand-built 2×2', () {
      // Bright light: 8 of 10 migraine days, 5 of 40 clear days.
      final p = planted(10, 40, 8, 5);
      final r = computeTrackedFactors(p.events, p.checkins);
      final row = r.factors[kTriggerFactor]!.singleWhere((x) => x.bucket == 'Bright light');
      expect(row.migraineDays, 8);
      expect(row.totalDays, 13);
      final expected = (oddsRatio(8, 2, 5, 35) * 100).round() / 100;
      expect(row.oddsRatio, expected);
      expect(r.topFactors.first.condition, 'Bright light');
    });

    test('migraines before the first check-in are left out', () {
      final p = planted(10, 40, 8, 5);
      final early = [for (var i = 1; i <= 20; i++) attack(day(6, i), sleep: 7)];
      final r = computeTrackedFactors([...early, ...p.events], p.checkins);
      expect(r.migraineDays, 10);
      expect(r.trackedDays, 50);
    });

    test('a bare check-in is tracked but not in the trigger table', () {
      final p = planted(10, 30, 8, 0);
      final bare = [for (var i = 1; i <= 20; i++) CheckinStat(day: day(10, i))];
      final r = computeTrackedFactors(p.events, [...p.checkins, ...bare]);
      expect(r.clearDays, 50);
      final row = r.factors[kTriggerFactor]!.singleWhere((x) => x.bucket == 'Bright light');
      expect(row.totalDays, 8);
      final expected = (oddsRatio(8, 2, 0, 30) * 100).round() / 100;
      expect(row.oddsRatio, expected, reason: '30 recorded clear days, not 50');
    });

    test('day 2 of a multi-day migraine and a check-in on it are left out', () {
      final p = planted(10, 30, 0, 0);
      // An attack Oct 1 10:00 to Oct 2 13:00, and a check-in on Oct 2.
      final long = attack(day(10, 1), hours: 27);
      final r = computeTrackedFactors(
        [...p.events, long],
        [...p.checkins, CheckinStat(day: day(10, 2))],
      );
      expect(r.migraineDays, 11);
      expect(r.clearDays, 30);
    });

    test('sleep and stress are bucketed; stress takes the day\'s worst', () {
      expect(sleepBucket(5.9), '< 6 h');
      expect(sleepBucket(6), '6–8 h');
      expect(sleepBucket(8), '6–8 h');
      expect(sleepBucket(8.1), '> 8 h');
      expect([1, 2, 3, 4, 5].map(stressBucket), ['1–2', '1–2', '3', '4–5', '4–5']);

      final p = planted(10, 30, 0, 0);
      final events = [
        for (final e in p.events) attack(wallDay(e), stress: 2),
        // A second attack on the first migraine day, more stressed: that day reads 5.
        attack(wallDay(p.events.first), stress: 5),
      ];
      final checkins = [for (final c in p.checkins) CheckinStat(day: c.day, stress: 2)];
      final r = computeTrackedFactors(events, checkins);
      final high = r.factors[kStressFactor]!.singleWhere((x) => x.bucket == '4–5');
      expect(high.migraineDays, 1);
      expect(high.totalDays, 1);
    });
  });

  group('planted datasets', () {
    Future<DashboardResult> load(String name) async {
      final db = MegrimDatabase.forTesting(NativeDatabase.memory());
      await ImportService(
        db,
      ).importJsonString(File('test/fixtures/datasets/$name').readAsStringSync(), replace: true);
      final dash = await MegrimRepository(db: db).dashboard(now: DateTime(2026, 7, 6, 12));
      await db.close();
      return dash;
    }

    test('07: a trigger planted on migraine days surfaces', () async {
      final r = (await load('07-checkins-planted-trigger.json')).trackedFactors!;
      expect(r.available, isTrue);
      expect((r.trackedDays, r.migraineDays, r.clearDays), (60, 15, 45));
      final top = r.topFactors.first;
      expect((top.factor, top.condition), (kTriggerFactor, 'Bright light'));
      expect(top.oddsRatio, greaterThan(10));
    });

    test('08: the same trigger equally common on both does not', () async {
      final r = (await load('08-checkins-no-signal.json')).trackedFactors!;
      expect(r.available, isTrue);
      final row = r.factors[kTriggerFactor]!.singleWhere((x) => x.bucket == 'Bright light');
      expect(row.oddsRatio, closeTo(1.0, 0.25));
      expect(
        r.topFactors.where((t) => t.condition == 'Bright light' && t.oddsRatio > 1.5),
        isEmpty,
      );
    });
  });
}

DateTime wallDay(EventStat e) {
  final l = e.startedAt.toLocal();
  return DateTime(l.year, l.month, l.day);
}
