import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../services/app_lock.dart';

/// Sits in `MaterialApp.builder`, above the Navigator, so the lock covers every route, dialog and
/// snackbar (backlog #24). The app underneath stays mounted but [Offstage] — not painted, not
/// hit-testable, and out of the semantics tree, so TalkBack/VoiceOver can't read it either — and
/// it comes back exactly where the user left it once unlocked.
class AppLockGate extends StatelessWidget {
  final AppLockController controller;
  final Widget child;

  /// iOS has no FLAG_SECURE; it gets a blank cover whenever the app isn't in the foreground, so the
  /// switcher snapshot shows nothing. Injectable for tests.
  final bool coverWhenInactive;

  AppLockGate({super.key, required this.controller, required this.child, bool? coverWhenInactive})
    : coverWhenInactive = coverWhenInactive ?? Platform.isIOS;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final Widget? cover;
        if (!controller.loaded) {
          // Settings not read yet: show nothing rather than flash the diary before a lock.
          cover = const _BlankCover();
        } else if (controller.locked || controller.turnedOffNoCredential) {
          cover = _LockScreen(controller: controller);
        } else if (coverWhenInactive && controller.hideInSwitcher && !controller.foreground) {
          cover = const _BlankCover();
        } else {
          cover = null;
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            Offstage(offstage: cover != null, child: child),
            ?cover,
          ],
        );
      },
    );
  }
}

class _BlankCover extends StatelessWidget {
  const _BlankCover();

  @override
  Widget build(BuildContext context) => ColoredBox(color: Theme.of(context).colorScheme.surface);
}

class _LockScreen extends StatefulWidget {
  final AppLockController controller;
  const _LockScreen({required this.controller});

  @override
  State<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<_LockScreen> with WidgetsBindingObserver {
  AppLockController get c => widget.controller;
  String? _message;
  bool _busy = false;

  /// The prompt opens by itself once per lock, as soon as the app is in the foreground. After a
  /// cancel it waits for the button, so the user isn't trapped in a prompt loop.
  bool _autoPrompted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoPrompt());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _maybeAutoPrompt();
  }

  void _maybeAutoPrompt() {
    if (!mounted || _autoPrompted || !c.locked) return;
    // The OS prompt needs a foreground activity; on a cold start the first frame can come before
    // that, in which case the resumed callback above picks it up.
    final s = WidgetsBinding.instance.lifecycleState;
    if (s != null && s != AppLifecycleState.resumed) return;
    _autoPrompted = true;
    _unlock();
  }

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final outcome = await c.unlock();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = switch (outcome) {
        AuthOutcome.lockedOut => 'Too many attempts. Wait a moment, then try again.',
        AuthOutcome.error => 'Couldn\'t ask for your phone\'s unlock. Try again.',
        _ => null,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final turnedOff = c.turnedOffNoCredential;
    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/logo.png',
                    width: 72,
                    height: 72,
                    excludeFromSemantics: true,
                  ),
                ),
                const SizedBox(height: 24),
                if (turnedOff) ...[
                  Text(
                    'App lock turned off',
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your phone no longer has a screen lock, so Megrim can\'t check it\'s you. '
                    'App lock has been turned off. Set a screen lock in your phone\'s settings, '
                    'then turn app lock back on in Settings › Privacy.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(onPressed: c.acknowledgeTurnedOff, child: const Text('Continue')),
                ] else ...[
                  Text(
                    'Megrim is locked',
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _busy ? null : _unlock,
                    icon: const Icon(Icons.lock_open),
                    label: const Text('Unlock'),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
