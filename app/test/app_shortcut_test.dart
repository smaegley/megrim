import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/app.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/models/home_location.dart';
import 'package:megrim/repositories/megrim_repository.dart';
import 'package:megrim/services/app_lock.dart';
import 'package:megrim/services/app_shortcuts.dart';

/// Stand-in for the native shortcut channel.
class FakeShortcutSource implements ShortcutSource {
  String? initial;
  void Function(String)? _onAction;
  FakeShortcutSource({this.initial});

  @override
  Future<String?> initialAction() async {
    final i = initial;
    initial = null;
    return i;
  }

  @override
  void listen(void Function(String action) onAction) => _onAction = onAction;

  /// A shortcut tapped while the app is running.
  void tap() => _onAction?.call(kLogMigraineShortcut);
}

class FakeAuthenticator implements DeviceAuthenticator {
  final List<AuthOutcome> outcomes = [];
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<AuthOutcome> authenticate(String reason) async =>
      outcomes.isEmpty ? AuthOutcome.success : outcomes.removeAt(0);
}

class FakeWindow implements WindowSecurity {
  @override
  Future<void> setSecure(bool secure) async {}
}

/// Backlog #23 step 1, Steve's choices (2026-10-08): a tap starts the migraine; with one already
/// in progress it just shows it; with app lock on, it waits for the unlock; during onboarding it
/// is ignored.
void main() {
  group('AppShortcuts', () {
    test('a launching shortcut is pending once', () async {
      final s = AppShortcuts(source: FakeShortcutSource(initial: kLogMigraineShortcut));
      await s.init();
      expect(s.pending, isTrue);
      expect(s.take(), isTrue);
      expect(s.take(), isFalse);
    });

    test('a tap while running notifies; an unknown action is ignored', () async {
      final src = FakeShortcutSource();
      final s = AppShortcuts(source: src);
      await s.init();
      var notified = 0;
      s.addListener(() => notified++);
      src.tap();
      expect(s.pending, isTrue);
      expect(notified, 1);
      s.take();
      src._onAction!('something_else');
      expect(s.pending, isFalse);
    });
  });

  group('in the app', () {
    late MegrimDatabase db;
    late MegrimRepository repo;

    setUp(() {
      db = MegrimDatabase.forTesting(NativeDatabase.memory());
      repo = MegrimRepository(db: db);
      // connectivity_plus has no platform side in tests; report "offline" so the whole app can
      // settle (the other MegrimApp tests avoid settling instead).
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockStreamHandler(
          const EventChannel('dev.fluttercommunity.plus/connectivity_status'),
          MockStreamHandler.inline(onListen: (_, _) {}));
      messenger.setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/connectivity'), (_) async => ['none']);
    });

    Future<void> onboard() async {
      await repo.acceptDisclaimer();
      await repo.setHomeLocation(const HomeLocation(lat: 40, lon: -105, label: 'Home'));
    }

    Future<List<MigraineEvent>> events(WidgetTester tester) async =>
        (await tester.runAsync(() => db.select(db.migraineEvents).get()))!;

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    Future<void> close(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(() => db.close());
    }

    Future<AppLockController> lockOn(WidgetTester tester, FakeAuthenticator auth) async {
      await tester.runAsync(() => repo.setAppLockEnabled(true));
      return AppLockController(repo: repo, authenticator: auth, window: FakeWindow());
    }

    testWidgets('launched from the shortcut: a migraine starts', (tester) async {
      await tester.runAsync(onboard);
      final src = FakeShortcutSource(initial: kLogMigraineShortcut);
      await tester.pumpWidget(
        MegrimApp(
          repo: repo,
          shortcuts: AppShortcuts(source: src),
        ),
      );
      await settle(tester);

      final e = await events(tester);
      expect(e, hasLength(1));
      expect(e.single.endedAt, isNull);
      expect(find.text('Migraine in progress'), findsOneWidget);
      await close(tester);
    });

    testWidgets('a migraine already in progress: no second one', (tester) async {
      await tester.runAsync(() async {
        await onboard();
        await repo.startEvent(severity: 5);
      });
      final src = FakeShortcutSource(initial: kLogMigraineShortcut);
      await tester.pumpWidget(
        MegrimApp(
          repo: repo,
          shortcuts: AppShortcuts(source: src),
        ),
      );
      await settle(tester);

      expect(await events(tester), hasLength(1));
      expect(find.text('Migraine in progress'), findsOneWidget);
      await close(tester);
    });

    testWidgets('used while running on another tab: switches to Log and starts', (tester) async {
      await tester.runAsync(onboard);
      final src = FakeShortcutSource();
      await tester.pumpWidget(
        MegrimApp(
          repo: repo,
          shortcuts: AppShortcuts(source: src),
        ),
      );
      await settle(tester);
      await tester.tap(find.text('History'));
      await settle(tester);
      expect(await events(tester), isEmpty);

      src.tap();
      await settle(tester);
      expect(await events(tester), hasLength(1));
      expect(find.text('Migraine in progress'), findsOneWidget);
      await close(tester);
    });

    testWidgets('two quick taps start one migraine', (tester) async {
      await tester.runAsync(onboard);
      final src = FakeShortcutSource();
      await tester.pumpWidget(
        MegrimApp(
          repo: repo,
          shortcuts: AppShortcuts(source: src),
        ),
      );
      await settle(tester);
      src.tap();
      src.tap();
      await settle(tester);
      src.tap();
      await settle(tester);
      expect(await events(tester), hasLength(1));
      await close(tester);
    });

    testWidgets('app lock on: nothing is logged until the unlock', (tester) async {
      await tester.runAsync(onboard);
      final auth = FakeAuthenticator()..outcomes.add(AuthOutcome.cancelled);
      final lock = await lockOn(tester, auth);
      final src = FakeShortcutSource(initial: kLogMigraineShortcut);
      await tester.pumpWidget(
        MegrimApp(
          repo: repo,
          appLock: lock,
          shortcuts: AppShortcuts(source: src),
        ),
      );
      await settle(tester);

      expect(find.text('Megrim is locked'), findsOneWidget);
      expect(await events(tester), isEmpty, reason: 'the prompt was cancelled');

      await tester.tap(find.text('Unlock'));
      await settle(tester);
      expect(await events(tester), hasLength(1));
      expect(find.text('Migraine in progress'), findsOneWidget);
      await close(tester);
      lock.dispose();
    });

    testWidgets('returning via the shortcut re-locks first, then logs after unlock', (
      tester,
    ) async {
      // Android can deliver the shortcut just before the app reports it has resumed. The lock
      // ("Immediately") must engage on that resume before the shortcut is acted on.
      await tester.runAsync(() async {
        await onboard();
        await repo.setAppLockTimeout(Duration.zero);
      });
      final auth = FakeAuthenticator();
      final lock = await lockOn(tester, auth);
      final src = FakeShortcutSource();
      await tester.pumpWidget(
        MegrimApp(
          repo: repo,
          appLock: lock,
          shortcuts: AppShortcuts(source: src),
        ),
      );
      await settle(tester); // unlocks on start (auth succeeds)
      expect(find.text('Megrim is locked'), findsNothing);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      auth.outcomes.add(AuthOutcome.cancelled); // the prompt on return is cancelled
      src.tap(); // arrives while still in the background
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);

      expect(find.text('Megrim is locked'), findsOneWidget);
      expect(await events(tester), isEmpty, reason: 'nothing logged behind the lock');

      await tester.tap(find.text('Unlock'));
      await settle(tester);
      expect(await events(tester), hasLength(1));
      await close(tester);
      lock.dispose();
    });

    testWidgets('during onboarding the tap is ignored, and not replayed afterwards', (
      tester,
    ) async {
      final src = FakeShortcutSource(initial: kLogMigraineShortcut);
      final shortcuts = AppShortcuts(source: src);
      await tester.pumpWidget(MegrimApp(repo: repo, shortcuts: shortcuts));
      await settle(tester);

      expect(find.byType(NavigationBar), findsNothing, reason: 'onboarding is showing');
      expect(shortcuts.pending, isFalse, reason: 'the tap was dropped');
      expect(await events(tester), isEmpty);
      await close(tester);
    });

    testWidgets('no shortcut: nothing happens on a normal start', (tester) async {
      await tester.runAsync(onboard);
      await tester.pumpWidget(
        MegrimApp(
          repo: repo,
          shortcuts: AppShortcuts(source: FakeShortcutSource()),
        ),
      );
      await settle(tester);
      expect(await events(tester), isEmpty);
      expect(find.text('LOG MIGRAINE'), findsOneWidget);
      await close(tester);
    });
  });
}
