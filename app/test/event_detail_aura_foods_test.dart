import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/repositories/megrim_repository.dart';
import 'package:megrim/screens/event_detail_screen.dart';

/// Drives the Aura description and Foods notable sections added to Event Detail: the schema
/// (`aura_description`, `foods_notable`), and export/import already supported both, but there was
/// no UI to view or edit them (same gap class as the meds section — see
/// event_detail_meds_test.dart).
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

  group('Aura description', () {
    testWidgets('is hidden until aura is set to Yes', (tester) async {
      await pumpDetail(tester);
      expect(find.text('Aura description (optional)'), findsNothing);

      await tester.scrollUntilVisible(find.text('Yes'), 300);
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();
      expect(find.text('Aura description (optional)'), findsOneWidget);

      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();
      expect(find.text('Aura description (optional)'), findsNothing);
    });

    testWidgets('entered text persists to the database on save', (tester) async {
      await pumpDetail(tester);

      await tester.scrollUntilVisible(find.text('Yes'), 300);
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, 'Aura description (optional)'),
          'shimmering zigzag lines');

      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();

      final saved = await repo.getEvent(eventId);
      expect(saved!.auraPresent, isTrue);
      expect(saved.auraDescription, 'shimmering zigzag lines');
    });
  });

  group('Foods notable', () {
    testWidgets('adding a food renders it as a chip', (tester) async {
      await pumpDetail(tester);

      await tester.scrollUntilVisible(find.text('Add food'), 300);
      await tester.tap(find.text('Add food'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.descendant(
              of: find.byType(AlertDialog), matching: find.byType(TextField)),
          'Red wine');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      expect(find.text('Red wine'), findsOneWidget);
    });

    testWidgets('removing a food chip clears it', (tester) async {
      await pumpDetail(tester);

      await tester.scrollUntilVisible(find.text('Add food'), 300);
      await tester.tap(find.text('Add food'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.descendant(
              of: find.byType(AlertDialog), matching: find.byType(TextField)),
          'Chocolate');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      expect(find.text('Chocolate'), findsOneWidget);

      // Only one chip (and so only one delete icon) exists at this point.
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();
      expect(find.text('Chocolate'), findsNothing);
    });

    testWidgets('persists to the database on save', (tester) async {
      await pumpDetail(tester);

      await tester.scrollUntilVisible(find.text('Add food'), 300);
      await tester.tap(find.text('Add food'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.descendant(
              of: find.byType(AlertDialog), matching: find.byType(TextField)),
          'Aged cheese');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();

      final saved = await repo.getEvent(eventId);
      expect(saved!.foodsNotable, contains('Aged cheese'));
    });
  });
}
