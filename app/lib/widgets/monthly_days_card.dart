import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../analytics/dashboard.dart';

/// "Migraine days per month" (backlog #17): the number neurologists track. Two figures — the
/// rolling last 30 days and the average over the last 3 complete months — over a bar per calendar
/// month. Every month since the first entry is drawn, zero months included; the chart scrolls
/// sideways and opens on the latest [visibleMonths]. Days, not entries (docs/METHODS.md).
class MonthlyDaysCard extends StatelessWidget {
  final DashboardResult dash;

  /// Fixes "this month" for the in-progress marker. Default: now.
  final DateTime? now;

  static const int visibleMonths = 12;

  const MonthlyDaysCard({super.key, required this.dash, this.now});

  @override
  Widget build(BuildContext context) {
    final months = dash.migraineDaysByMonth;
    if (months.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final avg = dash.avgMigraineDaysLast3Months;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Migraine days per month', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _figure(context, '${dash.migraineDaysLast30}', 'Last 30 days')),
                Expanded(
                  child: _figure(
                    context,
                    avg == null ? '—' : '$avg',
                    'Avg/month, last 3 months',
                    tooltip: avg == null ? 'Needs 3 complete months of history' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _MonthChart(months: months, now: now ?? DateTime.now()),
            const SizedBox(height: 4),
            Text(
              'Days with a migraine, not entries. * month in progress.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _figure(BuildContext context, String value, String label, {String? tooltip}) {
    final theme = Theme.of(context);
    final tile = Column(
      children: [
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
    return tooltip == null ? tile : Tooltip(message: tooltip, child: tile);
  }
}

class _MonthChart extends StatelessWidget {
  final List<MonthDays> months;
  final DateTime now;
  const _MonthChart({required this.months, required this.now});

  bool _inProgress(MonthDays m) => m.year == now.year && m.month == now.month;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelColor = theme.textTheme.bodySmall?.color ?? theme.colorScheme.onSurface;
    final barColor = theme.colorScheme.primary;
    final maxDays = months.fold<int>(0, (m, e) => e.days > m ? e.days : m);
    final abbrev = DateFormat('MMM');
    final full = DateFormat('MMM yyyy');

    // One screen-reader sentence for the whole chart, newest first, rather than 12+ bar nodes.
    final spoken = [
      for (final m in months.reversed.take(MonthlyDaysCard.visibleMonths))
        '${full.format(DateTime(m.year, m.month))}${_inProgress(m) ? ' so far' : ''}: '
            '${m.days} ${m.days == 1 ? 'day' : 'days'}',
    ].join('; ');

    return LayoutBuilder(
      builder: (context, box) {
        final slot = box.maxWidth / MonthlyDaysCard.visibleMonths;
        final width =
            slot *
            (months.length < MonthlyDaysCard.visibleMonths
                ? MonthlyDaysCard.visibleMonths
                : months.length);
        final chart = SizedBox(
          width: width,
          height: 170,
          child: BarChart(
            BarChartData(
              maxY: (maxDays == 0 ? 1 : maxDays) * 1.25,
              alignment: BarChartAlignment.spaceAround,
              barTouchData: BarTouchData(
                enabled: false,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => Colors.transparent,
                  tooltipPadding: EdgeInsets.zero,
                  tooltipMargin: 2,
                  getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                    '${rod.toY.round()}',
                    TextStyle(color: labelColor, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (v, meta) {
                      final i = v.toInt();
                      if (i < 0 || i >= months.length) return const SizedBox();
                      final m = months[i];
                      // The year under every January, the first bar and the newest bar, so
                      // the opening window (the latest 12 months) always shows the year.
                      final showYear = m.month == 1 || i == 0 || i == months.length - 1;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${abbrev.format(DateTime(m.year, m.month))}${_inProgress(m) ? '*' : ''}'
                          '${showYear ? '\n${m.year}' : ''}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 9, height: 1.1),
                        ),
                      );
                    },
                  ),
                ),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: [
                for (var i = 0; i < months.length; i++)
                  BarChartGroupData(
                    x: i,
                    // Every bar is labelled, zeros included: a migraine-free month is a result.
                    showingTooltipIndicators: const [0],
                    barRods: [
                      BarChartRodData(
                        toY: months[i].days.toDouble(),
                        width: (slot * 0.55).clamp(6, 18),
                        // The unfinished month is drawn lighter so it doesn't read as a low month.
                        color: _inProgress(months[i]) ? barColor.withValues(alpha: 0.45) : barColor,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
        return Semantics(
          label: 'Migraine days per month, newest first. $spoken',
          // Its own node, so TalkBack reads the chart as one stop instead of merging it into the card.
          container: true,
          excludeSemantics: true,
          // reverse: opens scrolled to the newest month; older months are a swipe to the right.
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: chart,
          ),
        );
      },
    );
  }
}
