import 'package:flutter/widgets.dart';

import 'gen/app_localizations.dart';

/// The language `MaterialApp` picks, for code with no [BuildContext] (notifications, the phone's
/// unlock prompt): the first of the phone's preferred locales the app supports, else English
/// (docs/TRANSLATIONS.md).
Locale deviceLocale() => basicLocaleListResolution(
      WidgetsBinding.instance.platformDispatcher.locales,
      AppLocalizations.supportedLocales,
    );

/// Messages in [deviceLocale].
AppLocalizations deviceL10n() => lookupAppLocalizations(deviceLocale());
