import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/widgets/days_since_card.dart';

void main() {
  group('daysBetweenLocalDates', () {
    test('spans a US spring-forward transition correctly', () {
      // 2026-03-08 is the US spring-forward date (23-hour local day).
      expect(daysBetweenLocalDates(DateTime(2026, 3, 7), DateTime(2026, 3, 9)), 2);
    });

    test('spans a US fall-back transition correctly', () {
      // 2026-11-01 is the US fall-back date (25-hour local day).
      expect(daysBetweenLocalDates(DateTime(2026, 10, 31), DateTime(2026, 11, 3)), 3);
    });

    test('same day is zero', () {
      expect(daysBetweenLocalDates(DateTime(2026, 1, 1), DateTime(2026, 1, 1)), 0);
    });
  });
}
