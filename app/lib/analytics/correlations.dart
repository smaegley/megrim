import '../enrichment/astro.dart' show moonPhaseName, sunTimes;
import '../enrichment/calendar_factors.dart' show seasonForMonth;

/// Port of the private app's `correlations.py` (SPEC §6.2) — "Top Suspected Factors".
///
/// For each factor bucket we build a 2×2 contingency table:
///
/// ```
///                  in-bucket   not-in-bucket
///   migraine day       a             b
///   non-migraine       c             d
/// ```
///
/// odds ratio = (a·d)/(b·c) with a Haldane–Anscombe +0.5 correction on every cell.
/// OR > 1 ⇒ migraines are MORE likely when the factor is in that bucket.
///
/// Divergences from the SPEC §6.2 prose, kept to match the reference Python (the golden source):
///  - Study window is first-event → LAST-event date (Python uses the last event, not "today").
///  - "Top factors" filter is migraine_days ≥ 3 AND OR > 1.0 (prose says OR ≥ 1.5).
/// These are noted so a future change can reconcile prose and code deliberately.

const List<String> kDowLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const List<String> kMonthLabels = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' //
];
const List<String> kSeasonOrder = ['Spring', 'Summer', 'Autumn', 'Winter'];
const List<String> kMoonOrder = [
  'New Moon', 'Waxing Crescent', 'First Quarter', 'Waxing Gibbous',
  'Full Moon', 'Waning Gibbous', 'Last Quarter', 'Waning Crescent' //
];
const List<String> kPressureBuckets = [
  '< -10', '-10 to -5', '-5 to 0', '0 to 5', '5 to 10', '> 10' //
];

/// Daylight-length buckets (hours of daylight). Distinct from season: e.g. spring and autumn share
/// daylight lengths, so this isolates photoperiod (the seasonal-affective / SAD hypothesis).
const List<String> kDaylightBuckets = [
  '< 9.5 h', '9.5–11 h', '11–12.5 h', '12.5–14 h', '≥ 14 h' //
];

String daylightBucket(double hours) {
  if (hours < 9.5) return '< 9.5 h';
  if (hours < 11) return '9.5–11 h';
  if (hours < 12.5) return '11–12.5 h';
  if (hours < 14) return '12.5–14 h';
  return '≥ 14 h';
}

/// Minimum events before correlations are offered.
const int kMinEventsForCorrelations = 5;

String pressureBucket(double delta) {
  if (delta < -10) return '< -10';
  if (delta < -5) return '-10 to -5';
  if (delta < 0) return '-5 to 0';
  if (delta < 5) return '0 to 5';
  if (delta < 10) return '5 to 10';
  return '> 10';
}

/// Haldane–Anscombe corrected odds ratio.
double oddsRatio(int a, int b, int c, int d) {
  final a_ = a + 0.5, b_ = b + 0.5, c_ = c + 0.5, d_ = d + 0.5;
  return (a_ * d_) / (b_ * c_);
}

double _round2(double v) => (v * 100).round() / 100;

class FactorRow {
  final String bucket;
  final int migraineDays;
  final int totalDays;
  final double migraineRatePct;
  final double oddsRatio;

  const FactorRow({
    required this.bucket,
    required this.migraineDays,
    required this.totalDays,
    required this.migraineRatePct,
    required this.oddsRatio,
  });
}

class TopFactor {
  final String factor;
  final String condition;
  final double oddsRatio;
  final int migraineDays;
  final int totalDays;
  final double migraineRatePct;

  const TopFactor({
    required this.factor,
    required this.condition,
    required this.oddsRatio,
    required this.migraineDays,
    required this.totalDays,
    required this.migraineRatePct,
  });
}

class CorrelationResult {
  final bool available;
  final String? reason;
  final int totalEvents;
  final int totalMigraineDays;
  final int totalDaysInRange;
  final double baseRatePct;
  final List<TopFactor> topFactors;
  final Map<String, List<FactorRow>> factors;
  final List<String> caveats;

  const CorrelationResult({
    required this.available,
    this.reason,
    this.totalEvents = 0,
    this.totalMigraineDays = 0,
    this.totalDaysInRange = 0,
    this.baseRatePct = 0,
    this.topFactors = const [],
    this.factors = const {},
    this.caveats = const [],
  });
}

/// Build per-bucket rows for one factor from the migraine-day and all-day (baseline) counts.
List<FactorRow> factorRows(
  List<String> buckets,
  Map<String, int> migraineCounts,
  Map<String, int> baselineCounts,
  int totalMigraine,
  int totalDays,
) {
  final rows = <FactorRow>[];
  for (final b in buckets) {
    final inBucketTotal = baselineCounts[b] ?? 0;
    if (inBucketTotal == 0) continue;
    final a = migraineCounts[b] ?? 0; // migraine days in bucket
    final c = inBucketTotal - a; // non-migraine days in bucket
    final bb = totalMigraine - a; // migraine days not in bucket
    final d = (totalDays - totalMigraine) - c; // non-migraine days not in bucket
    final orr = oddsRatio(a, bb, c, d);
    rows.add(FactorRow(
      bucket: b,
      migraineDays: a,
      totalDays: inBucketTotal,
      migraineRatePct: _round2(a / inBucketTotal * 100),
      oddsRatio: _round2(orr),
    ));
  }
  return rows;
}

