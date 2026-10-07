import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/models/app_lock_timeout.dart';
import 'package:megrim/repositories/megrim_repository.dart';
import 'package:megrim/screens/settings_screen.dart';
import 'package:megrim/services/app_lock.dart';
import 'package:megrim/widgets/app_lock_gate.dart';

/// Scripted stand-in for the phone's unlock prompt.
class FakeAuthenticator implements DeviceAuthenticator {
  bool available = true;
  final List<AuthOutcome> outcomes = [];
  final List<String> reasons = [];

  /// Runs while the prompt is "open", e.g. to deliver the lifecycle events a real prompt causes.
  void Function()? duringPrompt;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<AuthOutcome> authenticate(String reason) async {
    reasons.add(reason);
    duringPrompt?.call();
    return outcomes.isEmpty ? AuthOutcome.success : outcomes.removeAt(0);
  }
}

class FakeWindow implements WindowSecurity {
  final List<bool> calls = [];
  @override
  Future<void> setSecure(bool secure) async => calls.add(secure);
}

/// Backlog #24: app lock with the phone's own unlock, and hide from recent apps.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MegrimDatabase db;
  late MegrimRepository repo;
  late FakeAuthenticator auth;
  late FakeWindow window;
  late DateTime now;

  setUp(() {
    db = MegrimDatabase.forTesting(NativeDatabase.memory());
    repo = MegrimRepository(db: db);
    auth = FakeAuthenticator();
    window = FakeWindow();
    now = DateTime(2026, 10, 7, 12);
  });
  tearDown(() => db.close());

  Future<AppLockController> controller() async {
    final c = AppLockController(repo: repo, authenticator: auth, window: window, now: () => now);
    await c.init();
    addTearDown(c.dispose);
    return c;
  }

  void background(AppLockController c, Duration away) {
    c.didChangeAppLifecycleState(AppLifecycleState.inactive);
    c.didChangeAppLifecycleState(AppLifecycleState.hidden);
    c.didChangeAppLifecycleState(AppLifecycleState.paused);
    now = now.add(away);
    c.didChangeAppLifecycleState(AppLifecycleState.hidden);
    c.didChangeAppLifecycleState(AppLifecycleState.inactive);
    c.didChangeAppLifecycleState(AppLifecycleState.resumed);
  }

  group('settings', () {
    test('defaults: lock off, 1 minute, not hidden — an upgrade changes nothing', () async {
      final c = await controller();
      expect(c.enabled, isFalse);
      expect(c.locked, isFalse);
      expect(c.timeout, kAppLockDefaultTimeout);
      expect(c.hideInSwitcher, isFalse);
      expect(window.calls, isEmpty, reason: 'FLAG_SECURE is only touched when the user asks');
      expect(auth.reasons, isEmpty);
    });

    test('timeout labels', () {
      expect(appLockTimeoutLabel(Duration.zero), 'Immediately');
      expect(appLockTimeoutLabel(const Duration(minutes: 1)), 'After 1 minute');
      expect(appLockTimeoutLabel(const Duration(minutes: 15)), 'After 15 minutes');
    });
  });

  group('turning it on and off', () {
    test('turning on needs a successful unlock, and is saved', () async {
      final c = await controller();
      expect(await c.setEnabled(true), AuthOutcome.success);
      expect(c.enabled, isTrue);
      expect(c.locked, isFalse, reason: 'the user just proved it is them');
      expect(await repo.appLockEnabled, isTrue);
      expect(auth.reasons, hasLength(1));
    });

    test('a cancelled prompt leaves it off', () async {
      final c = await controller();
      auth.outcomes.add(AuthOutcome.cancelled);
      expect(await c.setEnabled(true), AuthOutcome.cancelled);
      expect(c.enabled, isFalse);
      expect(await repo.appLockEnabled, isFalse);
    });

    test('no screen lock on the phone: refused without showing a prompt', () async {
      final c = await controller();
      auth.available = false;
      expect(await c.setEnabled(true), AuthOutcome.noCredential);
      expect(c.enabled, isFalse);
      expect(auth.reasons, isEmpty);
    });

    test('turning off also needs the unlock, so someone else holding the phone cannot', () async {
      await repo.setAppLockEnabled(true);
      final c = await controller();
      await c.unlock();
      auth.outcomes.add(AuthOutcome.cancelled);
      expect(await c.setEnabled(false), AuthOutcome.cancelled);
      expect(c.enabled, isTrue);
      expect(await c.setEnabled(false), AuthOutcome.success);
      expect(c.enabled, isFalse);
      expect(await repo.appLockEnabled, isFalse);
    });
  });

  group('when it locks', () {
    test('a cold start with the lock on begins locked', () async {
      await repo.setAppLockEnabled(true);
      final c = await controller();
      expect(c.locked, isTrue);
    });

    test('locks after the timeout in the background, not before', () async {
      await repo.setAppLockEnabled(true);
      final c = await controller();
      await c.unlock();

      background(c, const Duration(seconds: 59));
      expect(c.locked, isFalse, reason: '59 s < 1 min default');

      background(c, const Duration(minutes: 1));
      expect(c.locked, isTrue, reason: 'exactly the timeout locks');
    });

    test('"Immediately" locks on any trip to the background', () async {
      await repo.setAppLockEnabled(true);
      await repo.setAppLockTimeout(Duration.zero);
      final c = await controller();
      await c.unlock();
      background(c, Duration.zero);
      expect(c.locked, isTrue);
    });

    test('inactive alone (notification shade, the unlock prompt) never locks', () async {
      await repo.setAppLockEnabled(true);
      await repo.setAppLockTimeout(Duration.zero);
      final c = await controller();
      await c.unlock();
      c.didChangeAppLifecycleState(AppLifecycleState.inactive);
      now = now.add(const Duration(hours: 1));
      c.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(c.locked, isFalse);
    });

    test('the share sheet / file picker trip does not count as leaving', () async {
      await repo.setAppLockEnabled(true);
      await repo.setAppLockTimeout(Duration.zero);
      final c = await controller();
      await c.unlock();
      await c.whileExternal(() async {
        c.didChangeAppLifecycleState(AppLifecycleState.paused);
        now = now.add(const Duration(minutes: 10));
      });
      c.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(c.locked, isFalse);
    });

    test('the device-PIN screen (a separate activity on Android) does not re-lock', () async {
      await repo.setAppLockEnabled(true);
      await repo.setAppLockTimeout(Duration.zero);
      final c = await controller();
      auth.duringPrompt = () => c.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(await c.unlock(), AuthOutcome.success);
      c.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(c.locked, isFalse, reason: 'otherwise "Immediately" would loop forever');
    });

    test('with the lock off, nothing ever locks', () async {
      final c = await controller();
      background(c, const Duration(hours: 5));
      expect(c.locked, isFalse);
    });
  });

  group('unlocking', () {
    test('cancel stays locked; success opens', () async {
      await repo.setAppLockEnabled(true);
      final c = await controller();
      auth.outcomes.add(AuthOutcome.cancelled);
      expect(await c.unlock(), AuthOutcome.cancelled);
      expect(c.locked, isTrue);
      expect(await c.unlock(), AuthOutcome.success);
      expect(c.locked, isFalse);
    });

    test('lockout stays locked and keeps the setting', () async {
      await repo.setAppLockEnabled(true);
      final c = await controller();
      auth.outcomes.add(AuthOutcome.lockedOut);
      await c.unlock();
      expect(c.locked, isTrue);
      expect(c.enabled, isTrue);
    });

    test('screen lock removed from the phone: lock turns itself off, user is let in', () async {
      await repo.setAppLockEnabled(true);
      final c = await controller();
      auth.outcomes.add(AuthOutcome.noCredential);
      await c.unlock();
      expect(c.locked, isFalse);
      expect(c.enabled, isFalse);
      expect(c.turnedOffNoCredential, isTrue);
      expect(await repo.appLockEnabled, isFalse);
      c.acknowledgeTurnedOff();
      expect(c.turnedOffNoCredential, isFalse);
    });

    test('an unexplained error with no screen lock is treated the same way', () async {
      await repo.setAppLockEnabled(true);
      final c = await controller();
      auth.outcomes.add(AuthOutcome.error);
      auth.available = false;
      await c.unlock();
      expect(c.enabled, isFalse);
      expect(c.turnedOffNoCredential, isTrue);
    });

    test('an error while a screen lock exists stays locked', () async {
      await repo.setAppLockEnabled(true);
      final c = await controller();
      auth.outcomes.add(AuthOutcome.error);
      await c.unlock();
      expect(c.locked, isTrue);
      expect(c.enabled, isTrue);
    });
  });

  group('hide in recent apps', () {
    test('toggling sets FLAG_SECURE and is saved', () async {
      final c = await controller();
      await c.setHideInSwitcher(true);
      expect(window.calls, [true]);
      expect(await repo.hideInSwitcher, isTrue);
      await c.setHideInSwitcher(false);
      expect(window.calls, [true, false]);
    });

    test('applied again at start-up', () async {
      await repo.setHideInSwitcher(true);
      final c = await controller();
      expect(c.hideInSwitcher, isTrue);
      expect(window.calls, [true]);
    });
  });

  group('lock gate', () {
    Widget app(AppLockController c, {bool coverWhenInactive = false}) => MaterialApp(
          builder: (context, child) => AppLockScope(
            controller: c,
            child: AppLockGate(
                controller: c, coverWhenInactive: coverWhenInactive, child: child!),
          ),
          home: const Scaffold(body: Text('diary contents')),
        );

    testWidgets('locked: the diary is hidden (also from screen readers) and the prompt opens',
        (tester) async {
      await repo.setAppLockEnabled(true);
      late AppLockController c;
      await tester.runAsync(() async => c = await controller());
      auth.outcomes.add(AuthOutcome.cancelled);
      await tester.pumpWidget(app(c));
      await tester.pumpAndSettle();

      expect(find.text('Megrim is locked'), findsOneWidget);
      expect(find.text('diary contents'), findsNothing);
      expect(find.bySemanticsLabel('diary contents'), findsNothing);
      expect(auth.reasons, hasLength(1), reason: 'the prompt opens by itself once');

      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();
      expect(find.text('Megrim is locked'), findsNothing);
      expect(find.text('diary contents'), findsOneWidget);
    });

    testWidgets('unlocked: no lock screen and no prompt', (tester) async {
      late AppLockController c;
      await tester.runAsync(() async => c = await controller());
      await tester.pumpWidget(app(c));
      await tester.pumpAndSettle();
      expect(find.text('diary contents'), findsOneWidget);
      expect(auth.reasons, isEmpty);
    });

    testWidgets('screen lock removed: explains, then Continue opens the app', (tester) async {
      await repo.setAppLockEnabled(true);
      late AppLockController c;
      await tester.runAsync(() async => c = await controller());
      auth.outcomes.add(AuthOutcome.noCredential);
      await tester.pumpWidget(app(c));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();

      expect(find.text('App lock turned off'), findsOneWidget);
      expect(find.text('diary contents'), findsNothing);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('diary contents'), findsOneWidget);
    });

    testWidgets('iOS cover: blank while inactive when "hide in recent apps" is on',
        (tester) async {
      await repo.setHideInSwitcher(true);
      late AppLockController c;
      await tester.runAsync(() async => c = await controller());
      await tester.pumpWidget(app(c, coverWhenInactive: true));
      await tester.pumpAndSettle();
      expect(find.text('diary contents'), findsOneWidget);

      c.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.text('diary contents'), findsNothing);

      c.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('diary contents'), findsOneWidget);
    });
  });

  group('Settings › Privacy', () {
    testWidgets('turning app lock on asks for the unlock and enables "Lock after"',
        (tester) async {
      late AppLockController c;
      await tester.runAsync(() async => c = await controller());
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => AppLockScope(controller: c, child: child!),
        home: SettingsScreen(repo: repo),
      ));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('App lock'), 200);
      final lockAfter = find.widgetWithText(ListTile, 'Lock after');
      expect(tester.widget<ListTile>(lockAfter).enabled, isFalse);

      await tester.runAsync(() async {
        await tester.tap(find.text('App lock'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(c.enabled, isTrue);
      expect(auth.reasons.single, contains('turn on app lock'));
      expect(tester.widget<ListTile>(lockAfter).enabled, isTrue);
      expect(find.text('After 1 minute in the background'), findsOneWidget);
    });

    testWidgets('no screen lock: explains instead of turning on', (tester) async {
      auth.available = false;
      late AppLockController c;
      await tester.runAsync(() async => c = await controller());
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => AppLockScope(controller: c, child: child!),
        home: SettingsScreen(repo: repo),
      ));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('App lock'), 200);

      await tester.runAsync(() async {
        await tester.tap(find.text('App lock'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(find.text('No screen lock on this phone'), findsOneWidget);
      expect(c.enabled, isFalse);
    });

    testWidgets('without a lock controller (screen tested alone) there is no Privacy section',
        (tester) async {
      await tester.pumpWidget(MaterialApp(home: SettingsScreen(repo: repo)));
      await tester.pumpAndSettle();
      expect(find.text('App lock'), findsNothing);
    });
  });
}
