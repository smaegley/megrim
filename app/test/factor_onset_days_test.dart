import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:megrim/analytics/correlations.dart';
import 'package:megrim/analytics/pressure_baseline.dart';
import 'package:megrim/database/database.dart';
import 'package:flutter/material.dart';
import 'package:megrim/models/home_location.dart';
import 'package:megrim/repositories/megrim_repository.dart';
import 'package:megrim/screens/analytics_screen.dart';
import 'package:megrim/services/import_service.dart';

/// Suspected Factors counts attack ONSET days, and leaves the days in the middle of a multi-day
/// migraine out of the table altogether (2026-10-08, docs/METHODS.md): those days are neither
/// onset days nor days on which a new attack could have started.
///
/// All instants carry offset 0 so the calendar days don't depend on the test machine's zone.
void main() {
  // Seven events, all starting at noon UTC on these days in June 2024 (Sat 1 .. Sat 29).
  final starts = [
    for (final d in [1, 5, 10, 14, 19, 24, 29]) DateTime.utc(2024, 6, d, 12),
  ];
  List<int?> zeros(int n) => List.filled(n, 0);

  CorrelationResult run({
    List<DateTime?>? ends,
    Map<String, int>? hist,
    Map<String, String>? days,
  }) => computeCorrelations(
    eventStarts: starts,
    startOffsets: zeros(starts.length),
    eventEnds: ends,
    endOffsets: ends == null ? null : zeros(starts.length),
    pressureBaseline: hist,
    pressureDayBuckets: days,
    homeLat: 40.0,
  );

  int dowTotal(CorrelationResult r, String day) =>
      r.factors['Day of week']!.firstWhere((row) => row.bucket == day).totalDays;

  test('no end times: start days only, exactly the reference behaviour', () {
    final r = run();
    expect(r.totalMigraineDays, 7);
    expect(r.totalDaysInRange, 29); // 1..29 June
    expect(r.excludedMidAttackDays, 0);
    expect(r.caveats.any((c) => c.contains('middle of a')), isFalse);
  });

  test('a three-day migraine: onset counts once, days 2 and 3 leave the table', () {
    // The 10 June migraine (a Monday) runs to 12 June: Tue 11 and Wed 12 are mid-attack.
    final ends = <DateTime?>[for (final s in starts) s.add(const Duration(hours: 4))];
    ends[2] = DateTime.utc(2024, 6, 12, 8);
    final before = run();
    final after = run(ends: ends);

    expect(after.totalMigraineDays, 7, reason: 'still one onset per migraine');
    expect(after.excludedMidAttackDays, 2);
    expect(after.totalDaysInRange, 27);
    expect(dowTotal(after, 'Tue'), dowTotal(before, 'Tue') - 1);
    expect(dowTotal(after, 'Wed'), dowTotal(before, 'Wed') - 1);
    expect(dowTotal(after, 'Mon'), dowTotal(before, 'Mon'), reason: 'the onset day stays');
    expect(
      after.caveats.any((c) => c.startsWith('2 days in the middle of a multi-day migraine')),
      isTrue,
    );
  });

  test('the 2×2 for a bucket matches a hand count once mid-attack days are removed', () {
    final ends = <DateTime?>[for (final s in starts) s.add(const Duration(hours: 4))];
    ends[2] = DateTime.utc(2024, 6, 12, 8); // removes Tue 11, Wed 12
    final r = run(ends: ends);
    // Saturdays in 1..29 June: 1, 8, 15, 22, 29 (none removed). Onsets on a Saturday: 1, 29.
    final sat = r.factors['Day of week']!.firstWhere((row) => row.bucket == 'Sat');
    expect(sat.totalDays, 5);
    expect(sat.migraineDays, 2);
    // a=2, b=7-2=5, c=5-2=3, d=(27-7)-3=17 → OR = (2.5·17.5)/(5.5·3.5)
    expect(sat.oddsRatio, closeTo((2.5 * 17.5) / (5.5 * 3.5), 0.01));
  });

  test('a mid-attack day on which another migraine starts stays as an onset day', () {
    // The 1 June migraine runs to 6 June; the next one starts on 5 June.
    final ends = <DateTime?>[for (final s in starts) s.add(const Duration(hours: 4))];
    ends[0] = DateTime.utc(2024, 6, 6, 8);
    final r = run(ends: ends);
    expect(r.excludedMidAttackDays, 4, reason: '2, 3, 4 and 6 June; 5 June is an onset');
    expect(r.totalMigraineDays, 7);
  });

  test('a migraine still going covers only its start day, so nothing is removed', () {
    final ends = <DateTime?>[for (final s in starts) s.add(const Duration(hours: 4))];
    ends[3] = null;
    expect(run(ends: ends).excludedMidAttackDays, 0);
  });

  group('pressure baseline', () {
    final ends = <DateTime?>[for (final s in starts) s.add(const Duration(hours: 4))];
    ends[2] = DateTime.utc(2024, 6, 12, 8); // removes 11 and 12 June

    Map<String, String> allDays(String bucket) => {
      for (var d = 1; d <= 29; d++) '2024-06-${d.toString().padLeft(2, '0')}': bucket,
    };

    test('per-day buckets: mid-attack days leave the pressure baseline too', () {
      final days = allDays('0 to 5')..['2024-06-11'] = '< -10';
      final r = run(ends: ends, days: days);
      final rows = {for (final row in r.factors['Pressure Δ 24h (hPa)']!) row.bucket: row};
      expect(rows['0 to 5']!.totalDays, 27, reason: '29 days minus 11 and 12 June');
      expect(rows.containsKey('< -10'), isFalse, reason: '11 June was the only day in it');
    });

    test('an old histogram-only cache is used as it is', () {
      final r = run(ends: ends, hist: {'0 to 5': 29});
      final row = r.factors['Pressure Δ 24h (hPa)']!.single;
      expect(row.totalDays, 29);
    });
  });

  group('pressure cache', () {
    test('per-day buckets survive a save and load', () {
      const b = PressureBaseline('t', {'0 to 5': 2}, dayBuckets: {'2024-06-01': '0 to 5'});
      final back = PressureBaseline.tryDecode(jsonEncode(b.toJson()))!;
      expect(back.dayBuckets, {'2024-06-01': '0 to 5'});
      expect(
        PressureBaseline.tryDecode(jsonEncode({'tag': 't', 'histogram': {}}))!.dayBuckets,
        isNull,
        reason: 'an old cache decodes with no per-day buckets',
      );
    });

    test('bucketDailyDeltasByDay agrees with the histogram', () {
      final dates = [for (var d = 1; d <= 4; d++) DateTime.utc(2024, 6, d)];
      final pressures = <double?>[1000, 1003, 990, 991];
      final byDay = bucketDailyDeltasByDay(dates, pressures);
      expect(byDay, {'2024-06-02': '0 to 5', '2024-06-03': '< -10', '2024-06-04': '0 to 5'});
      final hist = bucketDailyDeltas(dates, pressures);
      expect(hist['0 to 5'], 2);
      expect(hist['< -10'], 1);
    });

    test('an old cache is kept offline and rebuilt with per-day buckets when online', () async {
      final db = MegrimDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      const home = HomeLocation(lat: 40.0, lon: -105.0, label: 'Home');
      await db.setSetting('home_location', home.encode());
      final start = DateTime(2024, 6, 2), end = DateTime(2024, 6, 3);
      final tag = pressureBaselineTag(start, end, home.lat, home.lon);
      await db.setSetting(
        'pressure_baseline',
        jsonEncode(const PressureBaseline('x', {}).toJson()..['tag'] = tag),
      );

      var calls = 0;
      final service = PressureBaselineService(
        db: db,
        httpClient: MockClient((req) async {
          calls++;
          return http.Response(
            jsonEncode({
              'daily': {
                'time': ['2024-06-01', '2024-06-02', '2024-06-03'],
                'surface_pressure_mean': [1000, 1002, 1009],
              },
            }),
            200,
          );
        }),
      );
      addTearDown(service.close);

      final offline = await service.getOrBuild(start, end, allowFetch: false);
      expect(calls, 0);
      expect(offline!.dayBuckets, isNull);

      final online = await service.getOrBuild(start, end);
      expect(calls, 1);
      expect(online!.dayBuckets, {'2024-06-02': '0 to 5', '2024-06-03': '5 to 10'});

      // Now current: no further fetch.
      await service.getOrBuild(start, end);
      expect(calls, 1);
    });
  });

  testWidgets('the Analytics card lists the left-out days among its caveats', (tester) async {
    // Steve's 2026-10-08 test (A2): the note reached the PDF but not the app card.
    final db = MegrimDatabase.forTesting(NativeDatabase.memory());
    final repo = MegrimRepository(db: db);
    await tester.runAsync(
      () => ImportService(
        db,
      ).importJsonString(File('test/fixtures/sample-data.json').readAsStringSync(), replace: true),
    );
    final excluded = (await tester.runAsync(() => repo.correlations()))!.excludedMidAttackDays;
    expect(excluded, greaterThan(0));

    await tester.pumpWidget(MaterialApp(home: AnalyticsScreen(repo: repo)));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    final showAll = find.textContaining(RegExp(r'^Show all \d+ factors$'));
    // The page scrolls vertically; the monthly chart (backlog #17) is a second, sideways one.
    final page = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    );
    await tester.scrollUntilVisible(showAll, 300, scrollable: page.first);
    await tester.ensureVisible(showAll);
    await tester.pumpAndSettle();
    await tester.tap(showAll);
    await tester.pumpAndSettle();
    final note = find.text('• ${midAttackNote(excluded)}');
    await tester.scrollUntilVisible(note, 200, scrollable: page.first);
    expect(note, findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(() => db.close());
  });

  test('the note reads naturally for one day and for several', () {
    expect(
      midAttackNote(1),
      '1 day in the middle of a multi-day migraine is left out: a new attack can\'t start while one is underway.',
    );
    expect(
      midAttackNote(18),
      startsWith('18 days in the middle of a multi-day migraine are left out'),
    );
  });
}
