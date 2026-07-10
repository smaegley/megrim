import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/repositories/megrim_repository.dart';
import 'package:megrim/screens/event_detail_screen.dart';
import 'package:megrim/screens/history_screen.dart';

/// Drift's query-stream store closes a stream's underlying resources on a timer rather than
/// synchronously (see StreamQueryStore.markAsClosed) — that timer only gets created once the
/// StreamBuilder actually disposes, which the test framework otherwise defers to its own
/// end-of-test element unmounting (too late for the test body to pump it away). Force disposal
/// now, while still inside the test, then pump so the resulting timer fires before the test ends.
Future<void> disposeAndDrain(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

/// Backlog #9: tapping a Calendar day opens its entry directly (one entry), offers a picker
/// (several entries), or starts a new past entry pre-dated to that day (none).
void main() {
  late MegrimDatabase db;
  late MegrimRepository repo;

  setUp(() {
    db = MegrimDatabase.forTesting(NativeDatabase.memory());
    repo = MegrimRepository(db: db);
  });
  tearDown(() => db.close());

  Future<String> seedEvent(DateTime localDay, int severity) async {
    final id = await repo.startEvent(severity: severity);
    await repo.endEvent(id);
    final at = DateTime(localDay.year, localDay.month, localDay.day, 12).toUtc();
    await repo.updateEvent(
        MigraineEventsCompanion(id: Value(id), startedAt: Value(at), endedAt: Value(at)));
    return id;
  }

  Future<void> pumpCalendar(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: HistoryScreen(repo: repo)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
  }

  testWidgets('tapping a day with exactly one entry opens it directly', (tester) async {
    final id = await seedEvent(DateTime(2024, 6, 5), 3);
    await pumpCalendar(tester);

    await tester.tap(find.widgetWithText(InkWell, '5'));
    await tester.pumpAndSettle();

    expect(find.byType(EventDetailScreen), findsOneWidget);
    expect(tester.widget<EventDetailScreen>(find.byType(EventDetailScreen)).eventId, id);
    await disposeAndDrain(tester);
  });

  testWidgets('tapping a day with multiple entries shows a picker', (tester) async {
    await seedEvent(DateTime(2024, 6, 10), 4);
    await seedEvent(DateTime(2024, 6, 10), 8);
    await pumpCalendar(tester);

    await tester.tap(find.widgetWithText(InkWell, '10'));
    await tester.pumpAndSettle();

    // A picker lists both entries rather than navigating straight to either one.
    expect(find.byType(EventDetailScreen), findsNothing);
    expect(find.text('2 entries on Mon 10 Jun 2024'), findsOneWidget);
    expect(find.text('Severity 4/10'), findsOneWidget);
    expect(find.text('Severity 8/10'), findsOneWidget);

    await tester.tap(find.text('Severity 8/10'));
    await tester.pumpAndSettle();
    expect(find.byType(EventDetailScreen), findsOneWidget);
    await disposeAndDrain(tester);
  });

  testWidgets('tapping an empty day starts a new past entry pre-dated to that day',
      (tester) async {
    // Any event so June's grid actually renders; day 20 itself stays empty.
    await seedEvent(DateTime(2024, 6, 5), 3);
    await pumpCalendar(tester);

    await tester.tap(find.widgetWithText(InkWell, '20'));
    await tester.pumpAndSettle();

    expect(find.byType(EventDetailScreen), findsOneWidget);
    final events = await db.select(db.migraineEvents).get();
    final created = events.firstWhere((e) => e.startedAt.toLocal().day == 20);
    expect(created.startedAt.toLocal().month, 6);
    expect(created.startedAt.toLocal().year, 2024);
    expect(created.endedAt, isNotNull); // pre-ended like the FAB's "Add past entry"
    await disposeAndDrain(tester);
  });
}
