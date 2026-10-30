import '../analytics/checkins.dart';
import '../analytics/correlations.dart';
import '../analytics/dashboard.dart';
import '../analytics/medications.dart';
import '../models/home_location.dart';
import '../models/medications.dart' show isoDay;

/// JSON serialization of the app's computed analytics for the `analytics` block of a
/// `megrim-export` document (issue #16). Pure: no DB, no IO.
///
/// Why this exists: external renderers of an export (e.g. an HTML/PDF report) otherwise have to
/// re-implement the migraine-day rule, the study window, the odds ratios and the moon/daylight
/// math, and every divergence shows up as numbers that don't match the phone. With this block the
/// Dart code that drives the Analytics tab is the single source of truth and a renderer only
/// formats. The block is written by Megrim and ignored on import (like `derived`).

String? _iso(DateTime? t) => t?.toUtc().toIso8601String();

Map<String, dynamic> _labeled(LabeledCount c) => {'label': c.label, 'count': c.count};

/// `dashboard` sub-block: the descriptive counts behind the Analytics tab's charts. The per-event
/// calendar is deliberately omitted — it is the events list, which the export already carries.
Map<String, dynamic> dashboardToJson(DashboardResult d) => {
      'summary': {
        'total_events': d.summary.totalEvents,
        'first_event': _iso(d.summary.firstEvent),
        'last_event': _iso(d.summary.lastEvent),
        'years_tracked': d.summary.yearsTracked,
        'avg_severity': d.summary.avgSeverity,
        'avg_duration_hours': d.summary.avgDurationHours,
        'avg_interval_days': d.summary.avgIntervalDays,
        'interval_std_dev_days': d.summary.intervalStdDevDays,
        'events_per_year': d.summary.eventsPerYear,
      },
      'by_year': [
        for (final y in d.byYear)
          {'year': y.year, 'count': y.count, 'avg_severity': y.avgSeverity},
      ],
      // Backlog #17: distinct migraine days, not events (see docs/METHODS.md).
      'migraine_days_last_30': d.migraineDaysLast30,
      'migraine_days_avg_last_3_months': d.avgMigraineDaysLast3Months,
      'migraine_days_by_month': [
        for (final m in d.migraineDaysByMonth)
          {'month': m.key, 'days': m.days, 'days_without_headache': m.daysWithoutHeadache},
      ],
      // Backlog #26: of the days above, those with only attacks without headache.
      'migraine_days_without_headache_last_30': d.migraineDaysWithoutHeadacheLast30,
      'without_headache': d.withoutHeadache == null
          ? null
          : {
              'events': d.withoutHeadache!.events,
              'pct_of_events': d.withoutHeadache!.pct,
              'with_aura': d.withoutHeadache!.withAura,
              'with_vertigo': d.withoutHeadache!.withVertigo,
              'other': d.withoutHeadache!.other,
              'median_duration_hours': d.withoutHeadache!.medianDurationHours,
              'symptoms': d.withoutHeadache!.symptoms.map(_labeled).toList(),
            },
      // Backlog #22a: days, on the migraine-day rule; a day takes its worst impact.
      'impact': d.impact == null
          ? null
          : {
              'unable_days_last_30': d.impact!.unableLast30,
              'reduced_days_last_30': d.impact!.reducedLast30,
              'recorded_days_last_30': d.impact!.recordedLast30,
              'unable_days_avg_last_3_months': d.impact!.avgUnableLast3Months,
              'reduced_days_avg_last_3_months': d.impact!.avgReducedLast3Months,
            },
      // Backlog #18: distinct days with each class of acute medication (see docs/METHODS.md).
      'medication_days': d.medicationDays == null ? null : _medicationDays(d.medicationDays!),
      // Backlog #19: helped / didn't / unknown per medication and relief method.
      'what_helped': [
        for (final r in d.whatHelped)
          {
            'name': r.name,
            'kind': r.relief ? 'relief' : 'medication',
            'tried': r.tried,
            'helped': r.helped,
            'not_helped': r.notHelped,
            'unknown': r.unknown,
            'helped_pct': r.helpedPct,
          },
      ],
      // Backlog #16: days with an entry or a check-in; null until there is a check-in.
      'days_tracked': d.tracked == null
          ? null
          : {
              'last_30': d.tracked!.last30,
              'clear_last_30': d.tracked!.clearLast30,
              'migraine_last_30': d.tracked!.migraineLast30,
              'first_checkin': isoDay(d.tracked!.firstCheckin),
              'since_first_checkin': d.tracked!.sinceFirstCheckin,
              'days_since_first_checkin': d.tracked!.daysSinceFirstCheckin,
            },
      // Backlog #16: self-reported factors, migraine days vs clear days over tracked days.
      'tracked_factors':
          d.trackedFactors == null ? null : _trackedFactors(d.trackedFactors!),
      'by_day_of_week': d.byDayOfWeek.map(_labeled).toList(),
      'by_time_of_day': d.byTimeOfDay.map(_labeled).toList(),
      'by_season': d.bySeason.map(_labeled).toList(),
      'by_moon_phase': d.byMoonPhase.map(_labeled).toList(),
      'by_daylight': d.byDaylight.map(_labeled).toList(),
      'pressure_delta': d.pressureDelta.map(_labeled).toList(),
      'trigger_frequency': d.triggerFrequency.map(_labeled).toList(),
      'symptom_frequency': d.symptomFrequency.map(_labeled).toList(),
      'away_from_home': d.awayFromHome == null
          ? null
          : {
              'located_events': d.awayFromHome!.locatedEvents,
              'away_events': d.awayFromHome!.awayEvents,
              'away_pct': d.awayFromHome!.awayPct,
              'threshold_km': d.awayFromHome!.thresholdKm,
              'farthest_km': d.awayFromHome!.farthestKm,
              'away_places': d.awayFromHome!.awayPlaces.map(_labeled).toList(),
            },
    };

