import 'package:flutter/material.dart';

import 'repositories/megrim_repository.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'theme.dart';

/// Root widget. Decides between onboarding and the main shell based on whether the disclaimer has
/// been accepted and a home location is set. Kicks off a background enrichment-queue drain.
class MegrimApp extends StatefulWidget {
  final MegrimRepository repo;
  const MegrimApp({super.key, required this.repo});

  @override
  State<MegrimApp> createState() => _MegrimAppState();
}

class _MegrimAppState extends State<MegrimApp> {
  late Future<bool> _onboarded;

  @override
  void initState() {
    super.initState();
    _onboarded = widget.repo.isOnboarded;
  }

  void _refreshGate() {
    setState(() => _onboarded = widget.repo.isOnboarded);
    // Drain any pending enrichment in the background; ignore failures (stays queued).
    widget.repo.processEnrichmentQueue().catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Megrim',
      debugShowCheckedModeBanner: false,
      theme: megrimDarkTheme(),
      home: FutureBuilder<bool>(
        future: _onboarded,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snap.data == true) {
            return HomeShell(repo: widget.repo);
          }
          return OnboardingScreen(repo: widget.repo, onComplete: _refreshGate);
        },
      ),
    );
  }
}
