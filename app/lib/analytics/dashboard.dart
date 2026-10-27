import 'dart:math' show sqrt;
import '../database/database.dart' show EventImpact;
import '../models/attack_details.dart';
import '../models/event_time.dart' show daysCovered, wallClock, wallDate;
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

  /// Schema v4 (backlog #26): false = an attack without headache; null counts as a headache.
  final bool? headachePresent;
  final bool? aura;

  /// Schema v4 (backlog #20): symptoms ticked on this event (descriptive only).
  final List<String> symptoms;

  /// Schema v4 (backlog #22a): one of `EventImpact`'s values, or null.
  final String? impact;

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
    this.headachePresent,
    this.aura,
    this.symptoms = const [],
    this.impact,
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

/// Distinct migraine days in one calendar month (backlog #17).
class MonthDays {
  final int year;
  final int month;
  final int days;

  /// Of [days], those covered only by attacks without headache (backlog #26). A day with both
  /// kinds counts as a headache day.
  final int daysWithoutHeadache;
  const MonthDays(this.year, this.month, this.days, [this.daysWithoutHeadache = 0]);

  /// `yyyy-MM`, the month's key in the export.
  String get key => '$year-${month.toString().padLeft(2, '0')}';
}

/// How much migraines stopped the user (backlog #22a), counted in days like [MonthDays]: each
/// migraine day takes the worst impact recorded on any attack covering it. Days with no impact
/// recorded are in neither count, and [recordedLast30] says how many of the last 30 days' migraine
/// days had one, so a low count can be told apart from a field that is rarely filled in.
class ImpactDays {
  final int reducedLast30;
  final int unableLast30;
  final int recordedLast30;

  /// Means over the last 3 complete calendar months, on the same rule as
  /// [DashboardResult.avgMigraineDaysLast3Months]; null until those months exist.
  final double? avgReducedLast3Months;
  final double? avgUnableLast3Months;

  const ImpactDays({
    required this.reducedLast30,
    required this.unableLast30,
    required this.recordedLast30,
    this.avgReducedLast3Months,
    this.avgUnableLast3Months,
  });
}

/// The attacks without headache (backlog #26), described for the report — what a clinician needs
/// to tell typical aura without headache and vestibular migraine apart from other causes.
class WithoutHeadache {
  final int events;
  final int totalEvents;

  /// Split by [noHeadacheKind]: aura first, then vertigo / dizziness, then the rest.
  final int withAura;
  final int withVertigo;
  final int other;

  /// Symptoms on these attacks only, most-ticked first.
  final List<LabeledCount> symptoms;

  /// Median length of those with an end time, in hours; null when none has one.
  final double? medianDurationHours;

  const WithoutHeadache({
    required this.events,
    required this.totalEvents,
    required this.withAura,
    required this.withVertigo,
    required this.other,
    this.symptoms = const [],
    this.medianDurationHours,
  });

  /// Share of all entries, 0–100, rounded to 1 decimal.
  double get pct => totalEvents == 0 ? 0 : _round1(events / totalEvents * 100);
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

  /// Frequency of symptoms (backlog #20), most-ticked first. Descriptive only, like triggers.
  final List<LabeledCount> symptomFrequency;

  final List<CalendarEntry> calendar;

  /// Null when there is no home location set, or when no entry carries coordinates — the card
  /// simply doesn't render (backlog #13).
  final AwayFromHome? awayFromHome;

  /// Migraine days per calendar month (backlog #17), oldest first: every month from the first
  /// entry's through the current month, zero months included — a migraine-free month is
  /// information. A "migraine day" is a distinct local calendar day covered by at least one
  /// migraine ([daysCovered]): a multi-day migraine counts each day, two on one day count once.
  final List<MonthDays> migraineDaysByMonth;

  /// Migraine days in the rolling 30 days ending today (today and the 29 days before).
  final int migraineDaysLast30;

  /// Mean migraine days per month over the last 3 complete calendar months, the usual clinical
  /// baseline. Null until 3 complete months have passed since the month of the first entry.
  final double? avgMigraineDaysLast3Months;

  /// Of [migraineDaysLast30], the days covered only by attacks without headache (backlog #26).
  final int migraineDaysWithoutHeadacheLast30;

  /// Null until some entry has an impact recorded — the card then doesn't render.
  final ImpactDays? impact;

  /// Null when no entry is marked as being without headache.
  final WithoutHeadache? withoutHeadache;

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
    this.symptomFrequency = const [],
    this.calendar = const [],
    this.awayFromHome,
    this.migraineDaysByMonth = const [],
    this.migraineDaysLast30 = 0,
    this.avgMigraineDaysLast3Months,
    this.migraineDaysWithoutHeadacheLast30 = 0,
    this.impact,
    this.withoutHeadache,
  });

  bool get isEmpty => summary.totalEvents == 0;
}

