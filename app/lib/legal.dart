// Legal / policy text (SPEC §9). Kept in one place so onboarding, About, and the store listing
// stay in sync.

const String kMedicalDisclaimer =
    'Megrim is a personal diary and is not a medical device. It does not '
    'diagnose, treat, cure, or prevent any condition. "Suspected factors" are '
    'statistical associations in your own log — association is not causation. '
    'Always consult a qualified healthcare professional about your migraines '
    'and before making any treatment decisions.';

const String kPrivacySummary =
    'All data stays on your device. We operate no servers and collect nothing — '
    'no accounts, no analytics, no identifiers, no crash reporting. The app\'s '
    'only network traffic is to Open-Meteo.com to fetch weather for the '
    'approximate (~1 km rounded) location and date of entries you create. '
    'Backups use standard Android device backup to your own Google account, '
    'which you control in Android settings; manual export files go wherever you '
    'choose to save them.';

/// Caveats shown verbatim on the correlations card (SPEC §9 / §6.2).
const List<String> kCorrelationCaveats = [
  'OR = odds ratio: how much more likely a migraine is on days with that factor. '
      'OR 2.0 ≈ twice the odds vs. other days; OR 1.0 means no effect.',
  'Small sample: results from a limited number of migraine days are noisy.',
  'Odds ratios use a +0.5 correction for empty cells; treat values near 1.0 as no signal.',
  'Many factors are tested at once (multiple comparisons) — some apparent associations are chance.',
  'Association is not causation. Use this to form hypotheses, not conclusions.',
];

const String kWeatherAttribution = 'Weather data by Open-Meteo.com';
const String kSourceUrl = 'https://github.com/megrim-app/megrim';

/// Store / About listing copy (kept in sync with fastlane/metadata and the README).
const String kAppTitle = 'Megrim: Migraine Log';
const String kAppSubtitle = 'Offline Migraine Log';
const String kAppTagline = 'Smart migraine tracking that stays on your device.';
const String kShortDescription =
    'Private, offline migraine log with automatic on-device pattern insights.';
const String kFullDescription =
    'Megrim is an open-source, offline-first migraine diary that helps you find '
    'your personal triggers. The app automatically adds local weather, '
    'barometric pressure, and time-of-day context to your entries, calculating '
    'correlations entirely on your phone. With no accounts, no cloud servers, and '
    'zero tracking, your health data stays completely private and under your control.';
