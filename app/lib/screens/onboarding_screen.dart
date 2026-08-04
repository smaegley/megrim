import 'package:flutter/material.dart';

import '../legal.dart';
import '../models/home_location.dart';
import '../repositories/megrim_repository.dart';
import '../services/geocoder.dart';
import '../widgets/location_picker.dart';

/// First-run onboarding (SPEC §4.1): welcome → medical disclaimer (must accept) → home location
/// → weather enrichment opt-in (default OFF — F-Droid review requirement: third-party network
/// use must be explicitly consented).
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
  bool _weatherOptIn = false;
  bool _saving = false;

  Future<void> _finish() async {
    if (_home == null) return;
    setState(() => _saving = true);
    await widget.repo.acceptDisclaimer();
    await widget.repo.setHomeLocation(_home!);
    await widget.repo.setWeatherEnrichmentEnabled(_weatherOptIn);
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
            2 => _location(),
            _ => _weather(),
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
              'Optionally, it can add weather and pressure context to your entries '
              'from Open-Meteo.com — you choose in a moment, and it is off unless '
              'you turn it on.',
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
                    'Used on-device for daylight and season analytics, and — only if you '
                    'enable weather enrichment in the next step — to fetch weather for your '
                    'entries. Searching here sends the place name you type to Open-Meteo\'s '
                    'geocoder to find coordinates; after that, only rounded (~1 km) '
                    'coordinates would ever be sent, and only for weather. Prefer not to '
                    'search online? Type GPS coordinates or a Plus Code instead — both are '
                    'decoded on-device.',
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
              onPressed: _home != null ? () => setState(() => _step = 3) : null,
              child: const Text('Continue'),
            ),
          ),
        ],
      );

  Widget _weather() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Weather enrichment',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Megrim can fetch the weather around each migraine — temperature, '
                    'humidity, barometric pressure, air quality — so Analytics can look '
                    'for patterns like pressure swings before an attack.\n\n'
                    'If you turn this on, the entry\'s date and rounded (~1 km) '
                    'coordinates are sent to Open-Meteo.com, a non-commercial weather '
                    'service. Nothing else ever leaves your device: no account, no '
                    'telemetry, and no server of ours.\n\n'
                    'Leave it off and Megrim is fully offline. You can change this '
                    'anytime in Settings.',
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _weatherOptIn,
                    onChanged: (v) => setState(() => _weatherOptIn = v),
                    title: const Text('Fetch weather for my entries'),
                    subtitle: const Text(
                        'Recommended if you want pressure correlations'),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: !_saving ? _finish : null,
              child: _saving
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Finish'),
            ),
          ),
        ],
      );
}
