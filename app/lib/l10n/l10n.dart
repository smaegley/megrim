import 'package:flutter/widgets.dart';

import 'gen/app_localizations.dart';

export 'gen/app_localizations.dart';

/// The app's messages for the current language (docs/TRANSLATIONS.md).
///
/// Falls back to English where no [AppLocalizations] delegate is installed: widget tests pump
/// screens in a bare `MaterialApp`, and the app itself always installs the delegates.
extension L10nContext on BuildContext {
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ?? englishL10n;
}

/// English messages without a [BuildContext], for code outside the widget tree that has no
/// language of its own to follow.
final AppLocalizations englishL10n = lookupAppLocalizations(const Locale('en'));
