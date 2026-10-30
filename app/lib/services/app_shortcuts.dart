import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The app-icon "Log migraine" shortcut (backlog #23, step 1).
///
/// A tap is only *recorded* here. [HomeShell] acts on it — starting a migraine, unless one is
/// already in progress — once the app is in the foreground and, if app lock is on, unlocked; a
/// tap during onboarding is dropped. So the shortcut can never log anything behind the lock.
const String kLogMigraineShortcut = 'log_migraine';

/// Notification buttons (backlog #27, #23 step 3), queued the same way: "No migraine today" on the
/// reminder checks today in, "Log" (and a tap on either notification) opens the Log tab, and End
/// on the ongoing notification ends the migraine in progress.
const String kCheckinTodayAction = 'checkin_today';
const String kOpenLogAction = 'open_log';
const String kEndMigraineAction = 'end_migraine';
const Set<String> kNotificationActions = {
  kCheckinTodayAction,
  kOpenLogAction,
  kEndMigraineAction,
};

/// Seam over the platform channel (MainActivity on Android, AppDelegate on iOS).
abstract class ShortcutSource {
  /// The shortcut that launched the app, if any. Returns it once, then null.
  Future<String?> initialAction();

  /// Called with each shortcut used while the app is already running.
  void listen(void Function(String action) onAction);
}

class PlatformShortcutSource implements ShortcutSource {
  static const _channel = MethodChannel('org.maegley.megrim/shortcut');

  @override
  Future<String?> initialAction() async {
    try {
      return await _channel.invokeMethod<String>('initialAction');
    } on MissingPluginException {
      return null; // no native side (tests, desktop)
    } on PlatformException {
      return null;
    }
  }

  @override
  void listen(void Function(String action) onAction) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'action' && call.arguments is String) onAction(call.arguments as String);
    });
  }
}

class AppShortcuts extends ChangeNotifier {
  final ShortcutSource source;
  AppShortcuts({ShortcutSource? source}) : source = source ?? PlatformShortcutSource();

  String? _pending;

  /// A shortcut or notification tap is waiting to be acted on.
  bool get pending => _pending != null;

  Future<void> init() async {
    source.listen(dispatch);
    final initial = await source.initialAction();
    if (initial != null) dispatch(initial);
  }

  /// Queue [action]. A later tap replaces an earlier one still waiting: it is what the user did
  /// last.
  void dispatch(String action) {
    if (action != kLogMigraineShortcut && !kNotificationActions.contains(action)) return;
    _pending = action;
    notifyListeners();
  }

  /// Claim the waiting action, once.
  String? takeAction() {
    final a = _pending;
    _pending = null;
    return a;
  }

  /// Claim the waiting tap: true once per tap.
  bool take() => takeAction() != null;
}

/// Makes [AppShortcuts] reachable from [HomeShell] and the onboarding gate.
class AppShortcutsScope extends InheritedNotifier<AppShortcuts> {
  const AppShortcutsScope({super.key, required AppShortcuts shortcuts, required super.child})
    : super(notifier: shortcuts);

  static AppShortcuts? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppShortcutsScope>()?.notifier;
}
