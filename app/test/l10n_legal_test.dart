import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/l10n/l10n.dart';
import 'package:megrim/legal.dart';

/// The legal and About text moved into app_en.arb (docs/TRANSLATIONS.md). Until the English
/// constants in legal.dart are removed, they must say exactly what the messages say.
void main() {
  final l = englishL10n;

  test('the legal messages match the English constants', () {
    expect(l.legalMedicalDisclaimer, kMedicalDisclaimer);
    expect(l.legalPrivacySummary, kPrivacySummary);
    expect(l.legalWeatherAttribution, kWeatherAttribution);
    expect(l.legalAppTitle, kAppTitle);
    expect(l.legalAppSubtitle, kAppSubtitle);
    expect(l.legalShortDescription, kShortDescription);
    expect(l.legalFullDescription, kFullDescription);
  });

  test('the correlation card caveats match', () {
    expect(correlationCardCaveats(l), kCorrelationCaveats);
  });
}
