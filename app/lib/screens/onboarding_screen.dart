import 'package:flutter/material.dart';

import '../legal.dart';
import '../models/home_location.dart';
import '../repositories/megrim_repository.dart';
import '../services/geocoder.dart';
import '../widgets/location_picker.dart';

/// First-run onboarding (SPEC §4.1): welcome → medical disclaimer (must accept) → home location.
class OnboardingScreen extends StatefulWidget {
  final MegrimRepository repo;
  final VoidCallback onComplete;

  /// Injectable for tests (passed through to [LocationPickerField]); defaults to a real geocoder.
  final Geocoder? geocoder;
  const OnboardingScreen(
      {super.key, required this.repo, required this.onComplete, this.geocoder});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  bool _disclaimerAccepted = false;
  HomeLocation? _home;
  bool _saving = false;

  Future<void> _finish() async {
    if (_home == null) return;
    setState(() => _saving = true);
    await widget.repo.acceptDisclaimer();
    await widget.repo.setHomeLocation(_home!);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: switch (_step) {
            0 => _welcome(),
            1 => _disclaimer(),
            _ => _location(),
          },
        ),
      ),
    );
  }

  // Every onboarding step is wrapped in a scrollable so it never overflows on a small screen or
  // in landscape (found on a Nexus S / API 26 emulator — a plain Column + Spacer clips instead of
  // scrolling once content plus the on-screen keyboard/search results exceed the viewport).
  Widget _welcome() => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome to Megrim',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            const Text(
              'A private, offline migraine diary. Everything stays on your device. '
              'The only network traffic is to Open-Meteo.com to add weather and '
              'pressure context to your entries.',
            ),
            const SizedBox(height: 32),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => setState(() => _step = 1),
                child: const Text('Get started'),
              ),
            ),
          ],
        ),
      );

  Widget _disclaimer() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Before you begin',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Text(kMedicalDisclaimer,
                  style: Theme.of(context).textTheme.bodyLarge),
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _disclaimerAccepted,
            onChanged: (v) => setState(() => _disclaimerAccepted = v ?? false),
            title: const Text('I understand and accept.'),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _disclaimerAccepted ? () => setState(() => _step = 2) : null,
              child: const Text('Continue'),
            ),
          ),
        ],
      );

  Widget _location() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your home location',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          // The picker's search-results dropdown can grow tall enough (plus the on-screen
          // keyboard) to overflow a small screen — scroll it rather than the whole step, so the
          // Finish button stays fixed and always reachable (matches the disclaimer step's pattern).
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Used to fetch weather and pressure for your entries when GPS is '
                    'unavailable. Only rounded (~1 km) coordinates are ever sent to the '
                    'weather service.',
                  ),
                  const SizedBox(height: 16),
                  LocationPickerField(
                      geocoder: widget.geocoder,
                      onSelected: (loc) => setState(() => _home = loc)),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: (_home != null && !_saving) ? _finish : null,
              child: _saving
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Finish'),
            ),
          ),
        ],
      );
}
