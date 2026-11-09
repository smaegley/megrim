import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'l10n.dart';

/// Dates, times and numbers in the user's locale (docs/TRANSLATIONS.md, decision D7).
///
/// The language is the app's; the region is the phone's when its language matches. The app has
/// one English, so a British phone resolves to plain `en`, which intl formats the American way;
/// formatting with `en_GB` instead gives "Mon, 9 Nov 2026" there and "Mon, Nov 9, 2026" on a US
/// phone.
///
/// Display only. Keys and stored values (`yyyy-MM-dd`, `yyyy-MM`) keep their fixed patterns.
class Formats {
  /// The intl locale used for every pattern, e.g. `en_GB`.
  final String locale;

  /// 24-hour times. On screen this follows the phone's setting; elsewhere, the locale's habit.
  final bool use24h;

  Formats(this.locale, {bool? use24h})
      : use24h = use24h ?? !DateFormat.jm(locale).pattern!.contains('a');

  /// For a screen: the app's language, the phone's region and its 12/24-hour setting.
  factory Formats.of(BuildContext context) => Formats(
        formatLocale(context.l10n),
        use24h: MediaQuery.maybeAlwaysUse24HourFormatOf(context) == true ? true : null,
      );

  /// For code outside the widget tree (the PDF report, notifications).
  factory Formats.forL10n(AppLocalizations l) => Formats(formatLocale(l));

  /// 9 Nov 2026
  String date(DateTime d) => DateFormat.yMMMd(locale).format(d);

  /// Mon, 9 Nov 2026
  String dateWeekday(DateTime d) => DateFormat.yMMMEd(locale).format(d);

  /// Monday 9 November 2026
  String dateLong(DateTime d) => DateFormat.yMMMMEEEEd(locale).format(d);

  /// Mon 9 Nov (no year)
  String dayMonthWeekday(DateTime d) => DateFormat.MMMEd(locale).format(d);

  /// 14:05, or 2:05 PM
  String time(DateTime d) => (use24h ? DateFormat.Hm(locale) : DateFormat.jm(locale)).format(d);

  /// Mon 9 Nov 2026, 14:05
  String dateWeekdayTime(DateTime d) => _withTime(DateFormat.yMMMEd(locale), d);

  /// Mon 9 Nov, 14:05
  String dayMonthWeekdayTime(DateTime d) => _withTime(DateFormat.MMMEd(locale), d);

  /// November 2026
  String monthYear(DateTime d) => DateFormat.yMMMM(locale).format(d);

  /// Nov 2026
  String monthYearShort(DateTime d) => DateFormat.yMMM(locale).format(d);

  /// Nov
  String monthShort(DateTime d) => DateFormat.MMM(locale).format(d);

  /// A number with a fixed count of decimals: 7.5, or 7,5.
  String decimal(num v, int decimals) => NumberFormat.decimalPatternDigits(
        locale: locale,
        decimalDigits: decimals,
      ).format(v);

  /// A whole number with the locale's grouping: 1,234 or 1 234.
  String integer(int v) => NumberFormat.decimalPattern(locale).format(v);

  /// A percentage: 42%, or 42 %.
  String percent(num pct) => NumberFormat.percentPattern(locale).format(pct / 100);

  String _withTime(DateFormat date, DateTime d) =>
      (use24h ? date.add_Hm() : date.add_jm()).format(d);
}

/// The intl locale for [l]'s language: the phone's first preferred locale in that language (so
/// its region's conventions apply), or the language alone.
String formatLocale(AppLocalizations l) {
  final lang = l.localeName.split('_').first;
  for (final p in WidgetsBinding.instance.platformDispatcher.locales) {
    if (p.languageCode != lang) continue;
    final tag = p.countryCode == null || p.countryCode!.isEmpty ? lang : '${lang}_${p.countryCode}';
    if (DateFormat.localeExists(tag)) return tag;
    break;
  }
  // A language intl has no data for (e.g. the en_XA pseudo-locale) falls back to its base.
  return DateFormat.localeExists(l.localeName) ? l.localeName : lang;
}
