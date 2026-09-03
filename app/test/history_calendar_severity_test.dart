import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/screens/history_screen.dart';

MigraineEvent _event(String id, DateTime startedAt, int? severity,
        {DateTime? endedAt}) =>
    MigraineEvent(
      id: id,
      startedAt: startedAt,
      endedAt: endedAt,
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

  group('eventsByLocalDay', () {
    test('groups multiple events on the same day together, in insertion order', () {
      final day = DateTime.utc(2024, 6, 1, 9);
      final a = _event('a', day, 3);
      final b = _event('b', day.add(const Duration(hours: 4)), 7);
      final grouped = eventsByLocalDay([a, b]);
      expect(grouped['2024-06-1']!.map((e) => e.id), ['a', 'b']);
    });

    test('keeps different days separate', () {
      final a = _event('a', DateTime.utc(2024, 6, 1, 9), 3);
      final b = _event('b', DateTime.utc(2024, 6, 2, 9), 7);
      final grouped = eventsByLocalDay([a, b]);
      expect(grouped['2024-06-1']!.map((e) => e.id), ['a']);
      expect(grouped['2024-06-2']!.map((e) => e.id), ['b']);
    });

    test('a day with no events has no entry', () {
      expect(eventsByLocalDay(const []).containsKey('2024-06-1'), isFalse);
    });
  });

  // Backlog #10: a multi-day migraine covers every local day from its start date to its end date.
  // Times are built as *local* wall-clock values and converted to UTC for storage, so the expected
  // local days hold under any test timezone (the suite runs under both UTC and America/Denver).
  group('localDaysSpanned', () {
    test('start and end on the same local day is a single day', () {
      final e = _event('a', DateTime(2024, 6, 5, 9).toUtc(), 4,
          endedAt: DateTime(2024, 6, 5, 21).toUtc());
      expect(localDaysSpanned(e), [DateTime(2024, 6, 5)]);
    });

    test('spans every day through the end date, across a month boundary', () {
      final e = _event('a', DateTime(2024, 6, 30, 20).toUtc(), 4,
          endedAt: DateTime(2024, 7, 2, 4).toUtc());
      expect(localDaysSpanned(e), [
        DateTime(2024, 6, 30),
        DateTime(2024, 7, 1),
        DateTime(2024, 7, 2),
      ]);
    });

    test('an ongoing event covers only its start day', () {
      final e = _event('a', DateTime(2024, 6, 5, 9).toUtc(), 4);
      expect(localDaysSpanned(e), [DateTime(2024, 6, 5)]);
    });

    test('a malformed end before the start falls back to the start day', () {
      final e = _event('a', DateTime(2024, 6, 5, 9).toUtc(), 4,
          endedAt: DateTime(2024, 6, 3, 9).toUtc());
      expect(localDaysSpanned(e), [DateTime(2024, 6, 5)]);
    });

    test('a span crossing the November DST fall-back keeps one entry per date', () {
      // Under America/Denver, 2024-11-03 has 25 hours; Duration-based day stepping would
      // land on Nov 3 twice and drop Nov 4 (the cb6671c bug class).
      final e = _event('a', DateTime(2024, 11, 2, 12).toUtc(), 4,
          endedAt: DateTime(2024, 11, 4, 12).toUtc());
      expect(localDaysSpanned(e), [
        DateTime(2024, 11, 2),
        DateTime(2024, 11, 3),
        DateTime(2024, 11, 4),
      ]);
    });
  });

  group('multi-day spans in the day maps (backlog #10)', () {
    test('severity applies to every day the event covers', () {
      final e = _event('a', DateTime(2024, 6, 30, 20).toUtc(), 6,
          endedAt: DateTime(2024, 7, 2, 4).toUtc());
      final sev = severityByLocalDay([e]);
      expect(sev['2024-06-30'], 6);
      expect(sev['2024-07-1'], 6);
      expect(sev['2024-07-2'], 6);
    });

    test('a covered day still keeps the max severity across events', () {
      final span = _event('span', DateTime(2024, 6, 5, 9).toUtc(), 3,
          endedAt: DateTime(2024, 6, 7, 9).toUtc());
      final spike = _event('spike', DateTime(2024, 6, 6, 12).toUtc(), 8,
          endedAt: DateTime(2024, 6, 6, 18).toUtc());
      final sev = severityByLocalDay([span, spike]);
      expect(sev['2024-06-5'], 3);
      expect(sev['2024-06-6'], 8);
      expect(sev['2024-06-7'], 3);
    });

    test('eventsByLocalDay lists the event under every covered day', () {
      final e = _event('a', DateTime(2024, 6, 30, 20).toUtc(), 6,
          endedAt: DateTime(2024, 7, 2, 4).toUtc());
      final grouped = eventsByLocalDay([e]);
      expect(grouped['2024-06-30']!.single.id, 'a');
      expect(grouped['2024-07-1']!.single.id, 'a');
      expect(grouped['2024-07-2']!.single.id, 'a');
    });
  });
}
