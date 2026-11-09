// Legal / policy text (SPEC §9). Kept in one place so onboarding, About, and the store listing
// stay in sync.
//
// Translations (docs/TRANSLATIONS.md): the text shown in the app is in app_en.arb as `legal*`
// messages (disclaimer, privacy summary, weather attribution, About copy, correlation caveats),
// reached through context.l10n. The English constants below are kept only for files not yet
// converted (the Log screen, Analytics and the report); remove each once nothing uses it.

import 'l10n/l10n.dart';

const String kMedicalDisclaimer =
    'Megrim is a personal diary and is not a medical device. It does not '
    'diagnose, treat, cure, or prevent any condition. "Suspected factors" are '
    'statistical associations in your own log — association is not causation. '
    'Always consult a qualified healthcare professional about your migraines '
    'and before making any treatment decisions.';

const String kPrivacySummary =
    'All data stays on your device. We operate no servers and collect nothing — '
    'no accounts, no analytics, no identifiers, no crash reporting. Weather '
    'enrichment is off unless you turn it on; then the app\'s only automatic '
    'network traffic is to Open-Meteo.com, to fetch weather for the approximate '
    '(~1 km rounded) location and date of entries you create. Backups use your '
    'phone\'s own backup (Google on Android, iCloud or your computer on iPhone), '
    'which you control in its settings; export files go wherever you choose to '
    'save them.';

/// Caveats shown verbatim on the correlations card (SPEC §9 / §6.2), in the app's language. The
/// PDF report lists the analytics' own caveats instead.
List<String> correlationCardCaveats(AppLocalizations l) => [
      l.legalCaveatOddsRatioExplained,
      l.legalCaveatSmallSample,
      l.correlationsCaveatOddsRatio,
      l.caveatMultipleComparisons,
      l.caveatNotCausation,
    ];

const String kWeatherAttribution = 'Weather data by Open-Meteo.com';
const String kSourceUrl = 'https://github.com/smaegley/megrim';

/// The import-format guide (docs/IMPORT.md) — linked from Settings so someone migrating from
/// another tracker can find the spec without hunting through the repo.
const String kImportDocUrl = '$kSourceUrl/blob/main/docs/IMPORT.md';

/// The single Dart-level source of truth for the displayed app version. There's no plugin-free
/// way to read pubspec.yaml's `version:` at runtime, so keep this in sync with it by hand at each
/// release (both are one-line edits).
const String kAppVersion = '1.0.8';

/// Store / About listing copy (kept in sync with fastlane/metadata and the README).
const String kAppTitle = 'Megrim: Migraine Log';
const String kAppSubtitle = 'Offline Migraine Log';
const String kAppTagline = 'Smart migraine tracking that stays on your device.';
const String kShortDescription =
    'Private, offline migraine log with automatic on-device pattern insights.';
const String kFullDescription =
    'Megrim is an open-source, offline-first migraine diary that helps you find '
    'your personal triggers. The app automatically adds time-of-day, season, '
    'daylight and moon context to your entries (and, if you opt in, local weather '
    'and barometric pressure), calculating correlations entirely on your phone. With no accounts, no cloud servers, and '
    'zero tracking, your health data stays completely private and under your control.';
