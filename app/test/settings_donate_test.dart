import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/repositories/megrim_repository.dart';
import 'package:megrim/screens/settings_screen.dart';

/// The Donate tile is hidden on iOS: an external tip link is allowed only on the US App Store, and
/// one binary serves every storefront (docs/APP_STORE.md). Android keeps it.
void main() {
  Future<bool> donateShown(WidgetTester tester, TargetPlatform platform) async {
    debugDefaultTargetPlatformOverride = platform;
    final db = MegrimDatabase.forTesting(NativeDatabase.memory());
    try {
      await tester.pumpWidget(MaterialApp(home: SettingsScreen(repo: MegrimRepository(db: db))));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Source code'), 200);
      return find.text('Donate').evaluate().isNotEmpty;
    } finally {
      debugDefaultTargetPlatformOverride = null;
      await tester.pumpWidget(const SizedBox.shrink());
      await db.close();
    }
  }

  testWidgets('Android shows the Donate tile', (tester) async {
    expect(await donateShown(tester, TargetPlatform.android), isTrue);
  });

  testWidgets('iOS hides the Donate tile', (tester) async {
    expect(await donateShown(tester, TargetPlatform.iOS), isFalse);
  });
}
