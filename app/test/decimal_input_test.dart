import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/models/decimal_input.dart';

void main() {
  test('accepts a point or a comma as the decimal separator', () {
    expect(parseDecimalInput('7.5'), 7.5);
    expect(parseDecimalInput('7,5'), 7.5);
    expect(parseDecimalInput(' 8 '), 8.0);
  });

  test('empty or unparseable text is null', () {
    expect(parseDecimalInput(''), isNull);
    expect(parseDecimalInput('  '), isNull);
    expect(parseDecimalInput('seven'), isNull);
    expect(parseDecimalInput('1,000.5'), isNull);
  });
}
