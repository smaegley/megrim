import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/repositories/megrim_repository.dart';
import 'package:megrim/screens/onboarding_screen.dart';
import 'package:megrim/screens/quick_log_screen.dart';

/// Regression guard for overflow found on a Nexus S (API 26) emulator: Onboarding and Quick Log
/// were the only two screens built with a plain, non-scrollable Column, so on a small screen (or
/// in landscape, where height shrinks a lot) content clipped instead of scrolling — at one point
/// making the "MIGRAINE ENDED" button unreachable. A RenderFlex overflow is a framework error
/// flutter_test surfaces via tester.takeException(), so asserting it's null after pumping at a
/// small/landscape size is a real check, not just a smoke test.
void main() {
  Future<void> setViewport(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('Onboarding at a small/landscape viewport', () {
    late MegrimDatabase db;
    late MegrimRepository repo;

    setUp(() {
      db = MegrimDatabase.forTesting(NativeDatabase.memory());
      repo = MegrimRepository(db: db);
    });
    tearDown(() => db.close());

    Future<void> pumpOnboarding(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: OnboardingScreen(repo: repo, onComplete: () {}),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('welcome + disclaimer steps do not overflow at Nexus-S portrait size',
        (tester) async {
      await setViewport(tester, const Size(320, 480));
      await pumpOnboarding(tester);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('location step does not overflow at Nexus-S portrait size',
        (tester) async {
      await setViewport(tester, const Size(320, 480));
      await pumpOnboarding(tester);

      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Your home location'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('location step does not overflow in a small landscape size',
        (tester) async {
      // Landscape shrinks height the most — the exact orientation the bug was reported in.
      await setViewport(tester, const Size(480, 320));
      await pumpOnboarding(tester);

      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Your home location'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Quick Log at a small/landscape viewport', () {
    late MegrimDatabase db;
    late MegrimRepository repo;

    setUp(() {
      db = MegrimDatabase.forTesting(NativeDatabase.memory());
      repo = MegrimRepository(db: db);
    });
    tearDown(() => db.close());

    testWidgets('idle view does not overflow at Nexus-S portrait size', (tester) async {
      await setViewport(tester, const Size(320, 480));
      await tester.pumpWidget(MaterialApp(home: QuickLogScreen(repo: repo)));
      await tester.pumpAndSettle();

      expect(find.text('LOG MIGRAINE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'active (in-progress) view does not overflow at Nexus-S portrait size',
        (tester) async {
      await repo.startEvent(severity: 5); // left ongoing (no endEvent)
      await setViewport(tester, const Size(320, 480));
      await tester.pumpWidget(MaterialApp(home: QuickLogScreen(repo: repo)));
      await tester.pumpAndSettle();

      expect(find.text('MIGRAINE ENDED'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'active (in-progress) view does not overflow in a small landscape size — '
        'MIGRAINE ENDED stays reachable', (tester) async {
      await repo.startEvent(severity: 5);
      // The exact scenario reported: rotating 90° while a migraine is in progress made the End
      // button unreachable.
      await setViewport(tester, const Size(480, 320));
      await tester.pumpWidget(MaterialApp(home: QuickLogScreen(repo: repo)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final endButton = find.widgetWithText(FilledButton, 'MIGRAINE ENDED');
      expect(endButton, findsOneWidget);
      // Not just present in the tree — actually tappable without needing to scroll it into view
      // first would be ideal, but at minimum confirm it's reachable via scrolling and tap works.
      await tester.ensureVisible(endButton);
      await tester.tap(endButton);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('LOG MIGRAINE'), findsOneWidget); // back to idle after ending
    });
  });
}
