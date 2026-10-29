import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../analytics/dashboard.dart';
import '../analytics/medications.dart';
import '../models/medications.dart';
import 'monthly_days_card.dart';

/// Short label for a class key, [kUnclassified] included.
String medClassName(String key) =>
    key == kUnclassified ? 'No class set' : kMedClassLabels[key] ?? key;

/// One reason a month reached a reference level, with its count and the level:
/// "Triptan on 11 days (level 10)".
String levelReason(MedMonth m, String reason) => reason == kMixedClasses
    ? 'A mix of classes on ${m.overuseClassDays} days in total '
          '(level $kMixedOveruseDaysPerMonth)'
    : '${kMedClassLabels[reason]} on ${m.byClass[reason]} days '
          '(level ${kOveruseDaysPerMonth[reason]})';

/// The overuse notice (backlog #18), as both the card and the report word it. States the counts
/// and the reference level and suggests a clinician; it never says the user has
/// medication-overuse headache and never tells them to stop or change a medication.
const String kOveruseNoticeTitle = 'Medication days at a reference level';

const String kOveruseNoticeBody =
    'In each of the last 3 complete months, your days with acute medication reached a level that '
    'headache guidelines (ICHD-3) use when looking at medication-overuse headache, where frequent '
    'use of acute medication can make headaches more frequent. This is a count of what you '
    'logged, not a diagnosis. Don\'t change how you take a medication because of it; it may be '
    'worth discussing with your doctor. The PDF report includes these counts.';

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
              Text('Acute medication days', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Days on which you took medication for an attack. Two doses on one day '
                'count once.',
                style: small,
              ),
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
                    '${m.last30}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text('days in the last 30 days', style: small)),
                ],
              ),
              const SizedBox(height: 4),
              if (m.byClassLast30.isEmpty) Text('None in the last 30 days.', style: small),
              for (final MapEntry(key: c, value: n) in m.byClassLast30.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(
                    children: [
                      Expanded(child: Text(medClassName(c))),
                      Text(
                        '$n ${n == 1 ? 'day' : 'days'}',
                        style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              MonthBarChart(
                months: [for (final x in m.byMonth) MonthBar(x.year, x.month, x.days)],
                now: now ?? DateTime.now(),
                title: 'Acute medication days per month',
              ),
              const SizedBox(height: 4),
              Text(
                '* month in progress. A day with two classes counts once in the bar.',
                style: small,
              ),
              if (unclassified.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${unclassified.length == 1 ? '1 medication has' : '${unclassified.length} '
                            'medications have'} no class (${unclassified.join(', ')}), so '
                  '${unclassified.length == 1 ? 'it isn\'t' : 'they aren\'t'} checked against '
                  'the reference levels.',
                  style: small,
                ),
                if (onSetClasses != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(onPressed: onSetClasses, child: const Text('Set classes')),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final f = DateFormat('MMM yyyy');
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
                      kOveruseNoticeTitle,
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
                  Text('${f.format(DateTime(m.year, m.month))}: ${levelReason(m, r)}'),
              const SizedBox(height: 8),
              Text(
                kOveruseNoticeBody,
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
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall;
    final meds = rows.where((r) => !r.relief).toList();
    final relief = rows.where((r) => r.relief).toList();

    Widget row(HelpedRow r) {
      final pct = r.helpedPct;
      final answered = r.helped + r.notHelped;
      final detail = pct == null
          ? 'tried ${r.tried}×, no answer recorded'
          : 'helped $pct% ($answered answered${r.unknown == 0 ? '' : ', ${r.unknown} unknown'})';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name and detail on separate lines: both can be long, and screens narrow.
            Text(r.name),
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
          Text('and ${list.length - maxRows} more (in the export).', style: small),
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
              Text('What helped', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'How often each medication or relief method helped, among the times you '
                'answered "Helped?". Unknown answers are left out of the share.',
                style: small,
              ),
              if (meds.isNotEmpty) section('Medications', meds),
              if (relief.isNotEmpty) section('Relief tried', relief),
              const SizedBox(height: 8),
              Text(
                'What you noted after each attack, not a comparison of treatments: how well '
                'something works depends on when and how it was taken.',
                style: small,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
