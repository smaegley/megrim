import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/analytics/correlations.dart';
import 'package:megrim/analytics/dashboard.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/services/report_content.dart';

/// Backlog #12: everything the printable report says is decided here, where it can be asserted
/// without rendering a PDF.
MigraineEvent event({
  required String id,
  required DateTime started,
  DateTime? ended,
  int? severity,
  bool? aura,
  String? notes,
  String? meds,
  String? triggers,
}) =>
    MigraineEvent(
      id: id,
      startedAt: started,
      endedAt: ended,
      severity: severity,
      auraPresent: aura,
      notes: notes,
      medsTaken: meds,
      triggersSuspected: triggers,
      createdAt: started,
      updatedAt: started,
    );

ReportContent build({
  DashboardResult? dash,
  CorrelationResult? corr,
  List<MigraineEvent> events = const [],
  String? homeLabel,
  bool Function(int)? canRender,
}) =>
    buildReportContent(
      dash: dash ?? const DashboardResult(summary: Summary(totalEvents: 0)),
      corr: corr ?? const CorrelationResult(available: true),
      events: events,
      appVersion: '1.0.6',
      now: DateTime(2026, 10, 5),
      homeLabel: homeLabel,
      canRender: canRender,
    );

void main() {
  group('sanitiseForFont', () {
    bool latinOnly(int rune) => rune < 0x250;

    test('replaces runes the font cannot draw and reports that it did', () {
      final r = sanitiseForFont('頭痛 bad', latinOnly);
      expect(r.text, '?? bad');
      expect(r.substituted, isTrue);
    });

    test('leaves renderable text alone', () {
      final r = sanitiseForFont('Łódź, Île-de-France', latinOnly);
      expect(r.text, 'Łódź, Île-de-France');
      expect(r.substituted, isFalse);
    });

    test('keeps newlines, which are laid out rather than drawn', () {
      expect(sanitiseForFont('a\nb', (_) => false).text, '?\n?');
    });
  });

  group('report content', () {
    test('the subtitle carries the counts, place, span and version', () {
      final c = build(
        dash: DashboardResult(
          summary: Summary(
            totalEvents: 55,
            firstEvent: DateTime(2024, 1, 5),
            lastEvent: DateTime(2026, 6, 1),
            yearsTracked: 2.4,
          ),
        ),
        homeLabel: 'Boulder, Colorado',
      );
      expect(c.subtitle, contains('55 entries'));
      expect(c.subtitle, contains('Boulder, Colorado'));
      expect(c.subtitle, contains('5 Jan 2024 to 1 Jun 2026'));
      expect(c.subtitle, contains('generated 5 Oct 2026'));
      expect(c.subtitle, contains('Megrim 1.0.6'));
    });

    test('medications are tallied with a helped share over recorded outcomes only', () {
      final c = build(events: [
        event(
          id: 'a',
          started: DateTime.utc(2026, 1, 1),
          meds: '[{"name":"Ibuprofen","helped":true},{"name":"Sumatriptan","helped":false}]',
        ),
        event(
          id: 'b',
          started: DateTime.utc(2026, 1, 2),
          meds: '[{"name":"Ibuprofen","helped":false},{"name":"Ibuprofen"}]',
        ),
      ]);
      final ibu = c.medications.firstWhere((m) => m.name == 'Ibuprofen');
      expect(ibu.taken, 3);
      expect(ibu.helped, 1);
      expect(ibu.notHelped, 1);
      expect(ibu.unknown, 1);
      expect(ibu.helpedPct, 50, reason: 'the unknown is excluded from the denominator');
      // Most-taken first.
      expect(c.medications.first.name, 'Ibuprofen');

      final suma = c.medications.firstWhere((m) => m.name == 'Sumatriptan');
      expect(suma.helpedPct, 0);
    });

    test('a medication with no recorded outcome has no percentage rather than 0%', () {
      final c = build(events: [
        event(id: 'a', started: DateTime.utc(2026, 1, 1), meds: '[{"name":"Aspirin"}]'),
      ]);
      expect(c.medications.single.helpedPct, isNull);
    });

    test('factor rows carry every bucket, with the app\'s headline rows marked', () {
      final c = build(
        corr: const CorrelationResult(
          available: true,
          totalMigraineDays: 55,
          totalDaysInRange: 879,
          baseRatePct: 6.26,
          topFactors: [
            TopFactor(
              factor: 'Day of week',
              condition: 'Fri',
              oddsRatio: 1.99,
              migraineDays: 13,
              totalDays: 126,
              migraineRatePct: 10.32,
            ),
          ],
          factors: {
            'Day of week': [
              FactorRow(
                  bucket: 'Mon',
                  migraineDays: 9,
                  totalDays: 126,
                  migraineRatePct: 7.14,
                  oddsRatio: 1.23),
              FactorRow(
                  bucket: 'Fri',
                  migraineDays: 13,
                  totalDays: 126,
                  migraineRatePct: 10.32,
                  oddsRatio: 1.99),
            ],
          },
        ),
      );
      final g = c.factorGroups.single;
      expect(g.name, 'Day of week');
      expect(g.rows.map((r) => r.bucket), ['Mon', 'Fri']);
      expect(g.rows.firstWhere((r) => r.bucket == 'Fri').isTop, isTrue);
      expect(g.rows.firstWhere((r) => r.bucket == 'Mon').isTop, isFalse);
      expect(c.factorsWindow, contains('55 migraine-days over 879 days'));
    });

    test('too little data gives the reason instead of empty tables', () {
      final c = build(
        corr: const CorrelationResult(
            available: false, reason: 'Need at least 5 events for correlation analysis.'),
      );
      expect(c.factorsAvailable, isFalse);
      expect(c.factorsReason, contains('at least 5 events'));
    });

    test('the missing pressure factor is footnoted, not silently dropped', () {
      final c = build();
      expect(c.footnotes.any((f) => f.contains('barometric-pressure factor is not shown')), isTrue);

      final withPressure = build(
        corr: const CorrelationResult(available: true, factors: {
          'Pressure Δ 24h (hPa)': [
            FactorRow(
                bucket: '0 to 5',
                migraineDays: 3,
                totalDays: 40,
                migraineRatePct: 7.5,
                oddsRatio: 1.1)
          ],
        }),
      );
      expect(withPressure.footnotes.any((f) => f.contains('barometric-pressure')), isFalse);
    });

    test('unrenderable characters are substituted and footnoted', () {
      final c = build(
        events: [event(id: 'a', started: DateTime.utc(2026, 1, 1), notes: '頭痛')],
        canRender: (r) => r < 0x250,
      );
      expect(c.events.single.notes, '??');
      expect(c.footnotes.first, contains('could not be drawn'));
      expect(c.footnotes.first, contains('JSON export preserves them'));
    });

    test('event rows format duration, ongoing entries and tri-state aura', () {
      final c = build(events: [
        event(
          id: 'a',
          started: DateTime.utc(2026, 1, 2, 9),
          ended: DateTime.utc(2026, 1, 2, 15),
          severity: 7,
          aura: true,
        ),
        event(id: 'b', started: DateTime.utc(2026, 1, 1, 9)), // ongoing, no severity, aura unknown
      ]);
      // Newest first.
      expect(c.events.first.severity, '7');
      expect(c.events.first.duration, '6.0h');
      expect(c.events.first.aura, 'yes');
      expect(c.events.last.duration, 'ongoing');
      expect(c.events.last.severity, '-');
      expect(c.events.last.aura, '-');
    });

    test('the away-from-home line distinguishes "none" from "some"', () {
      final none = build(
        dash: const DashboardResult(
          summary: Summary(totalEvents: 3),
          awayFromHome: AwayFromHome(
              locatedEvents: 3, awayEvents: 0, thresholdKm: 100, farthestKm: 12),
        ),
      );
      expect(none.awayFromHome, 'All 3 located entries were within 100 km of home.');

      final some = build(
        dash: const DashboardResult(
          summary: Summary(totalEvents: 3),
          awayFromHome: AwayFromHome(
            locatedEvents: 3,
            awayEvents: 2,
            thresholdKm: 100,
            farthestKm: 7854,
            awayPlaces: [LabeledCount('Paris', 2)],
          ),
        ),
      );
      expect(some.awayFromHome, contains('2 of 3 located entries'));
      expect(some.awayFromHome, contains('Paris (2)'));

      expect(build().awayFromHome, isNull, reason: 'no home location, no line');
    });
  });
}