double _round1(double v) => (v * 10).round() / 10;

/// [homeLat]/[homeLon] are the user's home location, used only for the away-from-home share
/// (backlog #13); omit them and [DashboardResult.awayFromHome] is null. [now] (default: the
/// phone's current time) fixes "today" for the monthly migraine-day figures (backlog #17).
DashboardResult computeDashboard(
  List<EventStat> events, {
  double? homeLat,
  double? homeLon,
  DateTime? now,
}) {
  if (events.isEmpty) {
    return const DashboardResult(summary: Summary(totalEvents: 0));
  }

  final sorted = [...events]..sort((a, b) => a.startedAt.compareTo(b.startedAt));
  final n = sorted.length;
  final first = sorted.first.startedAt.toUtc();
  final last = sorted.last.startedAt.toUtc();
  final yearsTracked = _round1(last.difference(first).inDays / 365.25);

  // Severity rates pain, so it is averaged over headache attacks only (backlog #26). The app
  // clears severity on an attack without headache, but an imported file may still carry one.
  bool rated(EventStat e) => e.severity != null && hasHeadache(e.headachePresent);
  final severities = sorted.where(rated).map((e) => e.severity!);
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
    if (rated(e)) {
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

  final triggerFrequency = _frequency(sorted.map((e) => e.triggers));
  final symptomFrequency = _frequency(sorted.map((e) => e.symptoms));

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

  final monthly = migraineDays(sorted, now ?? DateTime.now());
  final impact = impactDays(sorted, now ?? DateTime.now());

  // Attacks without headache (backlog #26).
  WithoutHeadache? withoutHeadache;
  final noHeadache = sorted.where((e) => !hasHeadache(e.headachePresent)).toList();
  if (noHeadache.isNotEmpty) {
    final kinds = {for (final k in NoHeadacheKind.values) k: 0};
    for (final e in noHeadache) {
      final k = noHeadacheKind(aura: e.aura, symptoms: e.symptoms);
      kinds[k] = kinds[k]! + 1;
    }
    final hours = [
      for (final e in noHeadache)
        if (e.endedAt != null && e.endedAt!.isAfter(e.startedAt))
          e.endedAt!.difference(e.startedAt).inSeconds / 3600.0,
    ]..sort();
    double? median;
    if (hours.isNotEmpty) {
      final mid = hours.length ~/ 2;
      median = _round1(hours.length.isOdd ? hours[mid] : (hours[mid - 1] + hours[mid]) / 2);
    }
    withoutHeadache = WithoutHeadache(
      events: noHeadache.length,
      totalEvents: n,
      withAura: kinds[NoHeadacheKind.aura]!,
      withVertigo: kinds[NoHeadacheKind.vertigo]!,
      other: kinds[NoHeadacheKind.other]!,
      symptoms: _frequency(noHeadache.map((e) => e.symptoms)),
      medianDurationHours: median,
    );
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
    symptomFrequency: symptomFrequency,
    calendar: calendar,
    awayFromHome: away,
    migraineDaysByMonth: monthly.byMonth,
    migraineDaysLast30: monthly.last30,
    avgMigraineDaysLast3Months: monthly.avgLast3Months,
    migraineDaysWithoutHeadacheLast30: monthly.last30WithoutHeadache,
    impact: impact,
    withoutHeadache: withoutHeadache,
  );
}

/// Count each label once per event it appears on, most-tagged first (ties alphabetical).
List<LabeledCount> _frequency(Iterable<List<String>> perEvent) {
  final counts = <String, int>{};
  for (final labels in perEvent) {
    for (final l in labels.toSet()) {
      counts[l] = (counts[l] ?? 0) + 1;
    }
  }
  return counts.entries.map((e) => LabeledCount(e.key, e.value)).toList()
    ..sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      return byCount != 0 ? byCount : a.label.compareTo(b.label);
    });
}

int _monthIndex(DateTime d) => d.year * 12 + d.month - 1;

