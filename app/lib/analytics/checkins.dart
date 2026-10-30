import '../models/event_time.dart' show daysCovered, wallDate;
import 'correlations.dart' show FactorRow, TopFactor, factorRows;
import 'dashboard.dart' show EventStat;

/// "No migraine today" check-ins (backlog #16): how many days are tracked, and the self-reported
/// factors (sleep, stress, triggers, foods) compared between migraine days and clear days. Pure
/// functions; see docs/METHODS.md, "Check-ins and the tracked-days comparison".
///
/// The rest of Suspected Factors compares migraine days with *every* day, which works for the
/// calendar, moon and pressure factors because they are known for every day. Self-reported factors
/// are only known for days the user recorded, so they are compared over tracked days only: days a
/// migraine started, and days checked in as clear.

/// One check-in: its local calendar date and the optional self-report fields.
class CheckinStat {
  /// Local-flagged midnight of the check-in's own date.
  final DateTime day;
  final List<String> triggers;
  final double? sleepHours;
  final int? stress;
  final List<String> foods;

  const CheckinStat({
    required this.day,
    this.triggers = const [],
    this.sleepHours,
    this.stress,
    this.foods = const [],
  });
}

/// The tracked-days set is offered from this many tracked days, with at least
/// [kMinTrackedMigraineDays] migraine days and [kMinTrackedClearDays] clear days among them.
/// Far above the 5 events Suspected Factors needs: a clear-day baseline from a handful of
/// check-ins says nothing.
const int kMinTrackedDays = 30;
const int kMinTrackedMigraineDays = 5;
const int kMinTrackedClearDays = 5;

/// Fixed buckets for the numeric fields, so they fit a 2×2 table (pinned in docs/METHODS.md).
const String kSleepFactor = 'Sleep the night before';
const String kStressFactor = 'Stress';
const String kTriggerFactor = 'Trigger noted';
const String kFoodFactor = 'Food noted';
const List<String> kSleepBuckets = ['< 6 h', '6–8 h', '> 8 h'];
const List<String> kStressBuckets = ['1–2', '3', '4–5'];

String sleepBucket(double hours) => hours < 6
    ? '< 6 h'
    : hours <= 8
    ? '6–8 h'
    : '> 8 h';

String stressBucket(int level) => level <= 2
    ? '1–2'
    : level == 3
    ? '3'
    : '4–5';

/// "Days tracked": days with a migraine entry or a check-in. A day can't be both; the entry wins.
class TrackedDays {
  /// Of today and the 29 days before.
  final int last30;

  /// Of those, check-in days (clear) and migraine days.
  final int clearLast30;
  final int migraineLast30;

  /// Since the first check-in, through today.
  final int sinceFirstCheckin;
  final int daysSinceFirstCheckin;
  final DateTime firstCheckin;

  const TrackedDays({
    required this.last30,
    required this.clearLast30,
    required this.migraineLast30,
    required this.sinceFirstCheckin,
    required this.daysSinceFirstCheckin,
    required this.firstCheckin,
  });
}

/// Null until there is a check-in: without one, "tracked" would just mean "migraine days".
/// "Today" is [now]'s date on the phone's clock, as for the monthly migraine days.
TrackedDays? trackedDays(Iterable<EventStat> events, Iterable<CheckinStat> checkins, DateTime now) {
  if (checkins.isEmpty) return null;
  final local = now.toLocal();
  final today = DateTime(local.year, local.month, local.day);
  final from30 = DateTime(today.year, today.month, today.day - 29);
  final migraine = <DateTime>{
    for (final e in events)
      ...daysCovered(e.startedAt, e.startOffsetMin, e.endedAt, e.endOffsetMin),
  };
  final clear = {for (final c in checkins) c.day}.difference(migraine);
  final first = checkins.map((c) => c.day).reduce((a, b) => a.isBefore(b) ? a : b);
  bool inRange(DateTime d, DateTime lo) => !d.isBefore(lo) && !d.isAfter(today);
  final clear30 = clear.where((d) => inRange(d, from30)).length;
  final mig30 = migraine.where((d) => inRange(d, from30)).length;
  return TrackedDays(
    last30: clear30 + mig30,
    clearLast30: clear30,
    migraineLast30: mig30,
    sinceFirstCheckin: {...clear, ...migraine}.where((d) => inRange(d, first)).length,
    // Calendar days, first check-in through today, counted by date so DST can't shift it.
    daysSinceFirstCheckin:
        DateTime.utc(
          today.year,
          today.month,
          today.day,
        ).difference(DateTime.utc(first.year, first.month, first.day)).inDays +
        1,
    firstCheckin: first,
  );
}

