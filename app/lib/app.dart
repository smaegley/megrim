import 'package:flutter/material.dart';

import 'repositories/megrim_repository.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'services/connectivity_monitor.dart';
import 'services/geocoder.dart';
import 'theme.dart';

/// Root widget. Decides between onboarding and the main shell based on whether the disclaimer has
/// been accepted and a home location is set. Kicks off a background enrichment-queue drain.
class MegrimApp extends StatefulWidget {
  final MegrimRepository repo;

  /// Injectable for tests (passed through to [OnboardingScreen]); defaults to a real geocoder.
  final Geocoder? geocoder;
  const MegrimApp({super.key, required this.repo, this.geocoder});

  @override
  State<MegrimApp> createState() => _MegrimAppState();
}

class _MegrimAppState extends State<MegrimApp> {
  late Future<bool> _onboardedFuture;
  // Set directly, bypassing a fresh DB read, the moment onboarding finishes in this session — we
  // already know the answer is true because we just wrote it ourselves a line above. Re-deriving
  // it via a brand-new Future (and waiting on FutureBuilder a second time) was a real,
  // reproducible bug: onboarding would visibly succeed (home location saved, confirmed by
  // reopening the app) but the UI stayed on a spinner indefinitely until the app was force-closed
  // and relaunched. Skipping the re-fetch removes the async gap that bug lived in, regardless of
  // its exact cause.
  bool? _onboardedOverride;
  final ConnectivityMonitor _connectivity = ConnectivityMonitor();

  @override
  void initState() {
    super.initState();
    _onboardedFuture = widget.repo.isOnboarded;
    // Drain the enrichment queue on cold start, and again whenever connectivity returns so events
    // logged offline get their weather as soon as the network is back (SPEC §5.1).
    _drainEnrichment();
    _connectivity.start(_drainEnrichment);
  }

  @override
  void dispose() {
    _connectivity.dispose();
    super.dispose();
  }

  void _drainEnrichment() {
    // Background best-effort; failures leave rows queued for the next trigger.
    widget.repo.processEnrichmentQueue().catchError((_) {});
  }

  void _onOnboardingComplete() {
    setState(() => _onboardedOverride = true);
    _drainEnrichment();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Megrim',
      debugShowCheckedModeBanner: false,
      // Follow the phone's light/dark setting (backlog #8).
      theme: megrimLightTheme(),
      darkTheme: megrimDarkTheme(),
      themeMode: ThemeMode.system,
      home: _onboardedOverride == true
          ? HomeShell(repo: widget.repo)
          : FutureBuilder<bool>(
              future: _onboardedFuture,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }
                if (snap.data == true) {
                  return HomeShell(repo: widget.repo);
                }
                return OnboardingScreen(
                    repo: widget.repo,
                    onComplete: _onOnboardingComplete,
                    geocoder: widget.geocoder);
              },
            ),
    );
  }
}
