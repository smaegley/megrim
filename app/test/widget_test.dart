import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/app.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/repositories/megrim_repository.dart';

void main() {
  testWidgets('first run shows the onboarding welcome, not the main shell',
      (tester) async {
    final db = MegrimDatabase.forTesting(NativeDatabase.memory());
    final repo = MegrimRepository(db: db);

    await tester.pumpWidget(MegrimApp(repo: repo));
    await tester.pumpAndSettle();

    // Onboarding gate: no disclaimer accepted + no home location → welcome screen.
    expect(find.text('Welcome to Megrim'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);

    await db.close();
  });

  testWidgets('disclaimer gate blocks Continue until accepted', (tester) async {
    final db = MegrimDatabase.forTesting(NativeDatabase.memory());
    final repo = MegrimRepository(db: db);

    await tester.pumpWidget(MegrimApp(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('I understand and accept.'), findsOneWidget);
    // Continue is disabled until the checkbox is ticked.
    final continueBtn =
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'));
    expect(continueBtn.onPressed, isNull);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    final continueBtn2 =
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'));
    expect(continueBtn2.onPressed, isNotNull);

    await db.close();
  });
}