DateTime _today(DateTime now) {
  final local = now.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// Today and the 29 days before.
bool _inLast30(DateTime d, DateTime today) =>
    !d.isBefore(DateTime(today.year, today.month, today.day - 29)) && !d.isAfter(today);

/// Mean of [perMonth] over the 3 complete months before [today]'s; null unless all three are on
/// or after [firstMonth], otherwise months before tracking began would drag the average down.
double? _avgLast3Months(Map<int, int> perMonth, int firstMonth, DateTime today) {
  final current = _monthIndex(today);
  if (current - 3 < firstMonth) return null;
  return _round1(
      [for (var m = current - 3; m < current; m++) perMonth[m] ?? 0].reduce((a, b) => a + b) / 3);
}

/// The backlog #17 figures. "Today" is [now]'s date on the phone's clock; each migraine's days are
/// read in the zone it was logged in. Days covered only by attacks without headache are counted
/// too, and also reported on their own (backlog #26). Public for tests.
({
  List<MonthDays> byMonth,
  int last30,
  int last30WithoutHeadache,
  double? avgLast3Months,
}) migraineDays(
  Iterable<EventStat> events,
  DateTime now,
) {
  final days = <DateTime>{};
  final headacheDays = <DateTime>{};
  for (final e in events) {
    final covered = daysCovered(e.startedAt, e.startOffsetMin, e.endedAt, e.endOffsetMin);
    days.addAll(covered);
    if (hasHeadache(e.headachePresent)) headacheDays.addAll(covered);
  }
  if (days.isEmpty) {
    return (byMonth: const [], last30: 0, last30WithoutHeadache: 0, avgLast3Months: null);
  }
  final withoutHeadache = days.difference(headacheDays);

  final today = _today(now);
  final perMonth = <int, int>{};
  final perMonthWithout = <int, int>{};
  for (final d in days) {
    perMonth[_monthIndex(d)] = (perMonth[_monthIndex(d)] ?? 0) + 1;
  }
  for (final d in withoutHeadache) {
    perMonthWithout[_monthIndex(d)] = (perMonthWithout[_monthIndex(d)] ?? 0) + 1;
  }
  final first = perMonth.keys.reduce((a, b) => a < b ? a : b);
  // Through the current month, or later if an entry is dated in the future.
  final last = [_monthIndex(today), ...perMonth.keys].reduce((a, b) => a > b ? a : b);
  final byMonth = [
    for (var m = first; m <= last; m++)
      MonthDays(m ~/ 12, m % 12 + 1, perMonth[m] ?? 0, perMonthWithout[m] ?? 0),
  ];

  return (
    byMonth: byMonth,
    last30: days.where((d) => _inLast30(d, today)).length,
    last30WithoutHeadache: withoutHeadache.where((d) => _inLast30(d, today)).length,
    avgLast3Months: _avgLast3Months(perMonth, first, today),
  );
}

/// The backlog #22a figures, on the same day rule and windows as [migraineDays]. Null when no
/// entry has an impact recorded. Public for tests.
ImpactDays? impactDays(Iterable<EventStat> events, DateTime now) {
  if (events.every((e) => e.impact == null)) return null;
  // Worst impact per migraine day, as an index into EventImpact.all; -1 = migraine, none recorded.
  final worst = <DateTime, int>{};
  for (final e in events) {
    final level = e.impact == null ? -1 : EventImpact.all.indexOf(e.impact!);
    for (final d in daysCovered(e.startedAt, e.startOffsetMin, e.endedAt, e.endOffsetMin)) {
      if (level > (worst[d] ?? -1)) {
        worst[d] = level;
      } else {
        worst.putIfAbsent(d, () => -1);
      }
    }
  }
  final today = _today(now);
  final first = worst.keys.map(_monthIndex).reduce((a, b) => a < b ? a : b);
  final reduced = EventImpact.all.indexOf(EventImpact.reduced);
  final unable = EventImpact.all.indexOf(EventImpact.unable);
  final reducedPerMonth = <int, int>{};
  final unablePerMonth = <int, int>{};
  var reduced30 = 0, unable30 = 0, recorded30 = 0;
  for (final MapEntry(key: d, value: level) in worst.entries) {
    final recent = _inLast30(d, today);
    if (recent && level >= 0) recorded30++;
    if (level == reduced) {
      reducedPerMonth[_monthIndex(d)] = (reducedPerMonth[_monthIndex(d)] ?? 0) + 1;
      if (recent) reduced30++;
    } else if (level == unable) {
      unablePerMonth[_monthIndex(d)] = (unablePerMonth[_monthIndex(d)] ?? 0) + 1;
      if (recent) unable30++;
    }
  }
  return ImpactDays(
    reducedLast30: reduced30,
    unableLast30: unable30,
    recordedLast30: recorded30,
    avgReducedLast3Months: _avgLast3Months(reducedPerMonth, first, today),
    avgUnableLast3Months: _avgLast3Months(unablePerMonth, first, today),
  );
}

List<LabeledCount> _labeledFrom(List<String> order, Iterable<String?> values) {
  final counts = <String, int>{};
  for (final v in values) {
    if (v != null) counts[v] = (counts[v] ?? 0) + 1;
  }
  return order.map((k) => LabeledCount(k, counts[k] ?? 0)).toList();
}

