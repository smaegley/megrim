import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/l10n/formats.dart';
import 'package:megrim/l10n/l10n.dart';

void main() {
  final d = DateTime(2026, 11, 9, 14, 5);

  test('a British phone keeps day-month dates; an American one gets its own', () {
    final gb = Formats('en_GB');
    expect(gb.dateWeekday(d), 'Mon, 9 Nov 2026');
    expect(gb.date(d), '9 Nov 2026');
    expect(gb.time(d), '14:05');
    final us = Formats('en_US');
    expect(us.dateWeekday(d), 'Mon, Nov 9, 2026');
    expect(us.time(d), matches(RegExp(r'^2:05\sPM$')));
    expect(Formats('en_US', use24h: true).time(d), '14:05');
  });

  test('numbers use the locale separator', () {
    expect(Formats('en_GB').decimal(7.5, 1), '7.5');
    expect(Formats('fr').decimal(7.5, 1), '7,5');
  });

  testWidgets('the format locale takes the region from the phone when the language matches',
      (tester) async {
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    tester.platformDispatcher.localesTestValue = const [Locale('en', 'GB')];
    expect(formatLocale(englishL10n), 'en_GB');
    tester.platformDispatcher.localesTestValue = const [Locale('de', 'DE'), Locale('en', 'AU')];
    expect(formatLocale(englishL10n), 'en_AU');
    tester.platformDispatcher.localesTestValue = const [Locale('de', 'DE')];
    expect(formatLocale(englishL10n), 'en');
  });
}