/// Compute correlations.
///
/// [eventStarts] are the event start instants (any tz; reduced to local calendar dates).
/// [migrainePressureDeltas] are the non-null `pressure_delta_24h` values from enriched migraine
/// events. [pressureBaseline] is the cached all-days delta histogram (§6.2); when null/empty the
/// pressure factor is omitted. [homeLat] selects the hemisphere for season labels.
CorrelationResult computeCorrelations({
  required List<DateTime> eventStarts,
  List<double> migrainePressureDeltas = const [],
  Map<String, int>? pressureBaseline,
  double homeLat = 40.0,
  double homeLon = 0.0,
}) {
  if (eventStarts.length < kMinEventsForCorrelations) {
    return CorrelationResult(
      available: false,
      reason:
          'Need at least $kMinEventsForCorrelations events for correlation analysis.',
    );
  }

  final eventDates = eventStarts.map((t) {
    final l = t.toLocal();
    return DateTime(l.year, l.month, l.day);
  }).toList()
    ..sort();

  final start = eventDates.first;
  final end = eventDates.last;
  final migraineDaySet = eventDates.toSet();
  final totalMigraine = migraineDaySet.length;

  final dowBase = <String, int>{}, dowMig = <String, int>{};
  final seasonBase = <String, int>{}, seasonMig = <String, int>{};
  final monthBase = <String, int>{}, monthMig = <String, int>{};
  final moonBase = <String, int>{}, moonMig = <String, int>{};
  final daylightBase = <String, int>{}, daylightMig = <String, int>{};

  // Step by calendar day via the constructor (always lands on local midnight of the next day).
  // NB: do NOT use `cur.add(Duration(days: 1))` — a fixed 24h drifts off midnight across DST
  // transitions, so days after a spring-forward would fail the midnight-equality match below and
  // their migraines would be dropped from the tallies (a real bug in DST timezones).
  var totalDays = 0;
  for (var cur = start;
      !cur.isAfter(end);
      cur = DateTime(cur.year, cur.month, cur.day + 1)) {
    totalDays++;
    final dow = kDowLabels[cur.weekday - 1];
    final season = seasonForMonth(cur.month, homeLat);
    final month = kMonthLabels[cur.month - 1];
    // Moon phase and daylight computed at (local) noon for stability near midnight boundaries.
    final noon = DateTime.utc(cur.year, cur.month, cur.day, 12);
    final moon = moonPhaseName(noon);
    // Daylight length depends on latitude and date (not longitude), so it is well-defined for every
    // day in range — the same analytic-baseline treatment used for the calendar/moon factors.
    final daylight =
        daylightBucket(sunTimes(noon, homeLat, homeLon).daylightHours);

    dowBase[dow] = (dowBase[dow] ?? 0) + 1;
    seasonBase[season] = (seasonBase[season] ?? 0) + 1;
    monthBase[month] = (monthBase[month] ?? 0) + 1;
    moonBase[moon] = (moonBase[moon] ?? 0) + 1;
    daylightBase[daylight] = (daylightBase[daylight] ?? 0) + 1;

    if (migraineDaySet.contains(cur)) {
      dowMig[dow] = (dowMig[dow] ?? 0) + 1;
      seasonMig[season] = (seasonMig[season] ?? 0) + 1;
      monthMig[month] = (monthMig[month] ?? 0) + 1;
      moonMig[moon] = (moonMig[moon] ?? 0) + 1;
      daylightMig[daylight] = (daylightMig[daylight] ?? 0) + 1;
    }
  }

  final factors = <String, List<FactorRow>>{
    'Day of week':
        factorRows(kDowLabels, dowMig, dowBase, totalMigraine, totalDays),
    'Season':
        factorRows(kSeasonOrder, seasonMig, seasonBase, totalMigraine, totalDays),
    'Month':
        factorRows(kMonthLabels, monthMig, monthBase, totalMigraine, totalDays),
    'Moon phase':
        factorRows(kMoonOrder, moonMig, moonBase, totalMigraine, totalDays),
    'Daylight hours': factorRows(
        kDaylightBuckets, daylightMig, daylightBase, totalMigraine, totalDays),
  };

  if (pressureBaseline != null && pressureBaseline.isNotEmpty) {
    final pressureMig = <String, int>{};
    for (final delta in migrainePressureDeltas) {
      final b = pressureBucket(delta);
      pressureMig[b] = (pressureMig[b] ?? 0) + 1;
    }
    factors['Pressure Δ 24h (hPa)'] = factorRows(
        kPressureBuckets, pressureMig, pressureBaseline, totalMigraine, totalDays);
  }

  final top = <TopFactor>[];
  factors.forEach((name, rows) {
    for (final r in rows) {
      if (r.migraineDays >= 3 && r.oddsRatio > 1.0) {
        top.add(TopFactor(
          factor: name,
          condition: r.bucket,
          oddsRatio: r.oddsRatio,
          migraineDays: r.migraineDays,
          totalDays: r.totalDays,
          migraineRatePct: r.migraineRatePct,
        ));
      }
    }
  });
  top.sort((a, b) => b.oddsRatio.compareTo(a.oddsRatio));

  return CorrelationResult(
    available: true,
    totalEvents: eventStarts.length,
    totalMigraineDays: totalMigraine,
    totalDaysInRange: totalDays,
    baseRatePct: _round2(totalMigraine / totalDays * 100),
    topFactors: top.take(8).toList(),
    factors: factors,
    caveats: [
      'Based on $totalMigraine migraine days over $totalDays days — small sample, results are noisy.',
      'Odds ratios use a +0.5 correction for empty cells; treat values near 1.0 as no signal.',
      'Many factors are tested at once (multiple comparisons) — some apparent associations are chance.',
      'Association is not causation. Use this to form hypotheses, not conclusions.',
    ],
  );
}
