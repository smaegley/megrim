import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/screens/event_detail_screen.dart';

void main() {
  group('buildEndedAt', () {
    final start = DateTime(2026, 9, 18, 9, 0);
    final newStart = DateTime(2026, 9, 17, 8, 0);

    test('zero duration (start == end) lands end on the new start', () {
      expect(
        buildEndedAt(
          currentEnd: start,
          endTouched: false,
          oldStart: start,
          newStart: newStart,
        ),
        newStart,
      );
    });

    test('six-hour duration is preserved across a start edit', () {
      final end = start.add(const Duration(hours: 6));
      expect(
        buildEndedAt(
          currentEnd: end,
          endTouched: false,
          oldStart: start,
          newStart: newStart,
        ),
        newStart.add(const Duration(hours: 6)),
      );
    });

    test('leaves end unchanged once the end has been touched', () {
      final end = start.add(const Duration(hours: 6));
      expect(
        buildEndedAt(
          currentEnd: end,
          endTouched: true,
          oldStart: start,
          newStart: newStart,
        ),
        end,
      );
    });

    test('leaves a null (ongoing) end unchanged', () {
      expect(
        buildEndedAt(
          currentEnd: null,
          endTouched: false,
          oldStart: start,
          newStart: newStart,
        ),
        isNull,
      );
    });
  });
}
