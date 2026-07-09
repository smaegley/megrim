import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/analytics/correlations.dart';
import 'package:megrim/analytics/dashboard.dart';

void main() {
  group('oddsRatio (Haldane–Anscombe)', () {
    test('matches hand-computed values', () {
      // (a+.5)(d+.5)/((b+.5)(c+.5))
      expect(oddsRatio(3, 2, 1, 10), closeTo(9.8, 1e-9)); // 36.75/3.75
      expect(oddsRatio(2, 3, 0, 4), closeTo(6.428571, 1e-6)); // 11.25/1.75
      expect(oddsRatio(0, 0, 0, 0), closeTo(1.0, 1e-9)); // .25/.25
    });
  });

  group('pressureBucket boundaries', () {
    test('classifies deltas', () {
      expect(pressureBucket(-12), '< -10');
      expect(pressureBucket(-10), '-10 to -5'); // -10 is not < -10
      expect(pressureBucket(-7), '-10 to -5');
      expect(pressureBucket(-1), '-5 to 0');
      expect(pressureBucket(0), '0 to 5');
      expect(pressureBucket(4.9), '0 to 5');
      expect(pressureBucket(9), '5 to 10');
      expect(pressureBucket(10), '> 10');
    });
  });

  group('computeCorrelations', () {
    test('requires at least 5 events', () {
      final r = computeCorrelations(
        eventStarts: List.generate(
            4, (i) => DateTime.utc(2024, 1, 1 + i, 12)),
      );
      expect(r.available, isFalse);
      expect(r.reason, contains('at least 5'));
    });

    test('hand-verified window, base rate, and a day-of-week odds ratio', () {
      // Window Jan 1..Jan 9 2024 (9 days). Jan 1 2024 is a Monday.
      final events = [
        DateTime.utc(2024, 1, 1, 12), // Mon
        DateTime.utc(2024, 1, 3, 12), // Wed
        DateTime.utc(2024, 1, 5, 12), // Fri
        DateTime.utc(2024, 1, 8, 12), // Mon
        DateTime.utc(2024, 1, 9, 12), // Tue
      ];
      final r = computeCorrelations(eventStarts: events, homeLat: 40.0);

      expect(r.available, isTrue);
      expect(r.totalEvents, 5);
      expect(r.totalMigraineDays, 5);
      expect(r.totalDaysInRange, 9);
      expect(r.baseRatePct, closeTo(55.56, 0.01)); // 5/9

      // Monday: 2 of 2 days were migraine days.
      final mon = r.factors['Day of week']!.firstWhere((f) => f.bucket == 'Mon');
      expect(mon.migraineDays, 2);
      expect(mon.totalDays, 2);
      expect(mon.migraineRatePct, 100.0);
      // 2x2: a=2 (mon+migraine), b=3 (migraine not-mon), c=0 (mon non-migraine),
      // d=4 (non-migraine not-mon) -> OR = 6.43
      expect(mon.oddsRatio, closeTo(6.43, 0.01));

      // No pressure baseline supplied -> pressure factor omitted.
      expect(r.factors.containsKey('Pressure Δ 24h (hPa)'), isFalse);
      expect(r.caveats, hasLength(4));
    });

    test('includes the pressure factor when a baseline is supplied', () {
      final events = List.generate(6, (i) => DateTime.utc(2024, 1, 1 + i, 12));
      final r = computeCorrelations(
        eventStarts: events,
        migrainePressureDeltas: [-12, -8, 2, 3, 7, 11],
        pressureBaseline: {
          '< -10': 2, '-10 to -5': 2, '-5 to 0': 5, '0 to 5': 6,
          '5 to 10': 3, '> 10': 2 //
        },
      );
      expect(r.factors.containsKey('Pressure Δ 24h (hPa)'), isTrue);
    });

    test('balanced weekdays are not flagged (guard against false positives)', () {
      // A migraine every other day over eight weeks: each weekday ends up with a near-equal split
      // of migraine and non-migraine days, so its migraine rate ≈ the base rate and no weekday
      // should surface as a suspected factor (odds ratios sit around 1).
      final start = DateTime.utc(2024, 3, 4, 12); // a Monday
      final events = <DateTime>[
        for (var i = 0; i < 56; i += 2) start.add(Duration(days: i)),
      ];
      final r = computeCorrelations(eventStarts: events, homeLat: 40.0);
      expect(r.available, isTrue);
      // Every weekday odds ratio hugs 1 — nothing like the 6.4 a real Monday signal produces
      // (see the hand-verified test above). Small boundary noise from an odd-length window is fine.
      for (final f in r.factors['Day of week']!) {
        expect(f.oddsRatio, lessThan(1.5),
            reason: '${f.bucket} OR ${f.oddsRatio} should be near 1 for balanced data');
      }
    });

    test('top factors are sorted by odds ratio and need >=3 migraine days', () {
      // Cluster many migraines on Mondays so a bucket clears the >=3 threshold.
      final events = <DateTime>[];
      for (final mondayFirst in [1, 8, 15, 22]) {
        events.add(DateTime.utc(2024, 1, mondayFirst, 12)); // Mondays
      }
      events.add(DateTime.utc(2024, 1, 10, 12)); // one Wednesday
      final r = computeCorrelations(eventStarts: events, homeLat: 40.0);
      expect(r.available, isTrue);
      // Sorted descending.
      for (var i = 1; i < r.topFactors.length; i++) {
        expect(r.topFactors[i - 1].oddsRatio,
            greaterThanOrEqualTo(r.topFactors[i].oddsRatio));
      }
      // Every top factor has >=3 migraine days and OR > 1.
      for (final t in r.topFactors) {
        expect(t.migraineDays, greaterThanOrEqualTo(3));
        expect(t.oddsRatio, greaterThan(1.0));
      }
    });

    test('every migraine day is counted in each factor (DST-safe day stepping)', () {
      // Regression guard: the day-by-day baseline loop must count every migraine day exactly once
      // per factor. A previous version stepped with `add(Duration(days:1))`, which drifts off local
      // midnight across a DST spring-forward and silently dropped later days — only visible in a
      // DST timezone. This invariant (per-factor migraine-day sums == total) catches it; the CI
      // suite is also run under TZ=America/Denver so the drift is actually exercised.
      final events = <DateTime>[
        for (var y = 2022; y <= 2024; y++)
          for (final m in [1, 3, 4, 7, 11]) // incl. March (spring-forward month)
            DateTime.utc(y, m, 15, 18), // 18:00Z -> still same local day in the Americas
      ];
      final r = computeCorrelations(eventStarts: events, homeLat: 40.0, homeLon: -105.0);
      expect(r.available, isTrue);
      for (final entry in r.factors.entries) {
        final sum = entry.value.fold<int>(0, (s, row) => s + row.migraineDays);
        expect(sum, r.totalMigraineDays,
            reason: '${entry.key}: migraine-day counts sum to $sum, '
                'expected ${r.totalMigraineDays}');
      }
    });
  });

  group('computeDashboard', () {
    test('empty input', () {
      final r = computeDashboard(const []);
      expect(r.isEmpty, isTrue);
      expect(r.summary.totalEvents, 0);
    });

    test('summary: averages, intervals, counts', () {
      final events = [
        EventStat(
          startedAt: DateTime.utc(2024, 1, 1, 10),
          endedAt: DateTime.utc(2024, 1, 1, 12), // 2h
          severity: 4,
        ),
        EventStat(
          startedAt: DateTime.utc(2024, 1, 3, 10),
          endedAt: DateTime.utc(2024, 1, 3, 14), // 4h
          severity: 6,
        ),
        EventStat(
          startedAt: DateTime.utc(2024, 1, 6, 10), // ongoing
          severity: 8,
        ),
      ];
      final r = computeDashboard(events);
      expect(r.summary.totalEvents, 3);
      expect(r.summary.avgSeverity, 6.0); // (4+6+8)/3
      expect(r.summary.avgDurationHours, 3.0); // (2+4)/2
      expect(r.summary.avgIntervalDays, 2.5); // (2+3)/2
      // Sample SD of intervals [2, 3]: sqrt(((0.5)^2 + (0.5)^2)/(2-1)) = 0.707 → 0.7.
      expect(r.summary.intervalStdDevDays, 0.7);
      expect(r.calendar, hasLength(3));
      final y2024 = r.byYear.firstWhere((y) => y.year == 2024);
      expect(y2024.count, 3);
      expect(y2024.avgSeverity, 6.0);
    });

    test('interval SD needs at least two intervals', () {
      final one =
          computeDashboard([EventStat(startedAt: DateTime.utc(2024, 1, 1))]);
      expect(one.summary.intervalStdDevDays, isNull);
      final two = computeDashboard([
        EventStat(startedAt: DateTime.utc(2024, 1, 1)),
        EventStat(startedAt: DateTime.utc(2024, 1, 4)),
      ]);
      expect(two.summary.avgIntervalDays, 3.0);
      expect(two.summary.intervalStdDevDays, isNull); // only one interval
    });

    test('derived-factor buckets are ordered and counted', () {
      EventStat mk(String season, String tod, String moon, int dow) => EventStat(
            startedAt: DateTime.utc(2024, 6, 1, 10),
            season: season,
            timeOfDayBucket: tod,
            moonPhase: moon,
            dayOfWeek: dow,
            pressureDelta24h: -7,
          );
      final r = computeDashboard([
        mk('Summer', 'morning', 'New Moon', 0),
        mk('Summer', 'night', 'Full Moon', 0),
        mk('Winter', 'morning', 'New Moon', 3),
      ]);
      expect(r.bySeason.firstWhere((s) => s.label == 'Summer').count, 2);
      expect(r.byTimeOfDay.firstWhere((t) => t.label == 'morning').count, 2);
      expect(r.byMoonPhase.firstWhere((m) => m.label == 'New Moon').count, 2);
      expect(r.byDayOfWeek[0].count, 2); // Mon
      expect(r.pressureDelta.firstWhere((p) => p.label == '-10 to -5').count, 3);
      // Ordering preserved.
      expect(r.byTimeOfDay.map((e) => e.label).toList(), kTimeOfDayOrder);
      expect(r.pressureDelta.map((e) => e.label).toList(), kPressureBuckets);
    });

    test('trigger frequency counts once per event, most-tagged first', () {
      final r = computeDashboard([
        EventStat(startedAt: DateTime.utc(2024, 1, 1), triggers: const [
          'Stress',
          'Caffeine',
          'Stress', // duplicate on one event counts once
        ]),
        EventStat(startedAt: DateTime.utc(2024, 1, 2), triggers: const ['Stress']),
        EventStat(startedAt: DateTime.utc(2024, 1, 3), triggers: const ['Caffeine']),
        EventStat(startedAt: DateTime.utc(2024, 1, 4), triggers: const ['Stress']),
      ]);
      expect(r.triggerFrequency.first.label, 'Stress');
      expect(r.triggerFrequency.first.count, 3); // 3 events, not 4 tags
      expect(r.triggerFrequency[1].label, 'Caffeine');
      expect(r.triggerFrequency[1].count, 2);
    });
  });
}
