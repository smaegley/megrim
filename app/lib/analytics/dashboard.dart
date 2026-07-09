import 'dart:math' show sqrt;

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

/// One event's fields needed for statistics (event columns + its derived factors).
class EventStat {
  final DateTime startedAt; // UTC; reduced to local for date bucketing
  final DateTime? endedAt;
  final int? severity;
  final int? dayOfWeek; // 0=Mon..6=Sun
  final String? season;
  final String? timeOfDayBucket;
  final String? moonPhase;
  final double? pressureDelta24h;
  final double? daylightHours;

  /// Self-reported triggers tagged on this event (descriptive only — not correlated).
  final List<String> triggers;

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
  });

  bool get isEmpty => summary.totalEvents == 0;
}

double _round1(double v) => (v * 10).round() / 10;

DashboardResult computeDashboard(List<EventStat> events) {
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
    firstEvent: _localDate(first),
    lastEvent: _localDate(last),
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
    final y = e.startedAt.toLocal().year;
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
      .map((e) => CalendarEntry(_localDate(e.startedAt), e.severity))
      .toList();

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
  );
}

List<LabeledCount> _labeledFrom(List<String> order, Iterable<String?> values) {
  final counts = <String, int>{};
  for (final v in values) {
    if (v != null) counts[v] = (counts[v] ?? 0) + 1;
  }
  return order.map((k) => LabeledCount(k, counts[k] ?? 0)).toList();
}

DateTime _localDate(DateTime utc) {
  final l = utc.toLocal();
  return DateTime(l.year, l.month, l.day);
}
