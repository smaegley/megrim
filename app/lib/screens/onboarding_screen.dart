import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
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
            Text(context.l10n.onboardingWelcomeTitle,
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            Text(context.l10n.onboardingWelcomeBody),
            const SizedBox(height: 32),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => setState(() => _step = 1),
                child: Text(context.l10n.onboardingGetStarted),
              ),
            ),
          ],
        ),
      );

  Widget _disclaimer() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.onboardingBeforeYouBegin,
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Text(context.l10n.legalMedicalDisclaimer,
                  style: Theme.of(context).textTheme.bodyLarge),
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _disclaimerAccepted,
            onChanged: (v) => setState(() => _disclaimerAccepted = v ?? false),
            title: Text(context.l10n.onboardingAccept),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _disclaimerAccepted ? () => setState(() => _step = 2) : null,
              child: Text(context.l10n.onboardingContinue),
            ),
          ),
        ],
      );

  Widget _location() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.onboardingHomeTitle,
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
                  Text(context.l10n.onboardingHomeBody),
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
              child: Text(context.l10n.onboardingContinue),
            ),
          ),
        ],
      );

  Widget _weather() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.onboardingWeatherTitle,
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.onboardingWeatherBody),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _weatherOptIn,
                    onChanged: (v) => setState(() => _weatherOptIn = v),
                    title: Text(context.l10n.onboardingWeatherSwitch),
                    subtitle: Text(context.l10n.onboardingWeatherSwitchSubtitle),
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
                  : Text(context.l10n.onboardingFinish),
            ),
          ),
        ],
      );
}
