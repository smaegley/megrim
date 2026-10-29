import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../analytics/dashboard.dart';
import '../models/medications.dart' show parseIsoDay;

/// "Migraine days per month" (backlog #17): the number neurologists track. Two figures — the
/// rolling last 30 days and the average over the last 3 complete months — over a bar per calendar
/// month. Every month since the first entry is drawn, zero months included; the chart scrolls
/// sideways and opens on the latest [visibleMonths]. Days, not entries (docs/METHODS.md).
///
/// Attacks without headache (backlog #26) are migraine days too: they are counted, said so under
/// the last-30-days figure, and drawn as the lighter lower part of each month's bar.
///
/// Preventive medications (backlog #19) are marked above the month they started (▲) and stopped
/// (▼), so a change in the bars can be read against a change in treatment.
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
    final without = dash.migraineDaysWithoutHeadacheLast30;
    final anyWithout = months.any((m) => m.daysWithoutHeadache > 0);
    final f = DateFormat('MMM yyyy');
    final starts = <int>{}, stops = <int>{};
    final notes = <String>[];
    int? indexOf(DateTime? d) {
      if (d == null) return null;
      final i = months.indexWhere((m) => m.year == d.year && m.month == d.month);
      return i < 0 ? null : i;
    }

    for (final p in dash.preventives) {
      final start = parseIsoDay(p.startedOn);
      final stop = parseIsoDay(p.stoppedOn);
      final si = indexOf(start), ei = indexOf(stop);
      if (si != null) starts.add(si);
      if (ei != null) stops.add(ei);
      if (start == null) continue;
      notes.add(stop == null
          ? '${p.name} from ${f.format(start)}'
          : '${p.name} ${f.format(start)} – ${f.format(stop)}');
    }
    final markers = {
      for (final i in {...starts, ...stops})
        i: '${starts.contains(i) ? '▲' : ''}${stops.contains(i) ? '▼' : ''}',
    };
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
                Expanded(
                  child: _figure(
                    context,
                    '${dash.migraineDaysLast30}',
                    without == 0 ? 'Last 30 days' : 'Last 30 days\nincluding $without without headache',
                  ),
                ),
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
            MonthBarChart(
              months: [
                for (final m in months)
                  MonthBar(m.year, m.month, m.days, lower: m.daysWithoutHeadache),
              ],
              now: now ?? DateTime.now(),
              title: 'Migraine days per month',
              describeLower: (n) => '$n without headache',
              markers: markers,
            ),
            const SizedBox(height: 4),
            Text(
              'Days with a migraine, not entries. * month in progress.'
              '${anyWithout ? ' Lower part of a bar: days with only attacks without headache.' : ''}',
              style: theme.textTheme.bodySmall,
            ),
            if (notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Preventives (▲ started, ▼ stopped): ${notes.join('; ')}.',
                  style: theme.textTheme.bodySmall,
                ),
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

/// One month's bar: [value] in all, of which [lower] is drawn as a lighter base.
class MonthBar {
  final int year;
  final int month;
  final int value;
  final int lower;
  const MonthBar(this.year, this.month, this.value, {this.lower = 0});
}

/// A bar per calendar month, every bar labelled, scrolling sideways and opening on the latest
/// [MonthlyDaysCard.visibleMonths]. Shared by migraine days (backlog #17) and medication days
/// (#18). [markers] puts a short glyph above a month's bar, by index into [months].
class MonthBarChart extends StatelessWidget {
  final List<MonthBar> months;
  final DateTime now;

  /// Read first by screen readers, before the months.
  final String title;

  /// How a bar's [MonthBar.lower] part is spoken, e.g. "2 without headache".
  final String Function(int)? describeLower;
  final Map<int, String> markers;

  const MonthBarChart({
    super.key,
    required this.months,
    required this.now,
    required this.title,
    this.describeLower,
    this.markers = const {},
  });

  bool _inProgress(MonthBar m) => m.year == now.year && m.month == now.month;

  Color _shade(Color c, MonthBar m) => _inProgress(m) ? c.withValues(alpha: 0.45) : c;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelColor = theme.textTheme.bodySmall?.color ?? theme.colorScheme.onSurface;
    final barColor = theme.colorScheme.primary;
    final withoutColor = theme.colorScheme.tertiary;
    final maxDays = months.fold<int>(0, (m, e) => e.value > m ? e.value : m);
    final abbrev = DateFormat('MMM');
    final full = DateFormat('MMM yyyy');

    // One screen-reader sentence for the whole chart, newest first, rather than 12+ bar nodes.
    final spoken = [
      for (final m in months.reversed.take(MonthlyDaysCard.visibleMonths))
        '${full.format(DateTime(m.year, m.month))}${_inProgress(m) ? ' so far' : ''}: '
            '${m.value} ${m.value == 1 ? 'day' : 'days'}'
            '${m.lower == 0 || describeLower == null ? '' : ', ${describeLower!(m.lower)}'}',
    ].join('; ');
    final markerColor = theme.colorScheme.secondary;

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
                topTitles: markers.isEmpty
                    ? const AxisTitles(sideTitles: SideTitles(showTitles: false))
                    : AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 14,
                          getTitlesWidget: (v, meta) => Text(
                            markers[v.toInt()] ?? '',
                            style: TextStyle(fontSize: 10, color: markerColor, height: 1),
                          ),
                        ),
                      ),
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
                        toY: months[i].value.toDouble(),
                        width: (slot * 0.55).clamp(6, 18),
                        // The unfinished month is drawn lighter so it doesn't read as a low month.
                        color: _shade(barColor, months[i]),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        // The lower part at the bottom (headache-free days, #26), the rest on top.
                        rodStackItems: months[i].lower == 0
                            ? const []
                            : [
                                BarChartRodStackItem(0, months[i].lower.toDouble(),
                                    _shade(withoutColor, months[i])),
                                BarChartRodStackItem(months[i].lower.toDouble(),
                                    months[i].value.toDouble(), _shade(barColor, months[i])),
                              ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
        return Semantics(
          label: '$title, newest first. $spoken'
              '${markers.isEmpty ? '' : '. Treatment changes are marked.'}',
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
