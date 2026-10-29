import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/event_time.dart' show daysCovered;
import '../repositories/megrim_repository.dart';
import 'app_shortcuts.dart';

/// Local notifications (backlog #27 and #23 step 3 on Android): the opt-in daily reminder to log
/// the day, and the ongoing "Migraine in progress" notification. Both are off until the user turns
/// them on, and the permission is asked for only then. Nothing leaves the phone: the OS schedules
/// them. Neither writes the database: their buttons open the app, which acts once it is in the
/// foreground and unlocked, through the same queue as the app-icon shortcut ([AppShortcuts]).

/// How many days of reminders are scheduled ahead. Each is a one-off at that day's local time, so
/// a daylight-saving change can't shift it; they are rebuilt every time the app opens or data
/// changes, so they only run out if the app goes unopened for this long.
const int kReminderDaysAhead = 14;

/// Notification ids: the reminders take [kReminderBaseId] + 0..13.
const int kOngoingId = 1;
const int kReminderBaseId = 100;

/// The first reminder: today at [at] if that is still ahead and today has nothing logged,
/// otherwise tomorrow. Built with the date constructor, so a DST change can't move the time.
DateTime firstReminder(DateTime now, TimeOfDay at, {required bool todayLogged}) {
  final today = DateTime(now.year, now.month, now.day, at.hour, at.minute);
  if (!todayLogged && today.isAfter(now)) return today;
  return DateTime(now.year, now.month, now.day + 1, at.hour, at.minute);
}

/// [first] and the days after it, [kReminderDaysAhead] in all, each at the same wall-clock time.
List<DateTime> reminderTimes(DateTime first) => [
  for (var i = 0; i < kReminderDaysAhead; i++)
    DateTime(first.year, first.month, first.day + i, first.hour, first.minute),
];

/// `HH:mm`, the stored form of the reminder time.
String encodeTimeOfDay(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

TimeOfDay? decodeTimeOfDay(String? s) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(s ?? '');
  if (m == null) return null;
  final h = int.parse(m.group(1)!), min = int.parse(m.group(2)!);
  return h < 24 && min < 60 ? TimeOfDay(hour: h, minute: min) : null;
}

/// Seam over the plugin, so the scheduling rules can be tested without a device.
abstract class NotificationBackend {
  /// Whether the phone can show the ongoing notification (Android only: iOS gets a Live
  /// Activity in a later release).
  bool get supportsOngoing;

  /// [onAction] gets an [AppShortcuts] action for each notification or button the user taps,
  /// including the one that launched the app.
  Future<void> init(void Function(String action) onAction);

  /// Ask for permission to post notifications. True when granted.
  Future<bool> requestPermission();

  /// Replace any scheduled reminders with these (local wall-clock times).
  Future<void> scheduleReminders(List<DateTime> at);
  Future<void> cancelReminders();

  /// Post (or re-post) the ongoing notification with a clock counting up from [startedAt].
  Future<void> showOngoing(DateTime startedAt);
  Future<void> cancelOngoing();
}

class PluginNotificationBackend implements NotificationBackend {
  final _plugin = FlutterLocalNotificationsPlugin();

  static const _reminderCategory = 'reminder';

  @override
  bool get supportsOngoing => defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> init(void Function(String action) onAction) async {
    void respond(NotificationResponse r) {
      final action = _actionFor(r.actionId, r.payload);
      if (action != null) onAction(action);
    }

    await _plugin.initialize(
      settings: InitializationSettings(
        // A white-on-transparent glyph, as Android requires; kept from resource shrinking by
        // res/raw/keep.xml, since it is only referenced by name from here.
        android: const AndroidInitializationSettings('ic_stat_megrim'),
        iOS: DarwinInitializationSettings(
          // Asked for only when the user turns a notification on.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: [
            DarwinNotificationCategory(
              _reminderCategory,
              actions: [
                DarwinNotificationAction.plain(
                  kCheckinTodayAction,
                  'No migraine today',
                  options: {DarwinNotificationActionOption.foreground},
                ),
                DarwinNotificationAction.plain(
                  kOpenLogAction,
                  'Log',
                  options: {DarwinNotificationActionOption.foreground},
                ),
              ],
            ),
          ],
        ),
      ),
      onDidReceiveNotificationResponse: respond,
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final r = launch?.notificationResponse;
    if ((launch?.didNotificationLaunchApp ?? false) && r != null) respond(r);
  }

