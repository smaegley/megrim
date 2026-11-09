import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/l10n/device_l10n.dart';

/// Code with no BuildContext (notifications, the unlock prompt) picks its language the way
/// MaterialApp does: the phone's first supported locale, else English.
void main() {
  testWidgets('a supported phone language is used; anything else falls back to English',
      (tester) async {
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    tester.platformDispatcher.localesTestValue = const [Locale('en', 'GB')];
    expect(deviceLocale().languageCode, 'en');
    tester.platformDispatcher.localesTestValue = const [Locale('de', 'DE')];
    expect(deviceLocale().languageCode, 'en');
    expect(deviceL10n().notifReminderBody, 'How was today?');
  });
}
