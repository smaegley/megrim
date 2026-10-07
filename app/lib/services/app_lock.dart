import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';

import '../models/app_lock_timeout.dart';
import '../repositories/megrim_repository.dart';

/// App lock + hide-from-switcher (backlog #24).
///
/// The lock uses the phone's own unlock — fingerprint, face, or the device PIN/pattern/password,
/// whichever the user has set up — through `local_auth` with biometrics-only OFF. There is no
/// Megrim PIN, so there is nothing to forget: the recovery path is the phone's own unlock.
///
/// It is a privacy screen, not encryption (encryption at rest was reviewed and not planned): it
/// stops someone holding the unlocked phone from reading the diary.

/// What an unlock attempt came to.
enum AuthOutcome {
  success,

  /// The user (or the system) dismissed the prompt. Stay locked; they can try again.
  cancelled,

  /// The phone has no screen lock any more, so the app lock cannot be enforced.
  noCredential,

  /// Too many failed attempts; the OS has locked authentication for a while.
  lockedOut,

  /// Anything else the platform reported.
  error,
}

/// Seam over `local_auth` so tests can drive the lock without a platform.
abstract class DeviceAuthenticator {
  /// True when the phone has a screen lock (or biometrics) that can be asked for.
  Future<bool> isAvailable();

  Future<AuthOutcome> authenticate(String reason);
}

class LocalAuthAuthenticator implements DeviceAuthenticator {
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } on Exception {
      return false;
    }
  }

  @override
  Future<AuthOutcome> authenticate(String reason) async {
    try {
      // biometricOnly: false — the system prompt falls back to the device PIN/pattern/password
      // (Android BIOMETRIC_STRONG | DEVICE_CREDENTIAL; iOS deviceOwnerAuthentication).
      final ok = await _auth.authenticate(localizedReason: reason, biometricOnly: false);
      return ok ? AuthOutcome.success : AuthOutcome.cancelled;
    } on LocalAuthException catch (e) {
      switch (e.code) {
        case LocalAuthExceptionCode.userCanceled:
        case LocalAuthExceptionCode.systemCanceled:
        case LocalAuthExceptionCode.timeout:
        case LocalAuthExceptionCode.userRequestedFallback:
        case LocalAuthExceptionCode.authInProgress:
          return AuthOutcome.cancelled;
        case LocalAuthExceptionCode.noCredentialsSet:
          return AuthOutcome.noCredential;
        case LocalAuthExceptionCode.temporaryLockout:
        case LocalAuthExceptionCode.biometricLockout:
          return AuthOutcome.lockedOut;
        default:
          return AuthOutcome.error;
      }
    } on Exception {
      return AuthOutcome.error;
    }
  }
}

/// Seam over the Android FLAG_SECURE channel in MainActivity.
abstract class WindowSecurity {
  Future<void> setSecure(bool secure);
}

class PlatformWindowSecurity implements WindowSecurity {
  static const _channel = MethodChannel('org.maegley.megrim/window');

  @override
  Future<void> setSecure(bool secure) async {
    // Android only: iOS has no FLAG_SECURE — it gets the blank overlay in [AppLockGate] instead.
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('setSecure', secure);
    } on PlatformException {
      // Best effort: a failure here must never stop the app from opening.
    } on MissingPluginException {
      // Same.
    }
  }
}

class AppLockController extends ChangeNotifier with WidgetsBindingObserver {
  final MegrimRepository repo;
  final DeviceAuthenticator authenticator;
  final WindowSecurity window;
  final DateTime Function() _now;

  AppLockController({
    required this.repo,
    DeviceAuthenticator? authenticator,
    WindowSecurity? window,
    DateTime Function()? now,
  }) : authenticator = authenticator ?? LocalAuthAuthenticator(),
       window = window ?? PlatformWindowSecurity(),
       _now = now ?? DateTime.now;

  static const String unlockReason = 'Unlock Megrim';

  bool _loaded = false;
  bool _enabled = false;
  Duration _timeout = kAppLockDefaultTimeout;
  bool _hideInSwitcher = false;
  bool _locked = false;
  bool _foreground = true;
  bool _turnedOffNoCredential = false;

  /// When the app last went to the background (null while in the foreground, and when the
  /// background trip was one Megrim started itself — see [whileExternal]).
  DateTime? _backgroundedAt;

  /// >0 while Megrim itself has sent the user to another screen (system share sheet, file picker,
  /// the unlock prompt). Those trips don't count as leaving the app.
  int _external = 0;

