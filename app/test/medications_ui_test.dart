import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/models/json_fields.dart';
import 'package:megrim/repositories/megrim_repository.dart';
import 'package:megrim/screens/event_detail_screen.dart';
import 'package:megrim/screens/medications_screen.dart';

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

    testWidgets('relief tried: pick a suggestion, answer "helped?", saved with the entry',
        (tester) async {
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
      expect(decodeRelief(e!.reliefTried).map((r) => (r.name, r.helped)),
          [('Dark room', true), ('Ginger tea', null)]);
    });

    testWidgets('a dose on a multi-day entry asks which day it was taken', (tester) async {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day - 2, 9).toUtc();
      await db.into(db.migraineEvents).insert(MigraineEventsCompanion.insert(
            id: 'long',
            startedAt: start,
            endedAt: Value(DateTime(now.year, now.month, now.day, 8).toUtc()),
            createdAt: start,
            updatedAt: start,
          ));
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
}
