import 'package:flutter/material.dart';

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

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      QuickLogScreen(repo: widget.repo),
      HistoryScreen(repo: widget.repo),
      AnalyticsScreen(repo: widget.repo),
      SettingsScreen(repo: widget.repo),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
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
