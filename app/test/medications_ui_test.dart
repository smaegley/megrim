import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/models/json_fields.dart';
import 'package:megrim/repositories/megrim_repository.dart';
import 'package:megrim/screens/event_detail_screen.dart';
import 'package:megrim/screens/medications_screen.dart';
import 'package:megrim/analytics/dashboard.dart';
import 'package:megrim/models/med_entry.dart';
import 'package:megrim/models/medications.dart';
import 'package:megrim/models/relief_entry.dart';
import 'package:megrim/widgets/medication_cards.dart';
import 'package:megrim/widgets/monthly_days_card.dart';

/// Backlog #18 / #19 on screen: the class prompt on Event Detail, Relief tried, the day of a
/// dose on a multi-day entry, and Settings › Medications.
void main() {
  late MegrimDatabase db;
  late MegrimRepository repo;

  setUp(() {
    db = MegrimDatabase.forTesting(NativeDatabase.memory());
    repo = MegrimRepository(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  /// Scroll [f] fully into view (Event Detail's page, or a tall dialog) and tap it.
  Future<void> tapIn(WidgetTester tester, Finder f) async {
    if (f.evaluate().isEmpty) await tester.scrollUntilVisible(f, 300);
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> addMed(WidgetTester tester, String name) async {
    await tapIn(tester, find.text('Add medication'));
    await tester.enterText(find.widgetWithText(TextField, 'Name'), name);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
  }

  group('Event Detail', () {
    testWidgets('a name already known never asks for its class', (tester) async {
      await repo.addVocab(VocabKind.medication, 'Ibuprofen');
      final id = await repo.startEvent(severity: 5);
      await pump(tester, EventDetailScreen(repo: repo, eventId: id));
      await addMed(tester, 'Ibuprofen');
      expect(find.text('What kind of medication is Ibuprofen?'), findsNothing);
      expect(find.text('Ibuprofen'), findsOneWidget);
    });

    testWidgets('dismissing the class question leaves the class unset', (tester) async {
      final id = await repo.startEvent(severity: 5);
      await pump(tester, EventDetailScreen(repo: repo, eventId: id));
      await addMed(tester, 'Rizatriptan');
      expect(find.text('What kind of medication is Rizatriptan?'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5)); // outside the dialog
      await tester.pumpAndSettle();
      expect(find.text('Rizatriptan'), findsOneWidget);
      expect(await repo.medicationClassOf('Rizatriptan'), isNull);
    });

    testWidgets('relief tried: pick a suggestion, answer "helped?", saved with the entry', (
      tester,
    ) async {
      final id = await repo.startEvent(severity: 5);
      await pump(tester, EventDetailScreen(repo: repo, eventId: id));
      await tapIn(tester, find.text('Add relief'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Dark room'));
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Yes')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('Dark room'), findsOneWidget);

      // A typed name is learned into the relief vocabulary.
      await tapIn(tester, find.text('Add relief'));
      await tester.enterText(find.widgetWithText(TextField, 'What did you try?'), 'Ginger tea');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(await repo.vocab(VocabKind.relief), contains('Ginger tea'));

      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();
      final e = await repo.getEvent(id);
      expect(decodeRelief(e!.reliefTried).map((r) => (r.name, r.helped)), [
        ('Dark room', true),
        ('Ginger tea', null),
      ]);
    });

    testWidgets('a dose on a multi-day entry asks which day it was taken', (tester) async {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day - 2, 9).toUtc();
      await db
          .into(db.migraineEvents)
          .insert(
            MigraineEventsCompanion.insert(
              id: 'long',
              startedAt: start,
              endedAt: Value(DateTime(now.year, now.month, now.day, 8).toUtc()),
              createdAt: start,
              updatedAt: start,
            ),
          );
      await pump(tester, EventDetailScreen(repo: repo, eventId: 'long'));
      await tapIn(tester, find.text('Add medication'));
      await tester.tap(find.text('Time taken'));
      await tester.pumpAndSettle();
      expect(find.text('Day taken'), findsOneWidget);
    });

    testWidgets('a single-day entry goes straight to the time', (tester) async {
      final id = await repo.startEvent(severity: 5);
      await pump(tester, EventDetailScreen(repo: repo, eventId: id));
      await tapIn(tester, find.text('Add medication'));
      await tester.tap(find.text('Time taken'));
      await tester.pumpAndSettle();
      expect(find.text('Day taken'), findsNothing);
      expect(find.byType(TimePickerDialog), findsOneWidget);
    });
  });

  group('Settings › Medications', () {
    testWidgets('shows each medication\'s class and changes it', (tester) async {
      await repo.addVocab(VocabKind.medication, 'Sumatriptan');
      await repo.addVocab(VocabKind.medication, 'Mystery pill');
      await repo.setMedicationClass('Sumatriptan', MedClass.triptan);
      await pump(tester, MedicationsScreen(repo: repo));
      expect(find.text('Triptan'), findsOneWidget);
      expect(find.text('No class set'), findsOneWidget);

      await tester.tap(find.text('Mystery pill'));
      await tester.pumpAndSettle();
      await tapIn(tester, find.text('Anti-nausea'));
      expect(find.text('Anti-nausea'), findsOneWidget);
      expect(await repo.medicationClassOf('Mystery pill'), MedClass.antiemetic);

      // "Not set" clears it again.
      await tester.tap(find.text('Mystery pill'));
      await tester.pumpAndSettle();
      await tapIn(tester, find.text('Not set'));
      expect(await repo.medicationClassOf('Mystery pill'), isNull);
    });

    testWidgets('add a preventive, then mark it stopped', (tester) async {
      await pump(tester, MedicationsScreen(repo: repo));
      await tester.tap(find.text('Add preventive'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Propranolol');
      await tester.enterText(find.widgetWithText(TextField, 'Dose (optional)'), '40 mg');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('Propranolol · 40 mg'), findsOneWidget);
      expect(find.textContaining('Since '), findsOneWidget);
      expect((await repo.preventives()).single.stoppedOn, isNull);

      await tester.tap(find.text('Propranolol · 40 mg'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Still taking it'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK')); // the date picker, on today
      await tester.pumpAndSettle();
      expect(find.text('Stopped'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Since '), findsNothing);
      expect((await repo.preventives()).single.stoppedOn, isNotNull);

      await tester.tap(find.text('Propranolol · 40 mg'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(await repo.preventives(), isEmpty);
    });
  });

  group('Analytics cards', () {
    final today = DateTime(2026, 10, 15, 12);
    EventStat stat(DateTime day, List<MedEntry> meds, {List<ReliefEntry> relief = const []}) =>
        EventStat(
          startedAt: DateTime(day.year, day.month, day.day, 12).toUtc(),
          severity: 5,
          meds: meds,
          relief: relief,
        );

    /// Triptans on the first [n] days of July, August and September.
    List<EventStat> triptanMonths(int n) => [
      for (final m in [7, 8, 9])
        for (var d = 1; d <= n; d++) stat(DateTime(2026, m, d), const [MedEntry(name: 'Suma')]),
    ];

    Future<void> pumpCard(WidgetTester tester, Widget card) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: card)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the notice states counts and levels, and never diagnoses', (tester) async {
      final dash = computeDashboard(
        triptanMonths(11),
        now: today,
        medClasses: const {'Suma': MedClass.triptan},
      );
      await pumpCard(tester, MedicationDaysCard(dash: dash, now: today));
      expect(find.text(kOveruseNoticeTitle), findsOneWidget);
      expect(find.text('Jul 2026: Triptan on 11 days (level 10)'), findsOneWidget);
      expect(find.text('Sep 2026: Triptan on 11 days (level 10)'), findsOneWidget);
      final body = kOveruseNoticeBody.toLowerCase();
      for (final phrase in [
        'you have medication',
        'you have mo',
        'diagnosed',
        'stop taking',
        'stop using',
        'reduce your',
        'cut down',
      ]) {
        expect(body.contains(phrase), isFalse, reason: 'notice must not say "$phrase"');
      }
      expect(body, contains('not a diagnosis'));
      expect(body, contains('doctor'));
    });

    testWidgets('no notice under the level; unclassified names are listed with a way to fix', (
      tester,
    ) async {
      var tapped = false;
      final dash = computeDashboard(
        [
          ...triptanMonths(9),
          stat(DateTime(2026, 10, 10), const [MedEntry(name: 'Mystery pill')]),
        ],
        now: today,
        medClasses: const {'Suma': MedClass.triptan},
      );
      await pumpCard(
        tester,
        MedicationDaysCard(dash: dash, now: today, onSetClasses: () => tapped = true),
      );
      expect(find.text(kOveruseNoticeTitle), findsNothing);
      expect(find.text('Acute medication days'), findsOneWidget);
      expect(find.textContaining('1 medication has no class (Mystery pill)'), findsOneWidget);
      await tester.tap(find.text('Set classes'));
      expect(tapped, isTrue);
    });

    testWidgets('both cards render nothing without medications or relief', (tester) async {
      final dash = computeDashboard([stat(DateTime(2026, 10, 1), const [])], now: today);
      await pumpCard(
        tester,
        Column(
          children: [
            MedicationDaysCard(dash: dash),
            WhatHelpedCard(dash: dash),
          ],
        ),
      );
      expect(find.text('Acute medication days'), findsNothing);
      expect(find.text('What helped'), findsNothing);
    });

    testWidgets('what helped shows the share among answered tries', (tester) async {
      final dash = computeDashboard([
        stat(
          DateTime(2026, 10, 1),
          const [MedEntry(name: 'Suma', helped: true)],
          relief: const [ReliefEntry(name: 'Dark room', helped: false)],
        ),
        stat(DateTime(2026, 10, 2), const [
          MedEntry(name: 'Suma', helped: false),
          MedEntry(name: 'Suma'),
        ]),
      ], now: today);
      await pumpCard(tester, WhatHelpedCard(dash: dash));
      expect(find.text('helped 50% (2 answered, 1 unknown)'), findsOneWidget);
      expect(find.text('helped 0% (1 answered)'), findsOneWidget);
      expect(find.text('Relief tried'), findsOneWidget);
    });

    testWidgets('preventives are marked on the migraine days chart', (tester) async {
      await repo.savePreventive(name: 'Propranolol', startedOn: '2026-08-04');
      await repo.savePreventive(
        name: 'Topiramate',
        startedOn: '2026-06-01',
        stoppedOn: '2026-08-20',
      );
      await db
          .into(db.migraineEvents)
          .insert(
            MigraineEventsCompanion.insert(
              id: 'a',
              startedAt: DateTime.utc(2026, 5, 3, 12),
              createdAt: today,
              updatedAt: today,
            ),
          );
      final dash = await repo.dashboard(now: today);
      await pumpCard(tester, MonthlyDaysCard(dash: dash, now: today));
      expect(
        find.text(
          'Preventives (▲ started, ▼ stopped): Topiramate Jun 2026 – Aug 2026; '
          'Propranolol from Aug 2026.',
        ),
        findsOneWidget,
      );
      expect(find.text('▲'), findsOneWidget); // June
      expect(find.text('▲▼'), findsOneWidget); // August: one started, one stopped
    });

    testWidgets('the cards fit a 320 dp screen at 1.3× text with long names', (tester) async {
      tester.view.physicalSize = const Size(320, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const long = 'Paracetamol with codeine and caffeine (generic, 500/30/30)';
      final dash = computeDashboard(
        [
          ...triptanMonths(6),
          for (final m in [7, 8, 9])
            for (var d = 10; d <= 15; d++)
              stat(
                DateTime(2026, m, d),
                const [MedEntry(name: long, helped: true)],
                relief: const [ReliefEntry(name: 'Lying down in a dark, quiet, cool room')],
              ),
          stat(DateTime(2026, 10, 3), const [MedEntry(name: 'Another unnamed tablet')]),
        ],
        now: today,
        medClasses: const {'Suma': MedClass.triptan, long: MedClass.combinationAnalgesic},
      );
      expect(dash.medicationDays!.notice, isNotNull, reason: 'the mix reaches 10 days');
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(320, 2400), textScaler: TextScaler.linear(1.3)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    MedicationDaysCard(dash: dash, now: today, onSetClasses: () {}),
                    WhatHelpedCard(dash: dash),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Layout overflows fail the test by themselves.
      expect(find.text(kOveruseNoticeTitle), findsOneWidget);
    });
  });
}
