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

  Future<void> pumpCalendar(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: HistoryScreen(repo: repo)));
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
    await pumpCalendar(tester);

    expect(find.text('June 2024'), findsOneWidget);
    expect(find.text('July 2024'), findsOneWidget);
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
