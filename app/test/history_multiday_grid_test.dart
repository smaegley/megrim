import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/repositories/megrim_repository.dart';
import 'package:megrim/screens/event_detail_screen.dart';
import 'package:megrim/screens/history_screen.dart';

/// See history_calendar_tap_test.dart — Drift stream teardown must be forced before test end.
Future<void> disposeAndDrain(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

/// Backlog #10: the Calendar is a weekday-aligned grid, and multi-day migraines surface on
/// every day they span — in the Calendar (colored cells, tappable) and the List ("N days").
void main() {
  late MegrimDatabase db;
  late MegrimRepository repo;

  setUp(() {
    db = MegrimDatabase.forTesting(NativeDatabase.memory());
    repo = MegrimRepository(db: db);
  });
  tearDown(() => db.close());

  Future<String> seedSpan(DateTime localStart, DateTime localEnd,
      {int severity = 5}) async {
    final id = await repo.startEvent(severity: severity);
    await repo.endEvent(id);
    await repo.updateEvent(MigraineEventsCompanion(
      id: Value(id),
      startedAt: Value(localStart.toUtc()),
      endedAt: Value(localEnd.toUtc()),
    ));
    return id;
  }

  // "Today" is pinned near the seeded entries (see history_calendar_tap_test.dart) — the
  // calendar renders every month back from today, so an unpinned clock would bury the seeded
  // month and duplicate day-number finders across visible months.
  Future<void> pumpCalendar(WidgetTester tester,
      {DateTime? today}) async {
    await tester.pumpWidget(MaterialApp(
        home: HistoryScreen(
            repo: repo, todayOverride: today ?? DateTime(2024, 6, 15))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
  }

  testWidgets('grid is weekday-aligned with a header row', (tester) async {
    // June 2024: the 1st is a Saturday. Sunday-first (the default locale), day 1 sits in the
    // LAST column of its row and day 2 wraps to the FIRST column of the next row.
    await seedSpan(DateTime(2024, 6, 5, 12), DateTime(2024, 6, 5, 13));
    await pumpCalendar(tester);

    // Header initials, Sunday-first: S M T W T F S (S/M/T/F counts include the duplicates).
    expect(find.text('W'), findsOneWidget);
    expect(find.text('F'), findsOneWidget);
    expect(find.text('S'), findsNWidgets(2));

    final day1 = tester.getTopLeft(find.widgetWithText(InkWell, '1'));
    final day2 = tester.getTopLeft(find.widgetWithText(InkWell, '2'));
    expect(day2.dy, greaterThan(day1.dy), reason: 'day 2 starts a new row');
    expect(day2.dx, lessThan(day1.dx),
        reason: 'day 1 is in the last column, day 2 in the first');
    await disposeAndDrain(tester);
  });

  testWidgets('tapping the middle day of a multi-day migraine opens it',
      (tester) async {
    final id =
        await seedSpan(DateTime(2024, 6, 5, 12), DateTime(2024, 6, 7, 9));
    await pumpCalendar(tester);

    await tester.tap(find.widgetWithText(InkWell, '6'));
    await tester.pumpAndSettle();

    expect(find.byType(EventDetailScreen), findsOneWidget);
    expect(
        tester
            .widget<EventDetailScreen>(find.byType(EventDetailScreen))
            .eventId,
        id);
    await disposeAndDrain(tester);
  });

  testWidgets('a span crossing a month boundary renders both month cards',
      (tester) async {
    await seedSpan(DateTime(2024, 6, 30, 20), DateTime(2024, 7, 2, 4));
    await pumpCalendar(tester, today: DateTime(2024, 7, 15));

    expect(find.text('June 2024'), findsOneWidget);
    expect(find.text('July 2024'), findsOneWidget);
    // The span links across the month cards too: June 30 reaches toward July, and July 1
    // reaches back — the severity-colored halves that tie the migraine together visually.
    expect(find.byKey(const ValueKey('link-right-2024-06-30')), findsOneWidget);
    expect(find.byKey(const ValueKey('link-left-2024-07-1')), findsOneWidget);
    await disposeAndDrain(tester);
  });

  testWidgets('multi-day migraines draw connector bars between their days',
      (tester) async {
    await seedSpan(DateTime(2024, 6, 5, 12), DateTime(2024, 6, 7, 9));
    await pumpCalendar(tester);

    // Day 5 reaches right, day 6 links both ways, day 7 only back — and the run has clean ends.
    expect(find.byKey(const ValueKey('link-right-2024-06-5')), findsOneWidget);
    expect(find.byKey(const ValueKey('link-left-2024-06-6')), findsOneWidget);
    expect(find.byKey(const ValueKey('link-right-2024-06-6')), findsOneWidget);
    expect(find.byKey(const ValueKey('link-left-2024-06-7')), findsOneWidget);
    expect(find.byKey(const ValueKey('link-left-2024-06-5')), findsNothing);
    expect(find.byKey(const ValueKey('link-right-2024-06-7')), findsNothing);
    // A single-day entry draws no links at all.
    await seedSpan(DateTime(2024, 6, 20, 9), DateTime(2024, 6, 20, 11));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('link-right-2024-06-20')), findsNothing);
    expect(find.byKey(const ValueKey('link-left-2024-06-20')), findsNothing);
    await disposeAndDrain(tester);
  });

  testWidgets('migraine-free months still render, keeping gaps honest',
      (tester) async {
    // One migraine in June, "today" in September: July and August have no entries but must
    // appear anyway — skipping them made gaps between migraines look shorter than they were.
    await seedSpan(DateTime(2024, 6, 5, 12), DateTime(2024, 6, 5, 13));
    await pumpCalendar(tester, today: DateTime(2024, 9, 10));

    expect(find.text('September 2024'), findsOneWidget);
    expect(find.text('August 2024'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('June 2024'), 400);
    expect(find.text('June 2024'), findsOneWidget);
    await disposeAndDrain(tester);
  });

  testWidgets('List view labels a multi-day migraine with its day count',
      (tester) async {
    await seedSpan(DateTime(2024, 6, 5, 12), DateTime(2024, 6, 7, 9),
        severity: 7);
    await tester.pumpWidget(MaterialApp(home: HistoryScreen(repo: repo)));
    await tester.pumpAndSettle();

    expect(find.text('Severity 7/10 · 3 days'), findsOneWidget);
    await disposeAndDrain(tester);
  });
}
