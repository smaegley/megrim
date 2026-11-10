import 'package:flutter/material.dart';

import '../analytics/dashboard.dart';
import '../analytics/medications.dart';
import '../l10n/data_labels.dart';
import '../l10n/formats.dart';
import '../l10n/l10n.dart';
import '../models/medications.dart';
import 'monthly_days_card.dart';

/// "Acute medication days" (backlog #18): days with medication taken for an attack, in the last
/// 30 days and per class, a bar per month, and the overuse notice when the last 3 complete months
/// each reached a level. Renders nothing until an entry has a medication.
class MedicationDaysCard extends StatelessWidget {
  final DashboardResult dash;

  /// Opens Settings › Medications, offered when some medications have no class.
  final VoidCallback? onSetClasses;

  /// Fixes "this month" for the in-progress marker. Default: now.
  final DateTime? now;

  const MedicationDaysCard({super.key, required this.dash, this.onSetClasses, this.now});

  @override
  Widget build(BuildContext context) {
    final m = dash.medicationDays;
    if (m == null) return const SizedBox.shrink();
    final l = context.l10n;
    final fmt = Formats.of(context);
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall;
    final unclassified = m.unclassifiedNames;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.medCardTitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(l.medCardIntro, style: small),
              const SizedBox(height: 12),
              if (m.notice != null) ...[
                _OveruseNotice(months: m.notice!),
                const SizedBox(height: 12),
              ],
              // The figure, then the breakdown at full width: side by side they don't fit a
              // narrow phone at a large text size.
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    fmt.integer(m.last30),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l.medCardLast30Label, style: small)),
                ],
              ),
              const SizedBox(height: 4),
              if (m.byClassLast30.isEmpty) Text(l.medCardNoneLast30, style: small),
              for (final MapEntry(key: c, value: n) in m.byClassLast30.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(
                    children: [
                      Expanded(child: Text(medClassName(l, c))),
                      Text(
                        l.medCardClassDays(n),
                        style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              MonthBarChart(
                months: [for (final x in m.byMonth) MonthBar(x.year, x.month, x.days)],
                now: now ?? DateTime.now(),
                title: l.medCardChartTitle,
              ),
              const SizedBox(height: 4),
              Text(l.medCardFootnote, style: small),
              if (unclassified.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  l.medCardUnclassified(unclassified.length, unclassified.join(', ')),
                  style: small,
                ),
                if (onSetClasses != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(onPressed: onSetClasses, child: Text(l.medCardSetClasses)),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OveruseNotice extends StatelessWidget {
  final List<MedMonth> months;
  const _OveruseNotice({required this.months});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = Formats.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          // Informational, not an alarm: the secondary container, not the error colours.
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: scheme.onSecondaryContainer),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: scheme.onSecondaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.overuseNoticeTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final m in months)
                for (final r in m.levelsReached)
                  Text(l.overuseNoticeMonth(
                      fmt.monthYearShort(DateTime(m.year, m.month)), levelReason(l, m, r))),
              const SizedBox(height: 8),
              Text(
                '${l.overuseNoticeBody} ${l.medCardNoticePdfNote}',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSecondaryContainer),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "What helped" (backlog #19): for each medication and relief method, how often it helped among
/// the times "helped?" was answered. Descriptive only, like the trigger counts. Renders nothing
/// until something is recorded.
class WhatHelpedCard extends StatelessWidget {
  final DashboardResult dash;
  const WhatHelpedCard({super.key, required this.dash});

  static const int maxRows = 8;

  @override
  Widget build(BuildContext context) {
    final rows = dash.whatHelped;
    if (rows.isEmpty) return const SizedBox.shrink();
    final l = context.l10n;
    final fmt = Formats.of(context);
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall;
    final meds = rows.where((r) => !r.relief).toList();
    final relief = rows.where((r) => r.relief).toList();

    Widget row(HelpedRow r) {
      final pct = r.helpedPct;
      final answered = r.helped + r.notHelped;
      final detail = pct == null
          ? l.helpedNoAnswer(r.tried)
          : r.unknown == 0
          ? l.helpedShare(fmt.percent(pct), answered)
          : l.helpedShareWithUnknown(fmt.percent(pct), answered, r.unknown);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name and detail on separate lines: both can be long, and screens narrow.
            Text(dataLabel(l, r.name)),
            Text(detail, style: small),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (pct ?? 0) / 100,
                minHeight: 6,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                // A frequency share like the trigger bars, not a correlation.
                color: theme.colorScheme.tertiary,
              ),
            ),
          ],
        ),
      );
    }

    Widget section(String title, List<HelpedRow> list) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(title, style: theme.textTheme.titleSmall),
        for (final r in list.take(maxRows)) row(r),
        if (list.length > maxRows)
          Text(l.helpedMore(list.length - maxRows), style: small),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.helpedTitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(l.helpedIntro, style: small),
              if (meds.isNotEmpty) section(l.helpedMedications, meds),
              if (relief.isNotEmpty) section(l.helpedRelief, relief),
              const SizedBox(height: 8),
              Text(l.helpedFootnote, style: small),
            ],
          ),
        ),
      ),
    );
  }
}
