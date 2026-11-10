import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/repositories/megrim_repository.dart';
import 'package:megrim/screens/manage_vocab_screen.dart';

/// Manage vocabulary shows each value as displayed (translated for defaults) and starts a rename
/// from that text. Saving it unchanged keeps the stored value; a real edit stores the new text
/// (docs/TRANSLATIONS.md, "Data stays English").
void main() {
  Future<MegrimRepository> pump(WidgetTester tester) async {
    final db = MegrimDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = MegrimRepository(db: db);
    await tester.pumpWidget(MaterialApp(
        home: ManageVocabScreen(repo: repo, kind: VocabKind.trigger, title: 'Suspected triggers')));
    await tester.pumpAndSettle();
    return repo;
  }

  Future<void> rename(WidgetTester tester, String from, String? to) async {
    final tile = find.ancestor(of: find.text(from), matching: find.byType(ListTile));
    await tester.tap(find.descendant(of: tile, matching: find.byTooltip('Rename')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, from), findsOneWidget);
    if (to != null) await tester.enterText(find.byType(TextField), to);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  testWidgets('the title and tooltip read as before', (tester) async {
    await pump(tester);
    expect(find.text('Manage suspected triggers'), findsOneWidget);
    expect(find.byTooltip('Add suspected triggers'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('saving a rename unchanged keeps the stored value', (tester) async {
    final repo = await pump(tester);
    final before = await tester.runAsync(() => repo.vocab(VocabKind.trigger));
    await rename(tester, 'Stress', null);
    expect(await tester.runAsync(() => repo.vocab(VocabKind.trigger)), before);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a real rename stores the new text', (tester) async {
    final repo = await pump(tester);
    await rename(tester, 'Stress', 'Work stress');
    final after = (await tester.runAsync(() => repo.vocab(VocabKind.trigger)))!;
    expect(after, contains('Work stress'));
    expect(after, isNot(contains('Stress')));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
