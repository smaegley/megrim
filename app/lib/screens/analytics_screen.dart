import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../analytics/correlations.dart';
import '../analytics/dashboard.dart';
import '../legal.dart';
import '../repositories/megrim_repository.dart';
import '../widgets/severity_badge.dart' show StatusColors, onStatusColor;

/// Categorical series palette (dark steps from the data-viz reference palette, validated for the
/// dark card surface). Colour follows the entity by fixed index — never cycled — so a season/bucket
/// keeps its colour regardless of which buckets are present.
const List<Color> _seriesColors = [
  Color(0xFF3987E5), // blue
  Color(0xFF199E70), // aqua
  Color(0xFFC98500), // yellow
  Color(0xFF008300), // green
  Color(0xFF9085E9), // violet
  Color(0xFFE66767), // red
  Color(0xFFD55181), // magenta
  Color(0xFFD95926), // orange
];

/// Analytics (SPEC §4.5): a "days since last migraine" status card, summary, Top Suspected Factors,
/// Most-tagged triggers, then collapsible per-factor charts (incl. season & time-of-day donuts).
/// Computed locally. Includes the required Open-Meteo attribution footer.
class AnalyticsScreen extends StatefulWidget {
  final MegrimRepository repo;

  /// Bumped by the shell each time this tab is opened, so analytics recompute against the latest
  /// data (the screens are kept alive in an IndexedStack, so initState only runs once).
  final int refreshToken;
  const AnalyticsScreen({super.key, required this.repo, this.refreshToken = 0});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late Future<(DashboardResult, CorrelationResult)> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(AnalyticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _reload();
    }
  }

  void _reload() => setState(() => _future = _load());

  Future<(DashboardResult, CorrelationResult)> _load() async {
    final dash = await widget.repo.dashboard();
    final corr = await widget.repo.correlations();
    return (dash, corr);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<(DashboardResult, CorrelationResult)>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final (dash, corr) = snap.data!;
          if (dash.isEmpty) {
            return const Center(child: Text('Log a few migraines to see analytics.'));
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _daysSinceCard(dash.summary),
                const SizedBox(height: 16),
                _summaryCard(dash.summary),
                const SizedBox(height: 16),
                _CorrelationsCard(corr: corr),
                const SizedBox(height: 16),
                _TriggerCard(dash: dash),
                const SizedBox(height: 16),
                _collapsibleChart(
                  title: 'By day of week',
                  data: dash.byDayOfWeek,
                  child: _barChart(dash.byDayOfWeek),
                ),
                const SizedBox(height: 16),
                _collapsibleChart(
                  title: 'By season',
                  data: dash.bySeason,
                  child: _donut(dash.bySeason),
                ),
                const SizedBox(height: 16),
                _collapsibleChart(
                  title: 'By time of day',
                  data: dash.byTimeOfDay,
                  child: _donut(dash.byTimeOfDay),
                ),
                const SizedBox(height: 16),
                _collapsibleChart(
                  title: 'Pressure change (24h)',
                  data: dash.pressureDelta,
                  child: _barChart(dash.pressureDelta),
                ),
                const SizedBox(height: 16),
                _collapsibleChart(
                  title: 'By moon phase',
                  data: dash.byMoonPhase,
                  child: _barChart(dash.byMoonPhase),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(kWeatherAttribution,
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Days since last migraine (review item #5) ──────────────────────────────
  Widget _daysSinceCard(Summary s) {
    final last = s.lastEvent;
    if (last == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = today.difference(last).inDays;

    // Colour-code by how the current gap compares to the mean interval μ and its SD σ:
    //   green  d < μ−σ  (recently had one)   → yellow μ−σ ≤ d < μ
    //   orange μ ≤ d < μ+σ                    → red    d ≥ μ+σ  (statistically "overdue").
    // Flip the comparisons here if the opposite valence is wanted.
    final mu = s.avgIntervalDays;
    final sigma = s.intervalStdDevDays;
    Color color = StatusColors.neutral;
    String note = 'Not enough history to gauge yet.';
    if (mu != null && sigma != null) {
      if (days < mu - sigma) {
        color = StatusColors.good;
        note = 'Well within your usual gap (avg ${mu.round()} d).';
      } else if (days < mu) {
        color = StatusColors.warning;
        note = 'Approaching your average gap (avg ${mu.round()} d).';
      } else if (days < mu + sigma) {
        color = StatusColors.serious;
        note = 'Past your average gap (avg ${mu.round()} d).';
      } else {
        color = StatusColors.critical;
        note = 'Well past your average gap (avg ${mu.round()} d).';
      }
    }

    final df = DateFormat('EEE d MMM yyyy');
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
                '$days',
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
                  Text(
                      days == 1
                          ? 'day since last migraine'
                          : 'days since last migraine',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text('Last: ${df.format(last)}',
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

  Widget _summaryCard(Summary s) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Summary', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _kv('Total events', '${s.totalEvents}'),
              _kv('Years tracked', '${s.yearsTracked}'),
              if (s.avgSeverity != null) _kv('Avg severity', '${s.avgSeverity}/10'),
              if (s.avgDurationHours != null)
                _kv('Avg duration', '${s.avgDurationHours} h'),
              if (s.avgIntervalDays != null)
                _kv('Avg interval', '${s.avgIntervalDays} days'),
              _kv('Events / year', '${s.eventsPerYear}'),
            ],
          ),
        ),
      );

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(k), Text(v)],
        ),
      );

  // ── Collapsible chart card (review item #8) ────────────────────────────────
  Widget _collapsibleChart({
    required String title,
    required List<LabeledCount> data,
    required Widget child,
  }) {
    final top = _topOf(data);
    final summary =
        top == null ? 'No data yet' : 'Most: ${top.label} (${top.count})';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(summary, style: Theme.of(context).textTheme.bodySmall),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [child],
      ),
    );
  }

  static LabeledCount? _topOf(List<LabeledCount> data) {
    LabeledCount? top;
    for (final d in data) {
      if (d.count > 0 && (top == null || d.count > top.count)) top = d;
    }
    return top;
  }

  // ── Donut (review items #9, #10) ───────────────────────────────────────────
  Widget _donut(List<LabeledCount> data) {
    final present = <int>[]; // indices into data with count > 0
    for (var i = 0; i < data.length; i++) {
      if (data[i].count > 0) present.add(i);
    }
    if (present.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('No data yet')),
      );
    }
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 44,
              sections: [
                for (final i in present)
                  PieChartSectionData(
                    value: data[i].count.toDouble(),
                    color: _seriesColors[i % _seriesColors.length],
                    radius: 46,
                    title: '${data[i].count}',
                    titleStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: onStatusColor(_seriesColors[i % _seriesColors.length]),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Legend — direct labels supply the secondary encoding the palette's CVD floor requires.
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            for (final i in present)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _seriesColors[i % _seriesColors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('${data[i].label} (${data[i].count})',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget _barChart(List<LabeledCount> data) {
    final maxY = data.fold<double>(
        1, (m, e) => e.count > m ? e.count.toDouble() : m);
    return SizedBox(
      height: 160,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= data.length) return const SizedBox();
                  final label = data[i].label;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      label.length > 4 ? label.substring(0, 4) : label,
                      style: const TextStyle(fontSize: 9),
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: [
            for (var i = 0; i < data.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: data[i].count.toDouble(),
                  width: 14,
                  color: _seriesColors.first,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}

/// Top Suspected Factors (review item #6). Collapsed: the single strongest condition per factor
/// category (so you don't see e.g. three separate months). Expanded: the full ranked list plus the
/// correlation caveats.
class _CorrelationsCard extends StatefulWidget {
  final CorrelationResult corr;
  const _CorrelationsCard({required this.corr});

  @override
  State<_CorrelationsCard> createState() => _CorrelationsCardState();
}

class _CorrelationsCardState extends State<_CorrelationsCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final corr = widget.corr;
    if (!corr.available) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(corr.reason ?? 'Not enough data yet.'),
        ),
      );
    }

    // Strongest condition per factor category, keeping first-seen category order.
    final perCategory = <String, TopFactor>{};
    for (final t in corr.topFactors) {
      final cur = perCategory[t.factor];
      if (cur == null || t.oddsRatio > cur.oddsRatio) perCategory[t.factor] = t;
    }
    final collapsed = perCategory.values.toList();
    final hasMore = corr.topFactors.length > collapsed.length;
    final shown = _expanded ? corr.topFactors : collapsed;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Top suspected factors',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Base rate: ${corr.baseRatePct}% of days '
              '(${corr.totalMigraineDays}/${corr.totalDaysInRange})',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (corr.topFactors.isEmpty)
              const Text('No factors stand out above chance yet.')
            else
              for (final t in shown)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text('${t.factor}: ${t.condition}')),
                      Text('OR ${t.oddsRatio}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            if (hasMore)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  child: Text(_expanded
                      ? 'Show top factor per category'
                      : 'Show all ${corr.topFactors.length} factors'),
                ),
              ),
            // Caveats appear on expansion (review item #6).
            if (_expanded) ...[
              const Divider(height: 24),
              for (final c in kCorrelationCaveats)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('• $c',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Most-tagged triggers (review items #7, #11). Collapsed: top 5. Expanded: all tags plus the
/// "this is a frequency count, not a correlation" disclaimer.
class _TriggerCard extends StatefulWidget {
  final DashboardResult dash;
  const _TriggerCard({required this.dash});

  @override
  State<_TriggerCard> createState() => _TriggerCardState();
}

class _TriggerCardState extends State<_TriggerCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final triggers = widget.dash.triggerFrequency;
    if (triggers.isEmpty) return const SizedBox.shrink();
    final total = widget.dash.summary.totalEvents;
    final maxCount = triggers.first.count;
    final hasMore = triggers.length > 5;
    final shown = _expanded ? triggers : triggers.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Most-tagged triggers',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'How often you tagged each trigger, across $total migraines.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            for (final t in shown)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(t.label)),
                        Text('${t.count} · ${(t.count / total * 100).round()}%'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: maxCount == 0 ? 0 : t.count / maxCount,
                        minHeight: 6,
                        backgroundColor:
                            Theme.of(context).colorScheme.surfaceContainerHighest,
                        color: Colors.tealAccent,
                      ),
                    ),
                  ],
                ),
              ),
            if (hasMore)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  child: Text(_expanded
                      ? 'Show top 5'
                      : 'Show all ${triggers.length} triggers'),
                ),
              ),
            if (_expanded) ...[
              const Divider(height: 24),
              Text(
                'This is a frequency count of what you noted — not a correlation. '
                'Self-reported triggers are only recorded on migraine days, so there '
                'is no non-migraine baseline to test them against. Treat these as '
                'personal notes, not evidence of cause.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
