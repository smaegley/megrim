// Legal / policy text (SPEC §9). Kept in one place so onboarding, About, and the store listing
// stay in sync.
//
// Translations (docs/TRANSLATIONS.md): the text itself is in app_en.arb as `legal*` messages
// (disclaimer, privacy summary, weather attribution, About copy), reached through context.l10n.

import 'l10n/l10n.dart';

/// Caveats shown verbatim on the correlations card (SPEC §9 / §6.2), in the app's language. The
/// PDF report lists the analytics' own caveats instead.
List<String> correlationCardCaveats(AppLocalizations l) => [
      l.legalCaveatOddsRatioExplained,
      l.legalCaveatSmallSample,
      l.correlationsCaveatOddsRatio,
      l.caveatMultipleComparisons,
      l.caveatNotCausation,
    ];

const String kSourceUrl = 'https://github.com/smaegley/megrim';

/// The import-format guide (docs/IMPORT.md) — linked from Settings so someone migrating from
/// another tracker can find the spec without hunting through the repo.
const String kImportDocUrl = '$kSourceUrl/blob/main/docs/IMPORT.md';

/// The single Dart-level source of truth for the displayed app version. There's no plugin-free
/// way to read pubspec.yaml's `version:` at runtime, so keep this in sync with it by hand at each
/// release (both are one-line edits).
const String kAppVersion = '1.0.9';

/// Store / About listing copy: the rest is `legal*` messages (kept in sync with fastlane/metadata
/// and the README).
const String kAppTagline = 'Smart migraine tracking that stays on your device.';
