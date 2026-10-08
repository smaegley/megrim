import 'package:flutter/material.dart';

import '../services/app_lock.dart';
import '../services/app_shortcuts.dart';

import '../repositories/megrim_repository.dart';
import 'analytics_screen.dart';
import 'history_screen.dart';
import 'quick_log_screen.dart';
import 'settings_screen.dart';

/// Bottom-navigation shell: Log · History · Analytics · Settings.
class HomeShell extends StatefulWidget {
  final MegrimRepository repo;
  const HomeShell({super.key, required this.repo});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  // Bumped when an app-icon shortcut tap is acted on (backlog #23): Quick Log starts a migraine.
  int _shortcutToken = 0;
  AppShortcuts? _shortcuts;
  AppLockController? _lock;
  bool _shortcutScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shortcuts = AppShortcutsScope.maybeOf(context);
    final lock = AppLockScope.maybeOf(context);
    if (!identical(shortcuts, _shortcuts)) {
      _shortcuts?.removeListener(_maybeHandleShortcut);
      _shortcuts = shortcuts?..addListener(_maybeHandleShortcut);
    }
    if (!identical(lock, _lock)) {
      _lock?.removeListener(_maybeHandleShortcut);
      _lock = lock?..addListener(_maybeHandleShortcut);
    }
    _maybeHandleShortcut();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shortcuts?.removeListener(_maybeHandleShortcut);
    _lock?.removeListener(_maybeHandleShortcut);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _maybeHandleShortcut();
  }

  bool get _readyForShortcut {
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != null && state != AppLifecycleState.resumed) return false;
    final lock = _lock;
    return lock == null || (lock.loaded && !lock.locked);
  }

  /// Act on a waiting "Log migraine" shortcut tap — only in the foreground and, with app lock on,
  /// once unlocked. Deferred to after the frame: Android can deliver the shortcut just before the
  /// app reports it has resumed, and app lock must get the chance to re-lock on that resume
  /// first; otherwise a migraine could be started behind a lock that is about to appear.
  void _maybeHandleShortcut() {
    if (_shortcutScheduled || !(_shortcuts?.pending ?? false) || !_readyForShortcut) return;
    _shortcutScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _shortcutScheduled = false;
      if (!mounted || !_readyForShortcut || !(_shortcuts?.take() ?? false)) return;
      ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
      setState(() {
        _index = 0;
        _logToken++;
        _shortcutToken++;
      });
    });
    WidgetsBinding.instance.scheduleFrame();
  }
  // Bumped whenever the Analytics tab is opened, forcing it to recompute against current data.
  int _analyticsToken = 0;
  // Same idea for the Log tab's backup line, which would otherwise keep the date it first read
  // (IndexedStack never disposes the page).
  int _logToken = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      QuickLogScreen(
        repo: widget.repo,
        refreshToken: _logToken,
        startToken: _shortcutToken,
        onOpenSettings: () => setState(() => _index = 3),
      ),
      HistoryScreen(repo: widget.repo),
      AnalyticsScreen(repo: widget.repo, refreshToken: _analyticsToken),
      SettingsScreen(repo: widget.repo),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          // Dismiss any lingering snackbar (e.g. the delete/undo) on page change.
          ScaffoldMessenger.of(context).clearSnackBars();
          setState(() {
            _index = i;
            if (i == 0) _logToken++;
            if (i == 2) _analyticsToken++;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.add_circle_outline), label: 'Log'),
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'History'),
          NavigationDestination(icon: Icon(Icons.insights), label: 'Analytics'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
