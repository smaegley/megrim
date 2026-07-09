import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/screens/history_screen.dart';

MigraineEvent _event(String id, DateTime startedAt, int? severity) => MigraineEvent(
      id: id,
      startedAt: startedAt,
      severity: severity,
      createdAt: startedAt,
      updatedAt: startedAt,
    );

void main() {
  group('severityByLocalDay', () {
    test('keeps the max severity when multiple events share a day, any order', () {
      final day = DateTime.utc(2024, 6, 1, 9);
      final a = _event('a', day, 3);
      final b = _event('b', day.add(const Duration(hours: 2)), null);
      expect(severityByLocalDay([a, b])['2024-06-1'], 3);
      expect(severityByLocalDay([b, a])['2024-06-1'], 3);
    });

    test('two real severities: the higher one wins regardless of order', () {
      final day = DateTime.utc(2024, 6, 1, 9);
      final low = _event('low', day, 3);
      final high = _event('high', day.add(const Duration(hours: 4)), 7);
      expect(severityByLocalDay([low, high])['2024-06-1'], 7);
      expect(severityByLocalDay([high, low])['2024-06-1'], 7);
    });

    test('a day with only null severities stays null (not missing)', () {
      final day = DateTime.utc(2024, 6, 1, 9);
      final a = _event('a', day, null);
      expect(severityByLocalDay([a]).containsKey('2024-06-1'), isTrue);
      expect(severityByLocalDay([a])['2024-06-1'], isNull);
    });
  });
}