  /// A button gives its own action; a tap on the notification itself gives its payload's.
  static String? _actionFor(String? actionId, String? payload) {
    final a = (actionId == null || actionId.isEmpty) ? payload : actionId;
    return kNotificationActions.contains(a) ? a : null;
  }

  @override
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return await android.requestNotificationsPermission() ?? false;
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, badge: false, sound: true) ?? false;
    }
    return false;
  }

  @override
  Future<void> scheduleReminders(List<DateTime> at) async {
    await cancelReminders();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_reminder',
        'Daily reminder',
        channelDescription: 'The once-a-day reminder to log the day',
        // Nothing about health on a locked screen: Android shows "Contents hidden".
        visibility: NotificationVisibility.private,
        actions: [
          AndroidNotificationAction(
            kCheckinTodayAction,
            'No migraine today',
            showsUserInterface: true,
          ),
          AndroidNotificationAction(kOpenLogAction, 'Log', showsUserInterface: true),
        ],
      ),
      iOS: DarwinNotificationDetails(categoryIdentifier: _reminderCategory),
    );
    for (var i = 0; i < at.length; i++) {
      await _plugin.zonedSchedule(
        id: kReminderBaseId + i,
        // The instant, in UTC: each was built from local wall-clock time, so it is already right.
        scheduledDate: tz.TZDateTime.from(at[i].toUtc(), tz.UTC),
        notificationDetails: details,
        // Inexact: a few minutes late is fine, and it needs no exact-alarm permission.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: 'Megrim',
        body: 'How was today?',
        payload: kOpenLogAction,
      );
    }
  }

  @override
  Future<void> cancelReminders() async {
    for (var i = 0; i < kReminderDaysAhead; i++) {
      await _plugin.cancel(id: kReminderBaseId + i);
    }
  }

  @override
  Future<void> showOngoing(DateTime startedAt) => _plugin.show(
    id: kOngoingId,
    title: 'Migraine in progress',
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        'migraine_in_progress',
        'Migraine in progress',
        channelDescription: 'Shown while a migraine is running, with a clock and End',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        onlyAlertOnce: true,
        // The phone counts the clock up itself: no background work.
        usesChronometer: true,
        showWhen: true,
        when: startedAt.millisecondsSinceEpoch,
        visibility: NotificationVisibility.private,
        actions: const [
          AndroidNotificationAction(
            kEndMigraineAction,
            'End',
            showsUserInterface: true,
            cancelNotification: false,
          ),
        ],
      ),
    ),
    payload: kOpenLogAction,
  );

  @override
  Future<void> cancelOngoing() => _plugin.cancel(id: kOngoingId);
}

/// Keeps the notifications in step with the settings and the data. It watches the events and
/// check-ins tables, so whatever changes them (Quick Log, History, Event Detail, an import), the
/// ongoing notification follows the migraine in progress and the reminder skips a day that is
/// already logged.
class NotificationsController extends ChangeNotifier with WidgetsBindingObserver {
  final MegrimRepository repo;
  final NotificationBackend backend;
  final AppShortcuts shortcuts;

  /// Fixes "now" in tests.
  final DateTime Function() clock;

  NotificationsController({
    required this.repo,
    required this.shortcuts,
    NotificationBackend? backend,
    DateTime Function()? clock,
  }) : backend = backend ?? PluginNotificationBackend(),
       clock = clock ?? DateTime.now;

  TimeOfDay? _reminder;
  bool _ongoing = false;
  bool _loaded = false;

  /// Null when the daily reminder is off.
  TimeOfDay? get reminder => _reminder;
  bool get ongoingEnabled => _ongoing;
  bool get supportsOngoing => backend.supportsOngoing;
  bool get loaded => _loaded;

