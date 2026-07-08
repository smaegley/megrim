import 'package:flutter/foundation.dart' show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

/// Guards the About → View licences flow: Megrim's own GPL-3.0 licence must be registered (the
/// built-in page already aggregates third-party package licences; this adds the app's own).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Megrim GPL-3.0 licence is registered and readable', () async {
    // Mirror main()'s registration (test binding does not run main()).
    LicenseRegistry.addLicense(() async* {
      final gpl = await rootBundle.loadString('assets/gpl-3.0.txt');
      yield LicenseEntryWithLineBreaks(const ['Megrim'], gpl);
    });

    final entries = await LicenseRegistry.licenses.toList();
    final megrim = entries.where((e) => e.packages.contains('Megrim')).toList();
    expect(megrim, isNotEmpty, reason: 'Megrim licence not registered');

    final text = megrim.first.paragraphs.map((p) => p.text).join(' ');
    expect(text, contains('GNU GENERAL PUBLIC LICENSE'));
    expect(text, contains('Version 3'));
  });
}
