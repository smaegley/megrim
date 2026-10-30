import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/models/json_fields.dart';
import 'package:megrim/repositories/megrim_repository.dart';
import 'package:megrim/screens/analytics_screen.dart';
import 'package:megrim/screens/checkin_screen.dart';
import 'package:megrim/screens/event_detail_screen.dart';
import 'package:megrim/screens/history_screen.dart';
import 'package:megrim/screens/quick_log_screen.dart';
import 'package:megrim/services/import_service.dart';

/// Backlog #16 in the UI: "No migraine today" on Quick Log, marking a past day clear from the
/// History calendar, the optional details, and an entry replacing a check-in.

/// See history_calendar_tap_test.dart: Drift closes stream resources on a timer.
Future<void> disposeAndDrain(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

DateTime todayDate() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

void main() {
  late MegrimDatabase db;
  late MegrimRepository repo;

  setUp(() {
    db = MegrimDatabase.forTesting(NativeDatabase.memory());
    repo = MegrimRepository(db: db);
  });
  tearDown(() => db.close());

  group('Quick Log', () {
    testWidgets('one tap checks today in; Undo takes it back', (t) async {
      await t.pumpWidget(MaterialApp(home: QuickLogScreen(repo: repo)));
      await t.pumpAndSettle();
      await t.tap(find.text('NO MIGRAINE TODAY'));
      await t.pumpAndSettle();
      expect(await repo.checkinOn(todayDate()), isNotNull);
      expect(find.text('No migraine today'), findsOneWidget);
      expect(find.text('NO MIGRAINE TODAY'), findsNothing);

      await t.tap(find.text('Undo'));
      await t.pumpAndSettle();
      expect(await repo.checkinOn(todayDate()), isNull);
      expect(find.text('NO MIGRAINE TODAY'), findsOneWidget);
    });

    testWidgets('Add details opens the check-in, and what is saved is kept', (t) async {
      await repo.checkIn(todayDate());
      await t.pumpWidget(MaterialApp(home: QuickLogScreen(repo: repo)));
      await t.pumpAndSettle();
      await t.tap(find.text('Add details'));
      await t.pumpAndSettle();
      expect(find.byType(CheckinScreen), findsOneWidget);

      await t.tap(find.widgetWithText(FilterChip, 'Stress'));
      await t.enterText(find.widgetWithText(TextField, 'Sleep hours (prior night)'), '5.5');
      await t.tap(find.widgetWithText(TextButton, 'Save'));
      await t.pumpAndSettle();
      final c = (await repo.checkinOn(todayDate()))!;
      expect(decodeStringList(c.triggersSuspected), ['Stress']);
      expect(c.sleepHoursPrior, 5.5);
      expect(c.stressLevel, isNull, reason: 'the slider was never moved');
    });

    testWidgets('logging a migraine removes today\'s check-in and hides the button', (t) async {
      await repo.checkIn(todayDate());
      await t.pumpWidget(MaterialApp(home: QuickLogScreen(repo: repo)));
      await t.pumpAndSettle();
      await t.tap(find.text('LOG MIGRAINE'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(await repo.checkinOn(todayDate()), isNull);
      expect(find.textContaining('check-in was removed'), findsOneWidget);
      // End it: the idle view returns, and today now has an entry, so there's no button.
      await t.tap(find.text('MIGRAINE ENDED'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('LOG MIGRAINE'), findsOneWidget);
      expect(find.text('NO MIGRAINE TODAY'), findsNothing);
      await disposeAndDrain(t);
    });
  });

  group('History calendar', () {
    final today = DateTime(2024, 6, 15);

    Future<void> pumpCalendar(WidgetTester t) async {
      await t.pumpWidget(
        MaterialApp(
          home: HistoryScreen(repo: repo, todayOverride: today),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Calendar'));
      await t.pumpAndSettle();
    }

    testWidgets('a past day can be marked clear, and shows a tick', (t) async {
      await pumpCalendar(t);
      expect(find.byKey(const ValueKey('checkin-2024-06-10')), findsNothing);
      await t.tap(find.widgetWithText(InkWell, '10'));
      await t.pumpAndSettle();
      await t.tap(find.text('No migraine this day'));
      await t.pumpAndSettle();
      expect(await repo.checkinOn(DateTime(2024, 6, 10)), isNotNull);
      expect(find.byKey(const ValueKey('checkin-2024-06-10')), findsOneWidget);
      expect(find.text('Marked as a day without migraine'), findsOneWidget);
      await disposeAndDrain(t);
    });

    testWidgets('a checked-in day offers details and removal', (t) async {
      await repo.checkIn(DateTime(2024, 6, 10));
      await pumpCalendar(t);
      await t.tap(find.widgetWithText(InkWell, '10'));
      await t.pumpAndSettle();
      expect(find.text('No migraine this day'), findsNothing);
      await t.tap(find.text('Remove the check-in'));
      await t.pumpAndSettle();
      expect(await repo.checkinOn(DateTime(2024, 6, 10)), isNull);
      expect(find.byKey(const ValueKey('checkin-2024-06-10')), findsNothing);
      await disposeAndDrain(t);
    });

    testWidgets('a future day goes straight to a new entry', (t) async {
      await pumpCalendar(t);
      await t.tap(find.widgetWithText(InkWell, '20'));
      await t.pumpAndSettle();
      expect(find.byType(EventDetailScreen), findsOneWidget);
      await disposeAndDrain(t);
    });

    testWidgets('saving an entry on a checked-in day removes the check-in, with undo', (t) async {
      await repo.checkIn(DateTime(2024, 6, 10));
      await pumpCalendar(t);
      await t.tap(find.widgetWithText(InkWell, '10'));
      await t.pumpAndSettle();
      await t.tap(find.text('Log a migraine on this day'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Save'));
      await t.pumpAndSettle();
      expect(await repo.checkinOn(DateTime(2024, 6, 10)), isNull);
      expect(find.textContaining('Removed the "No migraine" check-in'), findsOneWidget);

      await t.tap(find.text('Undo'));
      await t.pumpAndSettle();
      expect(await repo.checkinOn(DateTime(2024, 6, 10)), isNotNull);
      // The entry wins on the calendar: no tick on a migraine day.
      expect(find.byKey(const ValueKey('checkin-2024-06-10')), findsNothing);
      await disposeAndDrain(t);
    });
  });

  testWidgets('the details screen can remove the check-in', (t) async {
    await repo.saveCheckinDetails(DateTime(2024, 6, 10), stress: 4);
    await t.pumpWidget(
      MaterialApp(
        home: CheckinScreen(repo: repo, day: DateTime(2024, 6, 10)),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Stress level: 4 / 5'), findsOneWidget);
    await t.tap(find.byTooltip('Remove check-in'));
    await t.pumpAndSettle();
    expect(await repo.checkinOn(DateTime(2024, 6, 10)), isNull);
    expect(await db.select(db.dayCheckins).get(), isEmpty);
  });

  group('Analytics', () {
    for (final narrow in [false, true]) {
      testWidgets('the planted dataset shows days tracked and the trigger'
          '${narrow ? ' (320 dp, 1.3× text)' : ''}', (t) async {
        if (narrow) {
          t.view.physicalSize = const Size(320, 2400);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
        }
        await ImportService(db).importJsonString(
          File('test/fixtures/datasets/07-checkins-planted-trigger.json').readAsStringSync(),
          replace: true,
        );
        final screen = AnalyticsScreen(repo: repo, refreshToken: 0);
        await t.pumpWidget(
          MaterialApp(
            home: narrow
                ? MediaQuery(
                    data: const MediaQueryData(
                      size: Size(320, 2400),
                      textScaler: TextScaler.linear(1.3),
                    ),
                    child: screen,
                  )
                : screen,
          ),
        );
        await t.pumpAndSettle();
        final list = find
            .byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down)
            .first;
        await t.scrollUntilVisible(find.text('Days tracked'), 300, scrollable: list);
        expect(find.textContaining('days since your first check-in'), findsOneWidget);
        await t.scrollUntilVisible(find.text('Migraine days vs clear days'), 300, scrollable: list);
        await t.scrollUntilVisible(find.text('Trigger noted: Bright light'), 100, scrollable: list);
        expect(find.textContaining('15 migraine days and 45 clear days'), findsOneWidget);
        await t.tap(find.textContaining('and the caveats'));
        await t.pumpAndSettle();
        expect(find.textContaining('Recall bias'), findsOneWidget);
        // Layout overflows fail the test by themselves.
      });
    }

    testWidgets('without a check-in, neither card shows', (t) async {
      await ImportService(db).importJsonString(
        File('test/fixtures/datasets/04-mixed-no-signal.json').readAsStringSync(),
        replace: true,
      );
      await t.pumpWidget(MaterialApp(home: AnalyticsScreen(repo: repo, refreshToken: 0)));
      await t.pumpAndSettle();
      final list = find
          .byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down)
          .first;
      await t.scrollUntilVisible(find.text('Most-tagged triggers'), 300, scrollable: list);
      expect(find.text('Days tracked'), findsNothing);
      expect(find.text('Migraine days vs clear days'), findsNothing);
    });
  });
}
