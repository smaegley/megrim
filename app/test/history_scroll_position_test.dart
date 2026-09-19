import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/repositories/megrim_repository.dart';
import 'package:megrim/screens/event_detail_screen.dart';
import 'package:megrim/screens/history_screen.dart';

/// Issue #13: the History Calendar lost its scroll position after opening an entry and coming
/// back. Two independent weaknesses made the list fragile to any remount/rebuild:
///  1. the screen created a brand-new Drift stream on every build, so any rebuild resubscribed
///     the StreamBuilder, flashed the loading spinner, and remounted the list at the top;
///  2. the calendar list had no PageStorageKey, so a remount had nothing to restore from.
/// These tests pin both, plus the push/pop round-trip the reporter described.
///
/// See history_calendar_tap_test.dart for why disposeAndDrain is needed with Drift streams.
Future<void> disposeAndDrain(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

/// Runs [body] and ALWAYS drains afterwards: a failing expectation that skipped the drain left
/// the Drift stream pending and hung the next test in this file rather than failing it.
Future<void> withDrain(WidgetTester tester, Future<void> Function() body) async {
  try {
    await body();
  } finally {
    await disposeAndDrain(tester);
  }
}

/// Stands in for HomeShell: a parent that can rebuild and hand HistoryScreen a fresh widget
/// instance (which is what forces `_HistoryScreenState.build` to run again).
class _Host extends StatefulWidget {
  final MegrimRepository repo;
  const _Host({required this.repo});

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  int _generation = 0;
  void rebuild() => setState(() => _generation++);

  @override
  Widget build(BuildContext context) {
    // _generation is read so the analyzer sees the setState do something observable.
    return HistoryScreen(
      key: ValueKey('history-$_generation'.length),
      repo: widget.repo,
      todayOverride: DateTime(2024, 6, 15),
    );
  }
}

void main() {
  late MegrimDatabase db;
  late MegrimRepository repo;

  setUp(() {
    db = MegrimDatabase.forTesting(NativeDatabase.memory());
    repo = MegrimRepository(db: db);
  });
  tearDown(() => db.close());

  Future<void> seedEvent(DateTime localDay) async {
    final id = await repo.startEvent(severity: 4);
    await repo.endEvent(id);
    final at = DateTime(localDay.year, localDay.month, localDay.day, 12).toUtc();
    await repo.updateEvent(MigraineEventsCompanion(
        id: Value(id), startedAt: Value(at), endedAt: Value(at)));
  }

  /// Enough months back from "today" (2024-06-15) that the calendar is comfortably taller than
  /// the test viewport and can be scrolled a long way.
  Future<void> seedTwoYears() async {
    for (var i = 0; i < 24; i++) {
      await seedEvent(DateTime(2024, 6 - i, 10));
    }
  }

  ScrollPosition calendarPosition(WidgetTester tester) =>
      tester.state<ScrollableState>(find.byType(Scrollable).last).position;

  Future<void> pumpCalendar(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: _Host(repo: repo)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
  }

  Future<double> scrollCalendarDown(WidgetTester tester) async {
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -1200));
    await tester.pumpAndSettle();
    final pixels = calendarPosition(tester).pixels;
    expect(pixels, greaterThan(300), reason: 'the drag should have scrolled a long way');
    return pixels;
  }

  testWidgets('a parent rebuild neither shows the spinner nor resets the calendar scroll',
      (tester) async {
    await withDrain(tester, () async {
      await seedTwoYears();
      await pumpCalendar(tester);
      final before = await scrollCalendarDown(tester);

      tester.state<_HostState>(find.byType(_Host)).rebuild();
      await tester.pump();
      // A fresh stream per build made StreamBuilder go back to "waiting" here.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpAndSettle();
      expect(calendarPosition(tester).pixels, before);
    });
  });

  testWidgets('switching List -> Calendar and back restores the calendar scroll',
      (tester) async {
    await withDrain(tester, () async {
      await seedTwoYears();
      await pumpCalendar(tester);
      final before = await scrollCalendarDown(tester);

      await tester.tap(find.text('List'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();
      expect(calendarPosition(tester).pixels, before);
    });
  });

  testWidgets('opening an entry from the calendar and going back keeps the scroll',
      (tester) async {
    await withDrain(tester, () async {
      await seedTwoYears();
      await pumpCalendar(tester);
      final before = await scrollCalendarDown(tester);

      // Every seeded month has an entry on the 10th; any visible "10" cell opens one directly.
      await tester.tap(find.widgetWithText(InkWell, '10').first);
      await tester.pumpAndSettle();
      expect(find.byType(EventDetailScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(EventDetailScreen), findsNothing);
      expect(calendarPosition(tester).pixels, before);
    });
  });
}
