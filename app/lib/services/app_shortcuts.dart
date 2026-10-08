import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The app-icon "Log migraine" shortcut (backlog #23, step 1).
///
/// A tap is only *recorded* here. [HomeShell] acts on it — starting a migraine, unless one is
/// already in progress — once the app is in the foreground and, if app lock is on, unlocked; a
/// tap during onboarding is dropped. So the shortcut can never log anything behind the lock.
const String kLogMigraineShortcut = 'log_migraine';

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

  bool _pending = false;

  /// A "Log migraine" tap is waiting to be acted on.
  bool get pending => _pending;

  Future<void> init() async {
    source.listen(_onAction);
    final initial = await source.initialAction();
    if (initial != null) _onAction(initial);
  }

  void _onAction(String action) {
    if (action != kLogMigraineShortcut) return;
    _pending = true;
    notifyListeners();
  }

  /// Claim the waiting tap: true once per tap.
  bool take() {
    if (!_pending) return false;
    _pending = false;
    return true;
  }
}

/// Makes [AppShortcuts] reachable from [HomeShell] and the onboarding gate.
class AppShortcutsScope extends InheritedNotifier<AppShortcuts> {
  const AppShortcutsScope({super.key, required AppShortcuts shortcuts, required super.child})
    : super(notifier: shortcuts);

  static AppShortcuts? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppShortcutsScope>()?.notifier;
}
