import 'package:flutter/widgets.dart' show Locale;

/// The languages the app offers (docs/TRANSLATIONS.md, decision D5).
///
/// lib/l10n/ also holds translations that aren't finished yet (Weblate commits them as they
/// progress), and gen-l10n lists every file it finds. This list, not
/// `AppLocalizations.supportedLocales`, decides what users get: a language is added here in the
/// release where it first meets the bar, checked by `tools/l10n.py check`. English stays first:
/// it's the fallback when none of the phone's languages match.
///
/// After editing, run `tools/l10n.py sync` so Android's per-app language list
/// (res/xml/locales_config.xml) and iOS's CFBundleLocalizations match.
const List<Locale> kShippedLocales = [
  Locale('en'),
];
