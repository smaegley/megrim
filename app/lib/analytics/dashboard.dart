import 'dart:math' show sqrt;
import '../models/event_time.dart' show wallClock, wallDate;
import 'geo_distance.dart';

import 'correlations.dart'
    show
        kDaylightBuckets,
        kDowLabels,
        kMoonOrder,
        kPressureBuckets,
        daylightBucket,
        pressureBucket;

/// Port of the private app's dashboard aggregates (SPEC §6.1). Pure functions over the event +
/// derived data. Dates are treated in local time (the app displays local time throughout).

const List<String> kTimeOfDayOrder = ['morning', 'afternoon', 'evening', 'night'];
const List<String> kSeasonDisplayOrder = ['Spring', 'Summer', 'Autumn', 'Winter'];

/// Distance from the home location beyond which an entry counts as "away" (backlog #13). Chosen
/// so that ordinary movement around a home city never registers, but a different city does.
const double kAwayFromHomeThresholdKm = 100.0;

/// One event's fields needed for statistics (event columns + its derived factors).
class EventStat {
  final DateTime startedAt; // UTC; reduced to the event's own calendar date for bucketing (#17)
  final DateTime? endedAt;

  /// UTC offsets (minutes) of the zone the event was logged in; null = phone's current zone.
  final int? startOffsetMin;
  final int? endOffsetMin;
  final int? severity;
  final int? dayOfWeek; // 0=Mon..6=Sun
  final String? season;
  final String? timeOfDayBucket;
  final String? moonPhase;
  final double? pressureDelta24h;
  final double? daylightHours;

  /// Self-reported triggers tagged on this event (descriptive only — not correlated).
  final List<String> triggers;

  /// The event's recorded location, if any (rounded to 2 decimals at capture — SPEC §3.1).
  final double? geoLat;
  final double? geoLon;
  final String? geoLabel;

  const EventStat({
    required this.startedAt,
    this.endedAt,
    this.severity,
    this.dayOfWeek,
    this.season,
    this.timeOfDayBucket,
    this.moonPhase,
    this.pressureDelta24h,
    this.daylightHours,
    this.triggers = const [],
    this.startOffsetMin,
    this.endOffsetMin,
    this.geoLat,
    this.geoLon,
    this.geoLabel,
  });
}

class Summary {
  final int totalEvents;
  final DateTime? firstEvent;
  final DateTime? lastEvent;
  final double yearsTracked;
  final double? avgSeverity;
  final double? avgDurationHours;
  final double? avgIntervalDays;

  /// Sample standard deviation of the between-event intervals (days). Null until there are at
  /// least two intervals (three events). Used to colour-code the "Days since last migraine" card.
  final double? intervalStdDevDays;

  final double eventsPerYear;

  const Summary({
    required this.totalEvents,
    this.firstEvent,
    this.lastEvent,
    this.yearsTracked = 0,
    this.avgSeverity,
    this.avgDurationHours,
    this.avgIntervalDays,
    this.intervalStdDevDays,
    this.eventsPerYear = 0,
  });
}

class YearCount {
  final int year;
  final int count;
  final double? avgSeverity;
  const YearCount(this.year, this.count, this.avgSeverity);
}

class LabeledCount {
  final String label;
  final int count;
  const LabeledCount(this.label, this.count);
}

class CalendarEntry {
  final DateTime date;
  final int? severity;
  const CalendarEntry(this.date, this.severity);
}

/// How many entries were logged away from the home location (backlog #13).
///
/// Descriptive only, exactly like [DashboardResult.triggerFrequency]: it says where migraines were
/// logged, not that travel causes them. It is deliberately NOT a suspected factor — an odds ratio
/// needs the location of **non-migraine** days too, and the app never collects that.
class AwayFromHome {
  /// Entries carrying coordinates. The denominator: entries without a location are in neither
  /// this nor [awayEvents], and the UI says so.
  final int locatedEvents;

  /// Of those, the ones more than [thresholdKm] from home.
  final int awayEvents;
  final double thresholdKm;

  /// Distance from home of the farthest entry (km), or null when nothing is located.
  final double? farthestKm;

  /// The away places by recorded label, most-logged first. Entries whose label is blank are
  /// grouped under their rounded coordinates.
  final List<LabeledCount> awayPlaces;

  const AwayFromHome({
    required this.locatedEvents,
    required this.awayEvents,
    required this.thresholdKm,
    this.farthestKm,
    this.awayPlaces = const [],
  });

  /// Share of located entries logged away from home, 0–100, rounded to 1 decimal.
  double get awayPct =>
      locatedEvents == 0 ? 0 : _round1(awayEvents / locatedEvents * 100);
}

