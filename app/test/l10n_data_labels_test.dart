import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/l10n/data_labels.dart';
import 'package:megrim/l10n/l10n.dart';

/// Values stored and computed in English are translated only for display (docs/TRANSLATIONS.md).
void main() {
  test('every default and analytics label has a translation', () {
    final missing =
        kDataValuesNeedingTranslation.where((v) => !kTranslatedDataValues.contains(v)).toList();
    expect(missing, isEmpty, reason: 'add these to dataLabel() and app_en.arb');
  });

  test('in English, every label reads exactly as stored', () {
    for (final v in kDataValuesNeedingTranslation) {
      expect(dataLabel(englishL10n, v), v);
    }
  });

  test('anything else, such as a trigger the user typed, is shown unchanged', () {
    expect(dataLabel(englishL10n, 'Cheese'), 'Cheese');
    expect(dataLabel(englishL10n, ''), '');
  });
}
