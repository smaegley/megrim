import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/repositories/megrim_repository.dart';
import 'package:megrim/screens/quick_log_screen.dart';
import 'package:megrim/screens/settings_screen.dart';
import 'package:megrim/services/app_shortcuts.dart';
import 'package:megrim/services/notifications.dart';

/// Backlog #27 (the daily reminder) and #23 step 3 on Android (the ongoing notification): when
/// they are scheduled, posted and cleared, and what their buttons do. The plugin is replaced by a
/// recording fake; the real one is checked on a device (the test script).

class FakeBackend implements NotificationBackend {
  bool grant = true;
  @override
  bool supportsOngoing = true;
  void Function(String)? onAction;
  List<DateTime>? reminders;
  DateTime? ongoing;
  int permissionAsks = 0;

  @override
  Future<void> init(void Function(String action) onAction) async => this.onAction = onAction;
  @override
  Future<bool> requestPermission() async {
    permissionAsks++;
    return grant;
  }

  @override
  Future<void> scheduleReminders(List<DateTime> at) async => reminders = at;
  @override
  Future<void> cancelReminders() async => reminders = null;
  @override
  Future<void> showOngoing(DateTime startedAt) async => ongoing = startedAt;
  @override
  Future<void> cancelOngoing() async => ongoing = null;
}

class NoShortcuts implements ShortcutSource {
  @override
  Future<String?> initialAction() async => null;
  @override
  void listen(void Function(String action) onAction) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const eight = TimeOfDay(hour: 20, minute: 0);

  group('reminder times', () {
    test('today if still ahead and nothing logged, otherwise tomorrow', () {
      final morning = DateTime(2026, 10, 29, 9);
      expect(firstReminder(morning, eight, todayLogged: false), DateTime(2026, 10, 29, 20));
      expect(firstReminder(morning, eight, todayLogged: true), DateTime(2026, 10, 30, 20));
      final late = DateTime(2026, 10, 29, 20, 30);
      expect(firstReminder(late, eight, todayLogged: false), DateTime(2026, 10, 30, 20));
      final monthEnd = DateTime(2026, 10, 31, 21);
      expect(firstReminder(monthEnd, eight, todayLogged: false), DateTime(2026, 11, 1, 20));
    });

    test('14 days at the same wall-clock time, across a DST change', () {
      // US clocks go back on 1 Nov 2026; the reminder stays at 20:00 local either side.
      final times = reminderTimes(DateTime(2026, 10, 25, 20));
      expect(times, hasLength(kReminderDaysAhead));
      expect(times.map((t) => (t.hour, t.minute)).toSet(), {(20, 0)});
      expect(times.map((t) => t.day), [25, 26, 27, 28, 29, 30, 31, 1, 2, 3, 4, 5, 6, 7]);
    });

    test('time of day round-trips through its stored form', () {
      expect(encodeTimeOfDay(const TimeOfDay(hour: 8, minute: 5)), '08:05');
      expect(decodeTimeOfDay('08:05'), const TimeOfDay(hour: 8, minute: 5));
      expect(decodeTimeOfDay(''), isNull);
      expect(decodeTimeOfDay('25:00'), isNull);
    });
  });

