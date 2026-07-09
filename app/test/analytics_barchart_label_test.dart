import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/screens/analytics_screen.dart';

/// Guards the bottom-axis label thinning added for "By year" once many years are tracked (a
/// user with 15+ years reported the 4-character year labels running together).
void main() {
  group('barChartLabelStep', () {
    test('shows every label when at or under the max (existing charts: <= 8 buckets)', () {
      expect(barChartLabelStep(4), 1); // e.g. season
      expect(barChartLabelStep(7), 1); // day of week
      expect(barChartLabelStep(8), 1); // moon phase — right at the threshold
    });

    test('thins labels once a series exceeds the max', () {
      expect(barChartLabelStep(9), 2);
      expect(barChartLabelStep(15), 2); // the reported case: 15 years tracked
      expect(barChartLabelStep(16), 2);
      expect(barChartLabelStep(17), 3);
    });

    test('a custom maxLabels is honored', () {
      expect(barChartLabelStep(10, maxLabels: 20), 1);
      expect(barChartLabelStep(10, maxLabels: 4), 3);
    });
  });
}
