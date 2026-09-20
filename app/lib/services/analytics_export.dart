import '../analytics/correlations.dart';
import '../analytics/dashboard.dart';
import '../models/home_location.dart';

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
      'by_day_of_week': d.byDayOfWeek.map(_labeled).toList(),
      'by_time_of_day': d.byTimeOfDay.map(_labeled).toList(),
      'by_season': d.bySeason.map(_labeled).toList(),
      'by_moon_phase': d.byMoonPhase.map(_labeled).toList(),
      'by_daylight': d.byDaylight.map(_labeled).toList(),
      'pressure_delta': d.pressureDelta.map(_labeled).toList(),
      'trigger_frequency': d.triggerFrequency.map(_labeled).toList(),
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
      'base_rate_pct': c.baseRatePct,
      'top_factors': [
        for (final t in c.topFactors)
          {
            'factor': t.factor,
            'condition': t.condition,
            'odds_ratio': t.oddsRatio,
            'migraine_days': t.migraineDays,
            'total_days': t.totalDays,
            'migraine_rate_pct': t.migraineRatePct,
          },
      ],
      'factors': {
        for (final entry in c.factors.entries)
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
      },
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
      'timezone': {
        'name': now.timeZoneName,
        'offset_minutes': now.timeZoneOffset.inMinutes,
      },
      'home_location': homeLocation?.toJson(),
      'method': 'docs/METHODS.md',
      'dashboard': dashboardToJson(dashboard),
      'correlations': correlationsToJson(correlations),
    };
