import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/analytics/dashboard.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/models/json_fields.dart';
import 'package:megrim/repositories/megrim_repository.dart';
import 'package:megrim/screens/analytics_screen.dart';
import 'package:megrim/screens/event_detail_screen.dart';
import 'package:megrim/screens/history_screen.dart';
import 'package:megrim/screens/quick_log_screen.dart';
import 'package:megrim/widgets/monthly_days_card.dart';
import 'package:megrim/widgets/severity_badge.dart';

/// The schema v4 attack fields on screen: "Headache?" (backlog #26), Impact (#22a) and Symptoms
/// (#20) in Event Detail, the Headache control in Quick Log, and the History label.

Finder headache(String label) =>
    find.descendant(of: find.byType(HeadacheSelector), matching: find.text(label));

Set<int> headacheSelection(WidgetTester tester) => tester
    .widget<SegmentedButton<int>>(find.descendant(
        of: find.byType(HeadacheSelector), matching: find.byType(SegmentedButton<int>)))
    .selected;

/// Drift's stream-close timer only starts once its StreamBuilder disposes (see
/// history_calendar_tap_test.dart); Quick Log's elapsed-time ticker is cancelled the same way.
Future<void> disposeAndDrain(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

/// Quick Log ticks every second, so it never settles: pump a few short frames instead.
Future<void> pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late MegrimDatabase db;
  late MegrimRepository repo;

  setUp(() {
    db = MegrimDatabase.forTesting(NativeDatabase.memory());
    repo = MegrimRepository(db: db);
  });

  tearDown(() async => db.close());

  group('Event Detail', () {
    testWidgets('No hides severity and head location; Save clears them and keeps the rest',
        (tester) async {
      final id = await repo.startEvent(severity: 6);
      await db.update(db.migraineEvents).write(
          MigraineEventsCompanion(locationHead: Value(encodeStringList(['Forehead']))));
      await tester.pumpWidget(MaterialApp(home: EventDetailScreen(repo: repo, eventId: id)));
      await tester.pumpAndSettle();

      expect(headacheSelection(tester), {1}, reason: 'Quick Log starts attacks at Yes');
      expect(find.text('Severity: 6 / 10'), findsOneWidget);
      expect(find.text('Head location'), findsOneWidget);

      await tester.tap(headache('No'));
      await tester.pumpAndSettle();
      expect(find.text('Severity: 6 / 10'), findsNothing);
      expect(find.text('Head location'), findsNothing);
      expect(find.textContaining('without headache'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Reduced'), 200);
      await tester.tap(find.text('Reduced'));
      await tester.scrollUntilVisible(find.widgetWithText(FilterChip, 'Fatigue'), 300);
      await tester.tap(find.widgetWithText(FilterChip, 'Fatigue'));
      await tester.tap(find.widgetWithText(FilterChip, 'Vertigo'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();

      final saved = (await repo.getEvent(id))!;
      expect(saved.headachePresent, isFalse);
      expect(saved.severity, isNull);
      expect(saved.locationHead, isNull);
      expect(saved.impact, EventImpact.reduced);
      expect(decodeStringList(saved.symptoms), unorderedEquals(['Fatigue', 'Vertigo']));
    });

    testWidgets('an existing entry from before v4 shows Not sure, and keeps its severity',
        (tester) async {
      final id = await repo.startEvent(severity: 4, headachePresent: null);
      await tester.pumpWidget(MaterialApp(home: EventDetailScreen(repo: repo, eventId: id)));
      await tester.pumpAndSettle();
      expect(headacheSelection(tester), {-1});
      expect(find.text('Severity: 4 / 10'), findsOneWidget, reason: 'Not sure counts as headache');

      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();
      final saved = (await repo.getEvent(id))!;
      expect(saved.headachePresent, isNull);
      expect(saved.severity, 4);
      expect(saved.impact, isNull, reason: 'impact left blank stays blank');
    });

    testWidgets('a new past entry starts at Yes, and Impact can be cleared again', (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: EventDetailScreen(
              repo: repo, draft: EventDraft(startedAt: DateTime(2026, 10, 20, 12)))));
      await tester.pumpAndSettle();
      expect(headacheSelection(tester), {1});

      await tester.scrollUntilVisible(find.text('Unable'), 200);
      await tester.tap(find.text('Unable'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unable'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();
      final saved = (await db.select(db.migraineEvents).get()).single;
      expect(saved.headachePresent, isTrue);
      expect(saved.impact, isNull);
    });
  });

  group('Quick Log', () {
    testWidgets('No hides the slider and clears the severity; Yes puts it back', (tester) async {
      final id = await repo.startEvent(severity: 7);
      await tester.pumpWidget(MaterialApp(home: QuickLogScreen(repo: repo)));
      await pumpFrames(tester);
      expect(find.text('Severity: 7 / 10'), findsOneWidget);

      await tester.tap(headache('No'));
      await pumpFrames(tester);
      expect(find.byType(Slider), findsNothing);
      var row = (await repo.getEvent(id))!;
      expect(row.headachePresent, isFalse);
      expect(row.severity, isNull);

      await tester.tap(headache('Yes'));
      await pumpFrames(tester);
      expect(find.text('Severity: 5 / 10'), findsOneWidget);
      row = (await repo.getEvent(id))!;
      expect(row.headachePresent, isTrue);
      expect(row.severity, 5);
      await disposeAndDrain(tester);
    });
  });

  group('History', () {
    testWidgets('an attack without headache is labelled from what was recorded', (tester) async {
      final at = DateTime.utc(2026, 10, 20, 9);
      Future<void> add(String id, {bool? headache, bool? aura, List<String> symptoms = const []}) =>
          db.into(db.migraineEvents).insert(MigraineEventsCompanion.insert(
                id: id,
                startedAt: at.add(Duration(days: id.codeUnitAt(0) - 97)),
                endedAt: Value(at.add(Duration(days: id.codeUnitAt(0) - 97, hours: 3))),
                headachePresent: Value(headache),
                auraPresent: Value(aura),
                symptoms: Value(encodeStringList(symptoms)),
                severity: Value(headache == false ? null : 6),
                createdAt: at,
                updatedAt: at,
              ));
      await add('a', headache: false, aura: true);
      await add('b', headache: false, symptoms: ['Dizziness']);
      await add('c', headache: false, symptoms: ['Fatigue']);
      await add('d');

      await tester.pumpWidget(MaterialApp(home: HistoryScreen(repo: repo)));
      await tester.pumpAndSettle();
      expect(find.textContaining('No headache · with aura'), findsOneWidget);
      expect(find.textContaining('No headache · with vertigo'), findsOneWidget);
      expect(find.text('No headache'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is SeverityBadge && w.noHeadache), findsNWidgets(3));
      expect(find.textContaining('Severity 6/10'), findsOneWidget);
      await disposeAndDrain(tester);
    });
  });

  group('Analytics', () {
    testWidgets('the monthly card says how many days were without headache', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MonthlyDaysCard(
              now: DateTime(2026, 10, 15),
              dash: const DashboardResult(
                summary: Summary(totalEvents: 5),
                migraineDaysLast30: 5,
                migraineDaysWithoutHeadacheLast30: 2,
                migraineDaysByMonth: [MonthDays(2026, 9, 3, 1), MonthDays(2026, 10, 5, 2)],
              ),
            ),
          ),
        ),
      ));
      expect(find.text('Last 30 days\nincluding 2 without headache'), findsOneWidget);
      expect(find.textContaining('days with only attacks without headache'), findsOneWidget);
      expect(
          find.bySemanticsLabel(RegExp(r'Oct 2026 so far: 5 days, 2 without headache; '
              r'Sep 2026: 3 days, 1 without headache')),
          findsOneWidget);
      handle.dispose();
    });

    testWidgets('no headache-free days: the card reads as before', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MonthlyDaysCard(
              now: DateTime(2026, 10, 15),
              dash: const DashboardResult(
                summary: Summary(totalEvents: 1),
                migraineDaysLast30: 1,
                migraineDaysByMonth: [MonthDays(2026, 10, 1)],
              ),
            ),
          ),
        ),
      ));
      expect(find.text('Last 30 days'), findsOneWidget);
      expect(find.textContaining('without headache'), findsNothing);
    });

    testWidgets('the tab shows the Symptoms and Impact cards once there is data',
        (tester) async {
      // 10:00 local, so a 2-hour attack never runs past midnight into a second day.
      final today = DateTime.now();
      for (var i = 0; i < 3; i++) {
        final at = DateTime(today.year, today.month, today.day - 2 - i * 3, 10).toUtc();
        await db.into(db.migraineEvents).insert(MigraineEventsCompanion.insert(
              id: 'e$i',
              startedAt: at,
              endedAt: Value(at.add(const Duration(hours: 2))),
              headachePresent: Value(i == 0 ? false : true),
              symptoms: Value(encodeStringList(i == 0 ? ['Fatigue'] : ['Nausea', 'Fatigue'])),
              impact: Value(i == 2 ? EventImpact.unable : EventImpact.reduced),
              createdAt: at,
              updatedAt: at,
            ));
      }
      await tester.pumpWidget(MaterialApp(home: AnalyticsScreen(repo: repo, refreshToken: 0)));
      await tester.pumpAndSettle();

      // The monthly chart scrolls sideways too; scroll the tab's own list.
      final list = find
          .byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down)
          .first;
      await tester.scrollUntilVisible(find.text('Most common symptoms'), 300, scrollable: list);
      expect(find.text('Fatigue'), findsOneWidget);
      expect(find.text('3 · 100%'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Impact on the day'), 300, scrollable: list);
      expect(find.text('Unable to function'), findsOneWidget);

      expect(find.textContaining('Impact recorded on 3 of 3 migraine days'), findsOneWidget);
      await disposeAndDrain(tester);
    });
  });
}