  final _subs = <StreamSubscription<Object?>>[];

  /// What was last handed to the backend, so an unchanged state isn't rescheduled on every write.
  DateTime? _scheduledFirst;
  DateTime? _ongoingShown;
  Future<void> _queue = Future.value();

  Future<void> init() async {
    try {
      await backend.init(shortcuts.dispatch);
    } catch (_) {
      // No plugin (tests without a backend, desktop): the rest still works without notifications.
    }
    _reminder = await repo.dailyReminder;
    _ongoing = await repo.ongoingNotification;
    _loaded = true;
    notifyListeners();
    WidgetsBinding.instance.addObserver(this);
    _subs
      ..add(repo.watchEvents().listen((_) => sync()))
      ..add(repo.watchCheckins().listen((_) => sync()));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A new day may have begun, and Android 14+ lets an ongoing notification be swiped away:
    // put it back.
    if (state == AppLifecycleState.resumed) sync(force: true);
  }

  /// Bring the scheduled reminders and the ongoing notification in line with the data. Runs one
  /// at a time, in order.
  Future<void> sync({bool force = false}) => _queue = _queue.then((_) => _sync(force));

  Future<void> _sync(bool force) async {
    try {
      final now = clock();
      final today = DateTime(now.year, now.month, now.day);
      final events = await repo.db.select(repo.db.migraineEvents).get();

      // The newest migraine still running, if any.
      final running = events.where((e) => e.endedAt == null).toList()
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
      final start = (_ongoing && backend.supportsOngoing && running.isNotEmpty)
          ? running.first.startedAt
          : null;
      if (start == null) {
        if (_ongoingShown != null || force) await backend.cancelOngoing();
        _ongoingShown = null;
      } else if (force || start != _ongoingShown) {
        await backend.showOngoing(start);
        _ongoingShown = start;
      }

      final r = _reminder;
      if (r == null) {
        if (_scheduledFirst != null || force) await backend.cancelReminders();
        _scheduledFirst = null;
        return;
      }
      final todayLogged =
          await repo.checkinOn(today) != null ||
          events.any(
            (e) => daysCovered(
              e.startedAt,
              e.startedAtOffsetMin,
              e.endedAt,
              e.endedAtOffsetMin,
            ).contains(today),
          );
      final first = firstReminder(now, r, todayLogged: todayLogged);
      if (force || first != _scheduledFirst) {
        await backend.scheduleReminders(reminderTimes(first));
        _scheduledFirst = first;
      }
    } catch (e) {
      debugPrint('notifications: sync failed: $e');
    }
  }

  /// Turn the daily reminder on at [at], or off with null. Turning it on asks for permission
  /// first; false (and nothing changed) if that is refused.
  Future<bool> setReminder(TimeOfDay? at) async {
    if (at != null && !await backend.requestPermission()) return false;
    _reminder = at;
    await repo.setDailyReminder(at);
    notifyListeners();
    await sync(force: true);
    return true;
  }

  /// As [setReminder], for the ongoing notification.
  Future<bool> setOngoing(bool on) async {
    if (on && !await backend.requestPermission()) return false;
    _ongoing = on;
    await repo.setOngoingNotification(on);
    await repo.markOngoingOffered();
    notifyListeners();
    await sync(force: true);
    return true;
  }

  /// Whether to offer the ongoing notification now (once, when the first migraine is started).
  Future<bool> shouldOfferOngoing() async =>
      backend.supportsOngoing && !_ongoing && !await repo.ongoingOffered;

  Future<void> declineOngoing() => repo.markOngoingOffered();
}

/// Makes [NotificationsController] reachable from Settings and Quick Log.
class NotificationsScope extends InheritedNotifier<NotificationsController> {
  const NotificationsScope({
    super.key,
    required NotificationsController controller,
    required super.child,
  }) : super(notifier: controller);

  static NotificationsController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NotificationsScope>()?.notifier;
}