  bool get loaded => _loaded;
  bool get enabled => _enabled;
  Duration get timeout => _timeout;
  bool get hideInSwitcher => _hideInSwitcher;
  bool get locked => _locked;

  /// False while the app is inactive/backgrounded. Drives the iOS switcher overlay.
  bool get foreground => _foreground;

  /// Set when the lock was switched off because the phone no longer has a screen lock; the lock
  /// screen shows a one-time explanation until [acknowledgeTurnedOff].
  bool get turnedOffNoCredential => _turnedOffNoCredential;

  /// Read the settings and start watching the app lifecycle. A cold start with the lock on begins
  /// locked.
  Future<void> init() async {
    _enabled = await repo.appLockEnabled;
    _timeout = await repo.appLockTimeout;
    _hideInSwitcher = await repo.hideInSwitcher;
    _locked = _enabled;
    _loaded = true;
    if (_hideInSwitcher) await window.setSecure(true);
    WidgetsBinding.instance.addObserver(this);
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _foreground = true;
        final away = _backgroundedAt;
        _backgroundedAt = null;
        if (_enabled && !_locked && away != null && _now().difference(away) >= _timeout) {
          _locked = true;
        }
        notifyListeners();
      case AppLifecycleState.inactive:
        _foreground = false;
        notifyListeners();
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _foreground = false;
        if (_external == 0) _backgroundedAt ??= _now();
        notifyListeners();
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Run [action] — something that opens a system screen on Megrim's behalf — without that trip
  /// counting as leaving the app, so returning from the share sheet or file picker doesn't lock.
  Future<T> whileExternal<T>(Future<T> Function() action) async {
    _external++;
    try {
      return await action();
    } finally {
      _external--;
    }
  }

  /// Ask for the phone's unlock and open the app on success. If the phone no longer has a screen
  /// lock, the app lock can't be enforced: turn it off rather than shut the user out of their data.
  Future<AuthOutcome> unlock() async {
    if (!_locked) return AuthOutcome.success;
    final outcome = await whileExternal(() => authenticator.authenticate(unlockReason));
    if (outcome == AuthOutcome.success) {
      _locked = false;
    } else if (outcome == AuthOutcome.noCredential ||
        (outcome == AuthOutcome.error && !await authenticator.isAvailable())) {
      await repo.setAppLockEnabled(false);
      _enabled = false;
      _turnedOffNoCredential = true;
      _locked = false;
    }
    notifyListeners();
    return outcome;
  }

  void acknowledgeTurnedOff() {
    _turnedOffNoCredential = false;
    notifyListeners();
  }

  /// Turn the lock on or off. Both directions need a successful unlock first: turning it on proves
  /// the prompt works on this phone, and turning it off can't be done by someone else holding it.
  /// Returns the outcome; [AuthOutcome.noCredential] when the phone has no screen lock at all.
  Future<AuthOutcome> setEnabled(bool on) async {
    if (on == _enabled) return AuthOutcome.success;
    if (on && !await authenticator.isAvailable()) {
      return AuthOutcome.noCredential;
    }
    final outcome = await whileExternal(
      () => authenticator.authenticate(
        on ? 'Confirm it\'s you to turn on app lock' : 'Confirm it\'s you to turn off app lock',
      ),
    );
    if (outcome != AuthOutcome.success) return outcome;
    await repo.setAppLockEnabled(on);
    _enabled = on;
    notifyListeners();
    return outcome;
  }

  Future<void> setTimeout(Duration d) async {
    await repo.setAppLockTimeout(d);
    _timeout = d;
    notifyListeners();
  }

  Future<void> setHideInSwitcher(bool on) async {
    await repo.setHideInSwitcher(on);
    _hideInSwitcher = on;
    await window.setSecure(on);
    notifyListeners();
  }
}

/// Makes the controller reachable from any screen (Settings, and the export/import paths that
/// wrap themselves in [AppLockController.whileExternal]).
class AppLockScope extends InheritedNotifier<AppLockController> {
  const AppLockScope({super.key, required AppLockController controller, required super.child})
    : super(notifier: controller);

  static AppLockController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppLockScope>()?.notifier;

  /// Wraps [action] with [AppLockController.whileExternal] when a controller is in scope (tests that
  /// pump a screen on its own have none).
  static Future<T> external<T>(BuildContext context, Future<T> Function() action) {
    final c = context.getInheritedWidgetOfExactType<AppLockScope>()?.notifier;
    return c == null ? action() : c.whileExternal(action);
  }
}