/// The self-reported factors over tracked days.
class TrackedFactors {
  final bool available;

  /// Why it isn't available yet (the gate, with the user's current counts).
  final String? reason;

  /// Tracked days compared, and how many were migraine (onset) and clear days.
  final int trackedDays;
  final int migraineDays;
  final int clearDays;

  /// Per factor; a factor is left out when too few of its days were recorded.
  final Map<String, List<FactorRow>> factors;
  final List<TopFactor> topFactors;
  final List<String> caveats;

  const TrackedFactors({
    required this.available,
    this.reason,
    this.trackedDays = 0,
    this.migraineDays = 0,
    this.clearDays = 0,
    this.factors = const {},
    this.topFactors = const [],
    this.caveats = const [],
  });
}

/// What was recorded on one tracked day.
class _Day {
  final bool migraine;
  final Set<String> triggers = {};
  final Set<String> foods = {};
  double? sleep;
  int? stress;
  _Day(this.migraine);

  bool get recorded => triggers.isNotEmpty || foods.isNotEmpty || sleep != null || stress != null;
}

/// Compare the self-reported factors on migraine days with clear days, over tracked days from the
/// first check-in on (migraines from before the user started checking in have no clear days to
/// compare with). The outcome is attack onset, as in Suspected Factors: a migraine day is a day a
/// migraine started, and later days of a multi-day migraine are left out, as is a check-in on any
/// day a migraine covers.
///
/// Each factor's table counts only the days that factor could be read on: sleep and stress the
/// days they were recorded, triggers and foods the days on which anything was recorded. A bare
/// check-in is a tracked day but says nothing about triggers; counting it as "no triggers" would
/// make every trigger look like a cause.
TrackedFactors computeTrackedFactors(Iterable<EventStat> events, Iterable<CheckinStat> checkins) {
  final days = <DateTime, _Day>{};
  final covered = <DateTime>{};
  final firstCheckin = checkins.isEmpty
      ? null
      : checkins.map((c) => c.day).reduce((a, b) => a.isBefore(b) ? a : b);

  // Earliest first, so a day's sleep comes from its first attack.
  final sorted = [...events]..sort((a, b) => a.startedAt.compareTo(b.startedAt));
  for (final e in sorted) {
    covered.addAll(daysCovered(e.startedAt, e.startOffsetMin, e.endedAt, e.endOffsetMin));
    final onset = wallDate(e.startedAt, e.startOffsetMin);
    if (firstCheckin == null || onset.isBefore(firstCheckin)) continue;
    final d = days.putIfAbsent(onset, () => _Day(true));
    d.triggers.addAll(e.triggers);
    d.foods.addAll(e.foods);
    d.sleep ??= e.sleepHoursPrior;
    if (e.stressLevel != null && (d.stress == null || e.stressLevel! > d.stress!)) {
      d.stress = e.stressLevel;
    }
  }
  for (final c in checkins) {
    if (covered.contains(c.day)) continue;
    days[c.day] = _Day(false)
      ..triggers.addAll(c.triggers)
      ..foods.addAll(c.foods)
      ..sleep = c.sleepHours
      ..stress = c.stress;
  }

  final migraineDays = days.values.where((d) => d.migraine).length;
  final clearDays = days.length - migraineDays;
  if (days.length < kMinTrackedDays ||
      migraineDays < kMinTrackedMigraineDays ||
      clearDays < kMinTrackedClearDays) {
    return TrackedFactors(
      available: false,
      trackedDays: days.length,
      migraineDays: migraineDays,
      clearDays: clearDays,
      reason:
          'Needs $kMinTrackedDays tracked days, with at least $kMinTrackedMigraineDays '
          'migraine days and $kMinTrackedClearDays clear days. So far: ${days.length} tracked, '
          '$migraineDays migraine, $clearDays clear (since your first check-in).',
    );
  }

  final factors = <String, List<FactorRow>>{};

  /// One factor's table over [included] days; [bucketsOf] gives each day's buckets (none, one,
  /// or, for triggers and foods, several: each is its own in-bucket / not-in-bucket table).
  void add(
    String name,
    List<String> order,
    bool Function(_Day) included,
    Iterable<String> Function(_Day) bucketsOf,
  ) {
    final rows = days.values.where(included).toList();
    final mig = rows.where((d) => d.migraine).length;
    if (mig < kMinTrackedMigraineDays || rows.length - mig < kMinTrackedClearDays) return;
    final base = <String, int>{}, migCounts = <String, int>{};
    for (final d in rows) {
      for (final b in bucketsOf(d)) {
        base[b] = (base[b] ?? 0) + 1;
        if (d.migraine) migCounts[b] = (migCounts[b] ?? 0) + 1;
      }
    }
    final table = factorRows(order, migCounts, base, mig, rows.length);
    if (table.isNotEmpty) factors[name] = table;
  }

  List<String> namesBy(Iterable<String> Function(_Day) of) {
    final counts = <String, int>{};
    for (final d in days.values) {
      for (final n in of(d)) {
        counts[n] = (counts[n] ?? 0) + 1;
      }
    }
    return counts.keys.toList()..sort((a, b) {
      final c = counts[b]!.compareTo(counts[a]!);
      return c != 0 ? c : a.compareTo(b);
    });
  }

  add(kSleepFactor, kSleepBuckets, (d) => d.sleep != null, (d) => [sleepBucket(d.sleep!)]);
  add(kStressFactor, kStressBuckets, (d) => d.stress != null, (d) => [stressBucket(d.stress!)]);
  add(kTriggerFactor, namesBy((d) => d.triggers), (d) => d.recorded, (d) => d.triggers);
  add(kFoodFactor, namesBy((d) => d.foods), (d) => d.recorded, (d) => d.foods);

  // Same filter as Suspected Factors: at least 3 migraine days in the bucket, odds ratio above 1.
  final top = <TopFactor>[
    for (final MapEntry(key: name, value: rows) in factors.entries)
      for (final r in rows)
        if (r.migraineDays >= 3 && r.oddsRatio > 1.0)
          TopFactor(
            factor: name,
            condition: r.bucket,
            oddsRatio: r.oddsRatio,
            migraineDays: r.migraineDays,
            totalDays: r.totalDays,
            migraineRatePct: r.migraineRatePct,
          ),
  ]..sort((a, b) => b.oddsRatio.compareTo(a.oddsRatio));

  return TrackedFactors(
    available: true,
    trackedDays: days.length,
    migraineDays: migraineDays,
    clearDays: clearDays,
    factors: factors,
    topFactors: top.take(8).toList(),
    caveats: [
      'Based on $migraineDays migraine days and $clearDays clear days since your first check-in '
          '— small sample, results are noisy.',
      'Each factor counts only the days it was recorded on.',
      'Recall bias: after a migraine people look harder for a cause than on a good day, so '
          'triggers can be over-recorded on migraine days.',
      'Many factors are tested at once (multiple comparisons) — some apparent associations are '
          'chance.',
      'Association is not causation. Use this to form hypotheses, not conclusions.',
    ],
  );
}