class DashboardResult {
  final Summary summary;
  final List<YearCount> byYear;
  final List<LabeledCount> byDayOfWeek;
  final List<LabeledCount> byTimeOfDay;
  final List<LabeledCount> bySeason;
  final List<LabeledCount> pressureDelta;
  final List<LabeledCount> byMoonPhase;
  final List<LabeledCount> byDaylight;

  /// Frequency of self-reported triggers, most-tagged first. Descriptive only — NOT a correlation
  /// (there is no non-migraine-day baseline for self-reported triggers). See SPEC §6.2.
  final List<LabeledCount> triggerFrequency;

  final List<CalendarEntry> calendar;

  /// Null when there is no home location set, or when no entry carries coordinates — the card
  /// simply doesn't render (backlog #13).
  final AwayFromHome? awayFromHome;

  const DashboardResult({
    required this.summary,
    this.byYear = const [],
    this.byDayOfWeek = const [],
    this.byTimeOfDay = const [],
    this.bySeason = const [],
    this.pressureDelta = const [],
    this.byMoonPhase = const [],
    this.byDaylight = const [],
    this.triggerFrequency = const [],
    this.calendar = const [],
    this.awayFromHome,
  });

  bool get isEmpty => summary.totalEvents == 0;
}

double _round1(double v) => (v * 10).round() / 10;

