import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/repositories/megrim_repository.dart';
import 'package:megrim/screens/analytics_screen.dart';

/// Regression: _reload()'s setState callback must not RETURN the _load() Future — with an arrow
/// body it did, and Flutter's debug-only assert threw "setState() callback argument returned a
/// Future" on every tab-reopen/refresh (found by Steve in the simulator; release builds skip
/// asserts, so it never showed on-device).
///
/// NB: AnalyticsScreen cannot be pumped to settlement in this suite (connectivity_plus's
/// platform channel never resolves without a mock) — bounded pump()s only, never pumpAndSettle.
void main() {
  testWidgets('bumping refreshToken reloads without throwing', (tester) async {
    final db = MegrimDatabase.forTesting(NativeDatabase.memory());
    final repo = MegrimRepository(db: db);

    await tester.pumpWidget(
        MaterialApp(home: AnalyticsScreen(repo: repo, refreshToken: 0)));
    await tester.pump(const Duration(milliseconds: 50));

    // Same position, new refreshToken → didUpdateWidget → _reload().
    await tester.pumpWidget(
        MaterialApp(home: AnalyticsScreen(repo: repo, refreshToken: 1)));
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    await db.close();
  });
}
