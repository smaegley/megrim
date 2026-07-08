import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/models/json_fields.dart';
import 'package:megrim/models/med_entry.dart';
import 'package:megrim/repositories/megrim_repository.dart';
import 'package:megrim/screens/event_detail_screen.dart';

/// Drives the Medications section added to Event Detail (backlog item #6): the schema, vocab and
/// export already supported meds, but there was no UI to add them. Exercises add → learn → remove.
void main() {
  late MegrimDatabase db;
  late MegrimRepository repo;
  late String eventId;

  setUp(() async {
    db = MegrimDatabase.forTesting(NativeDatabase.memory());
    repo = MegrimRepository(db: db);
    eventId = await repo.startEvent(severity: 5);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpDetail(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: EventDetailScreen(repo: repo, eventId: eventId),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('add a medication: it renders and the name is learned into vocab',
      (tester) async {
    await pumpDetail(tester);

    // The medication vocab starts empty (learned from entries).
    expect(await repo.vocab(VocabKind.medication), isEmpty);

    await tester.scrollUntilVisible(find.text('Add medication'), 300);
    await tester.tap(find.text('Add medication'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Sumatriptan');
    await tester.enterText(
        find.widgetWithText(TextField, 'Dose (optional)'), '50 mg');
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    // Tile shows name + dose; the name was learned into the medication vocab.
    expect(find.text('Sumatriptan'), findsOneWidget);
    expect(find.text('50 mg'), findsOneWidget);
    expect(await repo.vocab(VocabKind.medication), contains('Sumatriptan'));
  });

  testWidgets('remove a medication clears its tile', (tester) async {
    await pumpDetail(tester);

    await tester.scrollUntilVisible(find.text('Add medication'), 300);
    await tester.tap(find.text('Add medication'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Ibuprofen');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('Ibuprofen'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove medication'));
    await tester.pumpAndSettle();
    expect(find.text('Ibuprofen'), findsNothing);
  });

  test('meds encode/decode round-trips through the meds_taken column', () async {
    final meds = [
      const MedEntry(name: 'Rizatriptan', dose: '10 mg', helped: true),
      const MedEntry(name: 'Ibuprofen'),
    ];
    final raw = encodeMeds(meds);
    final decoded = decodeMeds(raw);
    expect(decoded.map((m) => m.name), ['Rizatriptan', 'Ibuprofen']);
    expect(decoded.first.dose, '10 mg');
    expect(decoded.first.helped, isTrue);
    expect(decoded.last.dose, isNull);
  });
}