  group('controller', () {
    late MegrimDatabase db;
    late MegrimRepository repo;
    late FakeBackend backend;
    late AppShortcuts shortcuts;
    late NotificationsController n;
    var now = DateTime(2026, 10, 29, 9);
    DateTime today() => DateTime(now.year, now.month, now.day);

    setUp(() async {
      now = DateTime(2026, 10, 29, 9);
      db = MegrimDatabase.forTesting(NativeDatabase.memory());
      repo = MegrimRepository(db: db);
      backend = FakeBackend();
      shortcuts = AppShortcuts(source: NoShortcuts());
      n = NotificationsController(
        repo: repo,
        shortcuts: shortcuts,
        backend: backend,
        clock: () => now,
      );
      await n.init();
    });
    tearDown(() async {
      n.dispose();
      await db.close();
    });

    /// Let the table watchers fire, then wait for the sync they queued.
    Future<void> settle() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await n.sync();
    }

    test('off by default: nothing scheduled or posted, no permission asked', () async {
      await settle();
      expect(backend.reminders, isNull);
      expect(backend.ongoing, isNull);
      expect(backend.permissionAsks, 0);
    });

    test('turning the reminder on asks, schedules from today, and is remembered', () async {
      expect(await n.setReminder(eight), isTrue);
      expect(backend.permissionAsks, 1);
      expect(backend.reminders!.first, DateTime(2026, 10, 29, 20));
      expect(backend.reminders, hasLength(kReminderDaysAhead));
      expect(await repo.dailyReminder, eight);

      expect(await n.setReminder(null), isTrue);
      expect(backend.reminders, isNull);
      expect(await repo.dailyReminder, isNull);
    });

    test('refused permission leaves it off', () async {
      backend.grant = false;
      expect(await n.setReminder(eight), isFalse);
      expect(n.reminder, isNull);
      expect(await repo.dailyReminder, isNull);
      expect(backend.reminders, isNull);
    });

    test('a check-in or an entry today moves the first reminder to tomorrow', () async {
      await n.setReminder(eight);
      await repo.checkIn(today());
      await settle();
      expect(backend.reminders!.first, DateTime(2026, 10, 30, 20));

      await repo.removeCheckin(today());
      await settle();
      expect(backend.reminders!.first, DateTime(2026, 10, 29, 20));

      await repo.insertEvent(
        MigraineEventsCompanion(
          startedAt: Value(DateTime(2026, 10, 29, 7).toUtc()),
          endedAt: Value(DateTime(2026, 10, 29, 8).toUtc()),
        ),
      );
      await settle();
      expect(backend.reminders!.first, DateTime(2026, 10, 30, 20));
    });

    test('the ongoing notification follows the migraine in progress', () async {
      expect(await n.setOngoing(true), isTrue);
      final id = await repo.startEvent(severity: 5);
      await settle();
      final started = (await repo.getEvent(id))!.startedAt;
      expect(backend.ongoing, started);

      await repo.endEvent(id);
      await settle();
      expect(backend.ongoing, isNull);

      // Discarding one removes it too.
      final id2 = await repo.startEvent(severity: 5);
      await settle();
      expect(backend.ongoing, isNotNull);
      await repo.deleteEvent(id2);
      await settle();
      expect(backend.ongoing, isNull);
    });

    test('off, or on iOS, there is no ongoing notification', () async {
      await repo.startEvent(severity: 5);
      await settle();
      expect(backend.ongoing, isNull);

      backend.supportsOngoing = false;
      await n.setOngoing(true);
      await settle();
      expect(backend.ongoing, isNull);
      expect(await n.shouldOfferOngoing(), isFalse);
    });

    test('offered once', () async {
      expect(await n.shouldOfferOngoing(), isTrue);
      await n.declineOngoing();
      expect(await n.shouldOfferOngoing(), isFalse);
    });

    test('notification buttons are queued like the shortcut', () async {
      backend.onAction!(kCheckinTodayAction);
      expect(shortcuts.takeAction(), kCheckinTodayAction);
      backend.onAction!(kEndMigraineAction);
      expect(shortcuts.takeAction(), kEndMigraineAction);
      shortcuts.dispatch('something else');
      expect(shortcuts.pending, isFalse);
    });
  });

  group('Quick Log acts on the buttons', () {
    late MegrimDatabase db;
    late MegrimRepository repo;
    setUp(() {
      db = MegrimDatabase.forTesting(NativeDatabase.memory());
      repo = MegrimRepository(db: db);
    });
    tearDown(() => db.close());

    DateTime todayDate() {
      final t = DateTime.now();
      return DateTime(t.year, t.month, t.day);
    }

    testWidgets('"No migraine today" checks today in', (t) async {
      await t.pumpWidget(MaterialApp(home: QuickLogScreen(repo: repo)));
      await t.pumpAndSettle();
      await t.pumpWidget(MaterialApp(home: QuickLogScreen(repo: repo, checkinToken: 1)));
      await t.pumpAndSettle();
      expect(await repo.checkinOn(todayDate()), isNotNull);
      expect(find.text('No migraine today'), findsOneWidget);
    });

    testWidgets('…but not when today already has an entry', (t) async {
      final id = await repo.startEvent(severity: 4);
      await repo.endEvent(id);
      await t.pumpWidget(MaterialApp(home: QuickLogScreen(repo: repo)));
      await t.pumpAndSettle();
      await t.pumpWidget(MaterialApp(home: QuickLogScreen(repo: repo, checkinToken: 1)));
      await t.pumpAndSettle();
      expect(await repo.checkinOn(todayDate()), isNull);
      expect(find.textContaining('already has a migraine entry'), findsOneWidget);
    });

    testWidgets('End ends the migraine in progress', (t) async {
      final id = await repo.startEvent(severity: 4);
      await t.pumpWidget(MaterialApp(home: QuickLogScreen(repo: repo)));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      await t.pumpWidget(MaterialApp(home: QuickLogScreen(repo: repo, endToken: 1)));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect((await repo.getEvent(id))!.endedAt, isNotNull);
      expect(find.text('LOG MIGRAINE'), findsOneWidget);
    });
  });

  group('Settings', () {
    late MegrimDatabase db;
    late MegrimRepository repo;
    late FakeBackend backend;
    late NotificationsController n;
    setUp(() {
      db = MegrimDatabase.forTesting(NativeDatabase.memory());
      repo = MegrimRepository(db: db);
      backend = FakeBackend();
    });
    tearDown(() => db.close());

    /// Unmount and let Drift's timers on the fake clock run, then close.
    Future<void> close(WidgetTester t) async {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(seconds: 1));
      n.dispose();
    }

    /// [body], then [close] even if it fails, so a failure can't
    /// leave the database open and hang the next test.
    Future<void> run(WidgetTester t, Future<void> Function() body) async {
      try {
        await body();
      } finally {
        await close(t);
      }
    }

    // Without init(): these test the rows, and the table watchers it starts belong to the
    // controller tests above (they don't run on a widget test's fake clock).
    Future<void> pump(WidgetTester t) async {
      // Built here, inside the test's fake-async zone, so its work runs on the test's clock.
      n = NotificationsController(
        repo: repo,
        shortcuts: AppShortcuts(source: NoShortcuts()),
        backend: backend,
      );
      await t.pumpWidget(
        MaterialApp(
          home: NotificationsScope(
            controller: n,
            child: SettingsScreen(repo: repo),
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    testWidgets('the reminder row turns on at a chosen time, and off', (t) async {
      await run(t, () async {
        await pump(t);
        expect(find.text('Daily reminder'), findsOneWidget);
        expect(find.text('Off'), findsOneWidget);
        await t.tap(find.text('Daily reminder'));
        await t.pumpAndSettle();
        await t.tap(find.text('Choose a time…'));
        await t.pumpAndSettle();
        await t.tap(find.text('OK'));
        await t.pumpAndSettle();
        // The reschedule reads the database, which completes on the fake clock.
        await t.pump(const Duration(seconds: 1));
        expect(n.reminder, const TimeOfDay(hour: 20, minute: 0));
        final texts = t.widgetList<Text>(find.byType(Text)).map((w) => w.data).toList();
        expect(
          texts.where((x) => x != null && x.startsWith('Every day at 8:00')),
          hasLength(1),
          reason: '$texts',
        );
        expect(backend.reminders, isNotNull);

        await t.tap(find.text('Daily reminder'));
        await t.pumpAndSettle();
        await t.tap(find.text('Off'));
        await t.pumpAndSettle();
        await t.pump(const Duration(seconds: 1));
        expect(n.reminder, isNull);
        expect(backend.reminders, isNull);
      });
    });

    testWidgets('refused permission says so and stays off', (t) async {
      await run(t, () async {
        backend.grant = false;
        await pump(t);
        await t.tap(find.text('Notification during a migraine'));
        await t.pumpAndSettle();
        expect(n.ongoingEnabled, isFalse);
        expect(find.textContaining('Notifications are off for Megrim'), findsOneWidget);
      });
    });

    testWidgets('no ongoing row where it is not supported', (t) async {
      await run(t, () async {
        backend.supportsOngoing = false;
        await pump(t);
        expect(find.text('Daily reminder'), findsOneWidget);
        expect(find.text('Notification during a migraine'), findsNothing);
      });
    });
  });
}