Map<String, dynamic> _medMonth(MedMonth m) => {
      'month': m.key,
      'days': m.days,
      'by_class': m.byClass,
      'overuse_class_days': m.overuseClassDays,
      'levels_reached': m.levelsReached,
    };

Map<String, dynamic> _medicationDays(MedicationDays m) => {
      'days_last_30': m.last30,
      'by_class_last_30': m.byClassLast30,
      'by_month': m.byMonth.map(_medMonth).toList(),
      // The last 3 complete months when each reached a reference level; null otherwise.
      'overuse_notice_months': m.notice?.map((x) => x.key).toList(),
      'unclassified_names': m.unclassifiedNames,
    };

Map<String, dynamic> _topFactor(TopFactor t) => {
      'factor': t.factor,
      'condition': t.condition,
      'odds_ratio': t.oddsRatio,
      'migraine_days': t.migraineDays,
      'total_days': t.totalDays,
      'migraine_rate_pct': t.migraineRatePct,
    };

Map<String, dynamic> _factors(Map<String, List<FactorRow>> factors) => {
      for (final entry in factors.entries)
        entry.key: [
          for (final r in entry.value)
            {
              'bucket': r.bucket,
              'migraine_days': r.migraineDays,
              'total_days': r.totalDays,
              'migraine_rate_pct': r.migraineRatePct,
              'odds_ratio': r.oddsRatio,
            },
        ],
    };

Map<String, dynamic> _trackedFactors(TrackedFactors t) => {
      'available': t.available,
      'reason': t.reason,
      'tracked_days': t.trackedDays,
      'migraine_days': t.migraineDays,
      'clear_days': t.clearDays,
      'top_factors': t.topFactors.map(_topFactor).toList(),
      'factors': _factors(t.factors),
      'caveats': t.caveats,
    };

/// `correlations` sub-block: the full odds-ratio result, every factor's per-bucket rows plus the
/// gated top list — exactly what the Analytics tab shows, including the pressure factor when the
/// app has a cached pressure baseline (external tools cannot compute that one).
Map<String, dynamic> correlationsToJson(CorrelationResult c) => {
      'available': c.available,
      'reason': c.reason,
      'total_events': c.totalEvents,
      'total_migraine_days': c.totalMigraineDays,
      'total_days_in_range': c.totalDaysInRange,
      'excluded_mid_attack_days': c.excludedMidAttackDays,
      'base_rate_pct': c.baseRatePct,
      'top_factors': c.topFactors.map(_topFactor).toList(),
      'factors': _factors(c.factors),
      'caveats': c.caveats,
    };

/// The whole `analytics` block. [now] is the computation instant; its local zone is recorded
/// because day-of-week, season and migraine-day bucketing are all local-calendar concepts — a
/// renderer in another zone can then say what the numbers are relative to.
Map<String, dynamic> analyticsBlock({
  required DashboardResult dashboard,
  required CorrelationResult correlations,
  required HomeLocation? homeLocation,
  required DateTime now,
}) =>
    {
      'computed_at': now.toUtc().toIso8601String(),
      // Since schema v2 (#17) day buckets come from each event's own stored offset; `timezone` is
      // the zone used only for rows without one (pre-v2 rows, imports without an offset).
      'bucketing': 'event-offset',
      'timezone': {
        'name': now.timeZoneName,
        'offset_minutes': now.timeZoneOffset.inMinutes,
      },
      'home_location': homeLocation?.toJson(),
      'method': 'docs/METHODS.md',
      'dashboard': dashboardToJson(dashboard),
      'correlations': correlationsToJson(correlations),
    };
