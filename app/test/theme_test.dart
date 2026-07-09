import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/app.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/repositories/megrim_repository.dart';
import 'package:megrim/theme.dart';

/// Backlog #8: the app should ship a light and a dark theme and follow the OS setting.
void main() {
  test('light/dark themes have the right brightness and pinned card surfaces', () {
    expect(megrimLightTheme().brightness, Brightness.light);
    expect(megrimDarkTheme().brightness, Brightness.dark);
    // The chart card surfaces the analytics palettes were validated against.
    expect(megrimDarkTheme().cardColor, kDarkCardSurface);
    expect(megrimLightTheme().cardColor, kLightCardSurface);
  });

  testWidgets('root MaterialApp wires both themes + ThemeMode.system', (tester) async {
    final db = MegrimDatabase.forTesting(NativeDatabase.memory());
    final repo = MegrimRepository(db: db);

    await tester.pumpWidget(MegrimApp(repo: repo));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.system);
    expect(app.theme?.brightness, Brightness.light);
    expect(app.darkTheme?.brightness, Brightness.dark);

    await db.close();
  });
}
