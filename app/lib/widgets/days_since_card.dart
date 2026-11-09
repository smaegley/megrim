import 'package:flutter/material.dart';

import '../analytics/dashboard.dart';
import '../l10n/formats.dart';
import '../l10n/l10n.dart';
import 'severity_badge.dart' show StatusColors, onStatusColor;

/// Whole calendar days between two local dates. Computed on UTC copies of the y/m/d fields so a
/// 23- or 25-hour DST day can't shift the count by one (a plain `.difference(...).inDays` on
/// local DateTimes undercounts a gap that crosses a spring-forward transition).
int daysBetweenLocalDates(DateTime a, DateTime b) => DateTime.utc(b.year, b.month, b.day)
    .difference(DateTime.utc(a.year, a.month, a.day))
    .inDays;

/// "Days since last migraine" status graphic, shared by Analytics and the idle Log screen.
///
/// Colour-coded by how the current gap compares to the mean interval μ and its SD σ:
///   green  d < μ−σ  (recently had one)   → yellow μ−σ ≤ d < μ
///   orange μ ≤ d < μ+σ                    → red    d ≥ μ+σ  (statistically "overdue").
/// Flip the comparisons below if the opposite valence is ever wanted.
class DaysSinceCard extends StatelessWidget {
  final Summary summary;
  const DaysSinceCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final last = summary.lastEvent;
    if (last == null) return const SizedBox.shrink();
    final days = daysBetweenLocalDates(last, DateTime.now());

    final l = context.l10n;
    final fmt = Formats.of(context);
    final mu = summary.avgIntervalDays;
    final sigma = summary.intervalStdDevDays;
    Color color = StatusColors.neutral;
    String note = l.daysSinceNoHistory;
    if (mu != null && sigma != null) {
      if (days < mu - sigma) {
        color = StatusColors.good;
        note = l.daysSinceWellWithin(mu.round());
      } else if (days < mu) {
        color = StatusColors.warning;
        note = l.daysSinceApproaching(mu.round());
      } else if (days < mu + sigma) {
        color = StatusColors.serious;
        note = l.daysSincePast(mu.round());
      } else {
        color = StatusColors.critical;
        note = l.daysSinceWellPast(mu.round());
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Text(
                fmt.integer(days),
                style: TextStyle(
                  color: onStatusColor(color),
                  fontWeight: FontWeight.bold,
                  fontSize: days >= 100 ? 20 : 26,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.daysSinceLabel(days),
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(l.daysSinceLast(fmt.dateWeekday(last)),
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 2),
                  Text(note, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