/// [homeLat]/[homeLon] are the user's home location, used only for the away-from-home share
/// (backlog #13); omit them and [DashboardResult.awayFromHome] is null.
DashboardResult computeDashboard(
  List<EventStat> events, {
  double? homeLat,
  double? homeLon,
}) {
  if (events.isEmpty) {
    return const DashboardResult(summary: Summary(totalEvents: 0));
  }

  final sorted = [...events]..sort((a, b) => a.startedAt.compareTo(b.startedAt));
  final n = sorted.length;
  final first = sorted.first.startedAt.toUtc();
  final last = sorted.last.startedAt.toUtc();
  final yearsTracked = _round1(last.difference(first).inDays / 365.25);

  final severities = sorted.where((e) => e.severity != null).map((e) => e.severity!);
  final avgSev = severities.isEmpty
      ? null
      : _round1(severities.reduce((a, b) => a + b) / severities.length);

  final durations = <double>[];
  for (final e in sorted) {
    if (e.endedAt != null && e.endedAt!.isAfter(e.startedAt)) {
      durations.add(e.endedAt!.difference(e.startedAt).inSeconds / 3600.0);
    }
  }
  final avgDur = durations.isEmpty
      ? null
      : _round1(durations.reduce((a, b) => a + b) / durations.length);

  final intervals = <int>[];
  for (var i = 1; i < n; i++) {
    intervals.add(sorted[i].startedAt.difference(sorted[i - 1].startedAt).inDays);
  }
  final avgIntervalRaw = intervals.isEmpty
      ? null
      : intervals.reduce((a, b) => a + b) / intervals.length;
  final avgInterval = avgIntervalRaw == null ? null : _round1(avgIntervalRaw);
  double? intervalStd;
  if (intervals.length >= 2) {
    final variance = intervals
            .map((x) => (x - avgIntervalRaw!) * (x - avgIntervalRaw))
            .reduce((a, b) => a + b) /
        (intervals.length - 1);
    intervalStd = _round1(sqrt(variance));
  }

  final summary = Summary(
    totalEvents: n,
    firstEvent: wallDate(sorted.first.startedAt, sorted.first.startOffsetMin),
    lastEvent: wallDate(sorted.last.startedAt, sorted.last.startOffsetMin),
    yearsTracked: yearsTracked,
    avgSeverity: avgSev,
    avgDurationHours: avgDur,
    avgIntervalDays: avgInterval,
    intervalStdDevDays: intervalStd,
    eventsPerYear: yearsTracked > 0 ? _round1(n / yearsTracked) : n.toDouble(),
  );

  // By year (with avg severity).
  final yearCounts = <int, int>{};
  final yearSevSum = <int, int>{};
  final yearSevN = <int, int>{};
  for (final e in sorted) {
    final y = wallClock(e.startedAt, e.startOffsetMin).year;
    yearCounts[y] = (yearCounts[y] ?? 0) + 1;
    if (e.severity != null) {
      yearSevSum[y] = (yearSevSum[y] ?? 0) + e.severity!;
      yearSevN[y] = (yearSevN[y] ?? 0) + 1;
    }
  }
  final byYear = (yearCounts.keys.toList()..sort())
      .map((y) => YearCount(
            y,
            yearCounts[y]!,
            yearSevN[y] != null ? _round1(yearSevSum[y]! / yearSevN[y]!) : null,
          ))
      .toList();

  // By day of week (from derived day_of_week).
  final dowCounts = <int, int>{};
  for (final e in sorted) {
    if (e.dayOfWeek != null) {
      dowCounts[e.dayOfWeek!] = (dowCounts[e.dayOfWeek!] ?? 0) + 1;
    }
  }
  final byDow = List.generate(
      7, (i) => LabeledCount(kDowLabels[i], dowCounts[i] ?? 0));

  final byTod = _labeledFrom(
      kTimeOfDayOrder, sorted.map((e) => e.timeOfDayBucket));
  final bySeason = _labeledFrom(
      kSeasonDisplayOrder, sorted.map((e) => e.season));
  final byMoon = _labeledFrom(kMoonOrder, sorted.map((e) => e.moonPhase));

  // Pressure delta buckets (from derived pressure_delta_24h).
  final pressureCounts = <String, int>{};
  for (final e in sorted) {
    if (e.pressureDelta24h != null) {
      final b = pressureBucket(e.pressureDelta24h!);
      pressureCounts[b] = (pressureCounts[b] ?? 0) + 1;
    }
  }
  final pressureDelta = kPressureBuckets
      .map((b) => LabeledCount(b, pressureCounts[b] ?? 0))
      .toList();

  // Daylight-length buckets (from derived daylight_hours) — photoperiod, distinct from season.
  final daylightCounts = <String, int>{};
  for (final e in sorted) {
    if (e.daylightHours != null) {
      final b = daylightBucket(e.daylightHours!);
      daylightCounts[b] = (daylightCounts[b] ?? 0) + 1;
    }
  }
  final byDaylight = kDaylightBuckets
      .map((b) => LabeledCount(b, daylightCounts[b] ?? 0))
      .toList();

  // Trigger frequency: count each trigger once per event it appears on, most-tagged first.
  final triggerCounts = <String, int>{};
  for (final e in sorted) {
    for (final t in e.triggers.toSet()) {
      triggerCounts[t] = (triggerCounts[t] ?? 0) + 1;
    }
  }
  final triggerFrequency = triggerCounts.entries
      .map((e) => LabeledCount(e.key, e.value))
      .toList()
    ..sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      return byCount != 0 ? byCount : a.label.compareTo(b.label);
    });

  final calendar = sorted
      .map((e) => CalendarEntry(wallDate(e.startedAt, e.startOffsetMin), e.severity))
      .toList();

  // Away from home (backlog #13) — descriptive only; see [AwayFromHome].
  AwayFromHome? away;
  if (homeLat != null && homeLon != null) {
    final located =
        sorted.where((e) => e.geoLat != null && e.geoLon != null).toList();
    if (located.isNotEmpty) {
      final placeCounts = <String, int>{};
      var awayCount = 0;
      double? farthest;
      for (final e in located) {
        final d = distanceKm(homeLat, homeLon, e.geoLat!, e.geoLon!);
        if (farthest == null || d > farthest) farthest = d;
        if (d <= kAwayFromHomeThresholdKm) continue;
        awayCount++;
        final label = e.geoLabel?.trim() ?? '';
        final key = label.isNotEmpty
            ? label
            : '${e.geoLat!.toStringAsFixed(2)}, ${e.geoLon!.toStringAsFixed(2)}';
        placeCounts[key] = (placeCounts[key] ?? 0) + 1;
      }
      final places = placeCounts.entries
          .map((e) => LabeledCount(e.key, e.value))
          .toList()
        ..sort((a, b) {
          final byCount = b.count.compareTo(a.count);
          return byCount != 0 ? byCount : a.label.compareTo(b.label);
        });
      away = AwayFromHome(
        locatedEvents: located.length,
        awayEvents: awayCount,
        thresholdKm: kAwayFromHomeThresholdKm,
        farthestKm: farthest == null ? null : _round1(farthest),
        awayPlaces: places,
      );
    }
  }

  return DashboardResult(
    summary: summary,
    byYear: byYear,
    byDayOfWeek: byDow,
    byTimeOfDay: byTod,
    bySeason: bySeason,
    pressureDelta: pressureDelta,
    byMoonPhase: byMoon,
    byDaylight: byDaylight,
    triggerFrequency: triggerFrequency,
    calendar: calendar,
    awayFromHome: away,
  );
}

List<LabeledCount> _labeledFrom(List<String> order, Iterable<String?> values) {
  final counts = <String, int>{};
  for (final v in values) {
    if (v != null) counts[v] = (counts[v] ?? 0) + 1;
  }
  return order.map((k) => LabeledCount(k, counts[k] ?? 0)).toList();
}

