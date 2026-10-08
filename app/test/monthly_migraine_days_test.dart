import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/analytics/correlations.dart';
import 'package:megrim/analytics/dashboard.dart';
import 'package:megrim/models/event_time.dart';
import 'package:megrim/services/analytics_export.dart';
import 'package:megrim/services/report_content.dart';
import 'package:megrim/widgets/monthly_days_card.dart';

/// Backlog #17: migraine DAYS per month — distinct local calendar days covered by a migraine.
///
/// Events are given explicit offsets (minutes east of UTC) so the results don't depend on the
/// zone the tests run in.
EventStat ev(DateTime startUtc, {DateTime? endUtc, int offset = 0, int? endOffset}) => EventStat(
  startedAt: startUtc,
  endedAt: endUtc,
  startOffsetMin: offset,
  endOffsetMin: endOffset,
);

Map<String, int> byKey(List<MonthDays> l) => {for (final m in l) m.key: m.days};

void main() {
  // "Today" for most tests: 15 Oct 2026, local noon.
  final now = DateTime(2026, 10, 15, 12);

  group('daysCovered', () {
    test('a one-day migraine covers its start day', () {
      expect(daysCovered(DateTime.utc(2026, 3, 4, 9), 0, DateTime.utc(2026, 3, 4, 17), 0), [
        DateTime(2026, 3, 4),
      ]);
    });

    test('a multi-day migraine covers every day from start to end', () {
      expect(daysCovered(DateTime.utc(2026, 1, 30, 20), 0, DateTime.utc(2026, 2, 1, 3), 0), [
        DateTime(2026, 1, 30),
        DateTime(2026, 1, 31),
        DateTime(2026, 2, 1),
      ]);
    });

    test('ongoing, or ending before it started: start day only', () {
      expect(daysCovered(DateTime.utc(2026, 5, 1, 9), 0, null, null), [DateTime(2026, 5, 1)]);
      expect(daysCovered(DateTime.utc(2026, 5, 3, 9), 0, DateTime.utc(2026, 5, 1, 9), 0), [
        DateTime(2026, 5, 3),
      ]);
    });

    test('days are read in the zone the migraine was logged in', () {
      // 22:30 UTC on 10 Jun is 00:30 on 11 Jun in Paris (+120).
      expect(daysCovered(DateTime.utc(2026, 6, 10, 22, 30), 120, null, null), [
        DateTime(2026, 6, 11),
      ]);
    });

    test('a span across a DST change neither skips nor repeats a day', () {
      // Denver, spring forward on 8 Mar 2026: 22:00 MST (-420) on the 7th to 23:00 MDT (-360)
      // on the 8th.
      expect(daysCovered(DateTime.utc(2026, 3, 8, 5), -420, DateTime.utc(2026, 3, 9, 5), -360), [
        DateTime(2026, 3, 7),
        DateTime(2026, 3, 8),
      ]);
    });

    test('the end falls back to the start zone when it has no offset of its own', () {
      // Ends 23:30 UTC on 2 Jun = 01:30 on 3 Jun at +120.
      expect(
        daysCovered(DateTime.utc(2026, 6, 2, 8), 120, DateTime.utc(2026, 6, 2, 23, 30), null),
        [DateTime(2026, 6, 2), DateTime(2026, 6, 3)],
      );
    });
  });

  group('monthly migraine days', () {
    test('two migraines on one day count once', () {
      final r = migraineDays([
        ev(DateTime.utc(2026, 9, 3, 8), endUtc: DateTime.utc(2026, 9, 3, 10)),
        ev(DateTime.utc(2026, 9, 3, 18), endUtc: DateTime.utc(2026, 9, 3, 20)),
      ], now);
      expect(byKey(r.byMonth)['2026-09'], 1);
    });

    test('a migraine across a month boundary counts in both months', () {
      final r = migraineDays([
        ev(DateTime.utc(2026, 8, 31, 20), endUtc: DateTime.utc(2026, 9, 1, 6)),
      ], now);
      expect(byKey(r.byMonth), {'2026-08': 1, '2026-09': 1, '2026-10': 0});
    });

    test('every month from the first entry to now is listed, zero months included', () {
      final r = migraineDays([ev(DateTime.utc(2026, 6, 10, 9))], now);
      expect(byKey(r.byMonth), {
        '2026-06': 1,
        '2026-07': 0,
        '2026-08': 0,
        '2026-09': 0,
        '2026-10': 0,
      });
      expect(r.byMonth.first.key, '2026-06');
    });

    test('nothing logged: no months, zero days, no average', () {
      final r = migraineDays(const [], now);
      expect(r.byMonth, isEmpty);
      expect(r.last30, 0);
      expect(r.avgLast3Months, isNull);
    });

    test('last 30 days is today and the 29 days before it', () {
      final r = migraineDays([
        ev(DateTime.utc(2026, 10, 15, 9)), // today: in
        ev(DateTime.utc(2026, 9, 16, 9)), // 29 days ago: in
        ev(DateTime.utc(2026, 9, 15, 9)), // 30 days ago: out
        ev(DateTime.utc(2026, 10, 20, 9)), // future-dated: out
      ], now);
      expect(r.last30, 2);
    });

    test('a future-dated entry extends the months past today', () {
      final r = migraineDays([ev(DateTime.utc(2026, 12, 1, 9))], now);
      expect(r.byMonth.last.key, '2026-12');
    });

    test('3-month average uses the last 3 complete months, not the current one', () {
      final r = migraineDays([
        ev(DateTime.utc(2026, 7, 1, 9)), // Jul: 1
        ev(DateTime.utc(2026, 8, 1, 9)), ev(DateTime.utc(2026, 8, 2, 9)), // Aug: 2
        ev(DateTime.utc(2026, 9, 1, 9)), ev(DateTime.utc(2026, 9, 2, 9)),
        ev(DateTime.utc(2026, 9, 3, 9)), ev(DateTime.utc(2026, 9, 4, 9)), // Sep: 4
        ev(DateTime.utc(2026, 10, 1, 9)), ev(DateTime.utc(2026, 10, 2, 9)), // Oct: in progress
      ], now);
      expect(r.avgLast3Months, 2.3); // (1 + 2 + 4) / 3, Oct excluded
    });

    test('no 3-month average until 3 complete months have passed since the first entry', () {
      // First entry in August: only Aug and Sep are complete.
      expect(migraineDays([ev(DateTime.utc(2026, 8, 20, 9))], now).avgLast3Months, isNull);
      // First entry in July: Jul, Aug, Sep are complete.
      expect(migraineDays([ev(DateTime.utc(2026, 7, 20, 9))], now).avgLast3Months, 0.3);
    });

    test('computeDashboard carries the figures and the export serialises them', () {
      final d = computeDashboard([
        ev(DateTime.utc(2026, 9, 30, 20), endUtc: DateTime.utc(2026, 10, 1, 4)),
      ], now: now);
      expect(byKey(d.migraineDaysByMonth), {'2026-09': 1, '2026-10': 1});
      expect(d.migraineDaysLast30, 2);
      final json = dashboardToJson(d);
      expect(json['migraine_days_last_30'], 2);
      expect(json['migraine_days_avg_last_3_months'], isNull);
      expect(json['migraine_days_by_month'], [
        {'month': '2026-09', 'days': 1},
        {'month': '2026-10', 'days': 1},
      ]);
    });
  });

  group('report', () {
    DashboardResult dashWithMonths(int n) => DashboardResult(
      summary: const Summary(totalEvents: 1),
      migraineDaysLast30: 3,
      avgMigraineDaysLast3Months: 2.7,
      migraineDaysByMonth: [
        // n months ending October 2026.
        for (var i = n - 1; i >= 0; i--)
          MonthDays(DateTime(2026, 10 - i).year, DateTime(2026, 10 - i).month, i % 4),
      ],
    );

    ReportContent build(DashboardResult dash) => buildReportContent(
      dash: dash,
      corr: const CorrelationResult(available: true),
      events: const [],
      appVersion: '1.0.7',
      now: DateTime(2026, 10, 15),
    );

    test('the monthly chart comes first: last 12 months, current month starred', () {
      final c = build(dashWithMonths(20));
      final chart = c.charts.first;
      expect(chart.title, 'Migraine days per month');
      expect(chart.bars, hasLength(12));
      expect(chart.bars.first.label, 'Nov 2025');
      expect(chart.bars.last.label, 'Oct 2026 *');
      expect(chart.note, contains('2.7'));
    });

    test('the summary gains a last-30-days tile', () {
      final c = build(dashWithMonths(3));
      expect(c.summary.last.label, 'Migraine days, last 30 d');
      expect(c.summary.last.value, '3');
    });
  });

  group('card', () {
    Future<void> pump(WidgetTester tester, DashboardResult dash) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MonthlyDaysCard(dash: dash, now: DateTime(2026, 10, 15)),
          ),
        ),
      ),
    );

    DashboardResult months(int n, {double? avg = 1.3}) => DashboardResult(
      summary: const Summary(totalEvents: 1),
      migraineDaysLast30: 2,
      avgMigraineDaysLast3Months: avg,
      migraineDaysByMonth: [
        for (var i = n - 1; i >= 0; i--)
          MonthDays(DateTime(2026, 10 - i).year, DateTime(2026, 10 - i).month, 1),
      ],
    );

    testWidgets('shows both figures and marks the month in progress', (tester) async {
      await pump(tester, months(5));
      expect(find.text('Migraine days per month'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Last 30 days'), findsOneWidget);
      expect(find.text('1.3'), findsOneWidget);
      expect(find.text('Oct*\n2026'), findsOneWidget);
    });

    testWidgets('no average yet shows a dash', (tester) async {
      await pump(tester, months(2, avg: null));
      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('a long history opens on the newest month; the oldest is scrolled off', (
      tester,
    ) async {
      await pump(tester, months(30));
      final screen = tester.getRect(find.byType(Scaffold));
      final newest = tester.getRect(find.text('Oct*\n2026'));
      expect(screen.contains(newest.center), isTrue, reason: 'newest month visible');
      // The first bar (May 2024) carries its year under the month.
      final oldest = tester.getRect(find.text('May\n2024'));
      expect(screen.contains(oldest.center), isFalse, reason: 'oldest month scrolled off');
    });

    testWidgets('screen readers get one sentence, newest month first', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, months(3));
      expect(
        find.bySemanticsLabel(
          RegExp(
            r'^Migraine days per month, newest first\. Oct 2026 so far: 1 day; Sep 2026: 1 day',
          ),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('renders nothing when there is no data', (tester) async {
      await pump(tester, const DashboardResult(summary: Summary(totalEvents: 0)));
      expect(find.text('Migraine days per month'), findsNothing);
    });
  });
}
