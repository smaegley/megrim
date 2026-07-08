import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../analytics/correlations.dart';
import '../analytics/dashboard.dart';
import '../analytics/pressure_baseline.dart';
import '../legal.dart';
import '../repositories/megrim_repository.dart';
import '../services/connectivity_monitor.dart';
import '../widgets/days_since_card.dart';
import '../widgets/severity_badge.dart' show onStatusColor;

/// x-axis glyphs for the moon-phase chart — icons in place of text labels (review item #6).
const Map<String, String> _moonGlyphs = {
  'New Moon': '🌑',
  'Waxing Crescent': '🌒',
  'First Quarter': '🌓',
  'Waxing Gibbous': '🌔',
  'Full Moon': '🌕',
  'Waning Gibbous': '🌖',
  'Last Quarter': '🌗',
  'Waning Crescent': '🌘',
};

/// Categorical series palette (dark steps from the data-viz reference palette, validated for the
/// dark card surface). Colour follows the entity by fixed index — never cycled — so a season/bucket
/// keeps its colour regardless of which buckets are present. Used for *identity* encodings (donuts).
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

/// Sequential single-hue purple ramp (dim→bright = low→high magnitude), used for *magnitude*
/// encodings: the descriptive count bars and the suspected-factor bars (backlog #1b/#2/#3). Steps
/// are validated for the #1E1E1E dark card surface (ordinal: monotone lightness, single hue, dim
/// end clears the 2:1 surface floor at 2.20:1). Distinct job from [_seriesColors] (identity).
const List<Color> _seqPurple = [
  Color(0xFF5A4796),
  Color(0xFF6D55B3),
  Color(0xFF8168D2),
  Color(0xFF9A86EA),
  Color(0xFFB8A8F6),
];

/// Map a normalised magnitude [t] in [0,1] to a step of the sequential purple ramp. Higher =
/// brighter. NaN (e.g. a max of 0) collapses to the dimmest step.
Color _magnitudeColor(double t) {
  final clamped = (t.isNaN ? 0.0 : t).clamp(0.0, 1.0);
  return _seqPurple[(clamped * (_seqPurple.length - 1)).round()];
}

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
    // The pressure "suspected factor" needs a one-time bulk fetch of daily pressure history at the
    // home location (cached after). Only allow that fetch when online, so the Analytics tab never
    // blocks on the network offline — it uses the cached baseline (or omits pressure) instead.
    final online = ConnectivityMonitor.isOnlineResult(
        await Connectivity().checkConnectivity());
    final corr = await widget.repo.correlations(
      baselineService: PressureBaselineService(db: widget.repo.db),
      allowFetch: online,
    );
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
                DaysSinceCard(summary: dash.summary),
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
                  title: 'By daylight hours',
                  data: dash.byDaylight,
                  child: _barChart(dash.byDaylight),
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
                  child: _barChart(dash.byMoonPhase, axisGlyphs: _moonGlyphs),
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

  // Summary as stat tiles — two rows of three (backlog #1). Each tile is a big glanceable figure
  // over a muted label; null-valued stats show an em dash so the grid stays a fixed 2×3.
  Widget _summaryCard(Summary s) {
    final tiles = <Widget>[
      _statTile('${s.totalEvents}', 'Events'),
      _statTile('${s.yearsTracked}', 'Years tracked'),
      _statTile(s.avgSeverity != null ? '${s.avgSeverity}' : '—', 'Avg severity'),
      _statTile(
          s.avgDurationHours != null ? '${s.avgDurationHours}h' : '—', 'Avg duration'),
      _statTile(
          s.avgIntervalDays != null ? '${s.avgIntervalDays}d' : '—', 'Avg interval'),
      _statTile('${s.eventsPerYear}', 'Per year'),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Summary', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(children: [for (final t in tiles.take(3)) Expanded(child: t)]),
            const SizedBox(height: 8),
            Row(children: [for (final t in tiles.skip(3)) Expanded(child: t)]),
          ],
        ),
      ),
    );
  }

  Widget _statTile(String value, String label) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()]),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color?.withValues(
                        alpha: 0.7,
                      )),
            ),
          ],
        ),
      );

  // ── Collapsible chart card (review items #3, #8) ───────────────────────────
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(summary, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            // A mini sparkline of the distribution gives the collapsed card visual interest.
            _MiniBars(data: data, color: _seqPurple[2]),
          ],
        ),
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
    // Labels (name + count) sit inside each slice — this is the direct labelling the palette's CVD
    // floor requires, so no separate legend is needed (review items #4, #5).
    return SizedBox(
      height: 210,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 36,
          sections: [
            for (final i in present)
              PieChartSectionData(
                value: data[i].count.toDouble(),
                color: _seriesColors[i % _seriesColors.length],
                radius: 68,
                titlePositionPercentageOffset: 0.6,
                title: '${data[i].label}\n${data[i].count}',
                titleStyle: TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  fontWeight: FontWeight.bold,
                  color: onStatusColor(_seriesColors[i % _seriesColors.length]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _barChart(List<LabeledCount> data, {Map<String, String>? axisGlyphs}) {
    final maxCount = data.fold<int>(0, (m, e) => e.count > m ? e.count : m);
    // Headroom above the tallest bar so the count label printed on top doesn't clip.
    final maxY = (maxCount == 0 ? 1 : maxCount) * 1.25;
    final labelColor =
        Theme.of(context).textTheme.bodySmall?.color ?? Colors.white70;
    return SizedBox(
      height: 160,
      child: BarChart(
        BarChartData(
          maxY: maxY.toDouble(),
          // Counts are always shown above each bar (backlog #2) via always-on, chrome-less
          // tooltips; touch stays enabled so a tap still highlights a bar.
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => Colors.transparent,
              tooltipPadding: EdgeInsets.zero,
              tooltipMargin: 2,
              getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                '${rod.toY.round()}',
                TextStyle(
                    color: labelColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
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
                  final glyph = axisGlyphs?[label];
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: glyph != null
                        ? Text(glyph, style: const TextStyle(fontSize: 15))
                        : Text(
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
              BarChartGroupData(
                x: i,
                // Show the count label only over bars that have one (avoids a "0" on the baseline).
                showingTooltipIndicators: data[i].count > 0 ? const [0] : const [],
                barRods: [
                  BarChartRodData(
                    toY: data[i].count.toDouble(),
                    width: 16,
                    // Shade by magnitude relative to the tallest bar (backlog #3).
                    color: _magnitudeColor(
                        maxCount == 0 ? 0 : data[i].count / maxCount),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// A compact sparkline of a distribution, shown on collapsed chart cards for visual interest
/// (review item #3). Bars are proportional to each bucket's count; empty buckets are faint stubs.
class _MiniBars extends StatelessWidget {
  final List<LabeledCount> data;
  final Color color;
  const _MiniBars({required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    final maxV = data.fold<int>(0, (m, e) => e.count > m ? e.count : m);
    if (maxV == 0) return const SizedBox.shrink();
    return SizedBox(
      height: 26,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final d in data) ...[
            Container(
              width: 6,
              height: 2 + 24 * (d.count / maxV),
              decoration: BoxDecoration(
                color: color.withValues(alpha: d.count == 0 ? 0.2 : 0.8),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
              ),
            ),
            const SizedBox(width: 3),
          ],
        ],
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
    // Longest bar = strongest odds ratio among the shown factors; the rest scale against it.
    final maxOr = shown.fold<double>(1, (m, t) => t.oddsRatio > m ? t.oddsRatio : m);

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
              for (final t in shown) _factorBar(context, t, maxOr),
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

  /// One suspected factor rendered as a horizontal bar whose length encodes the odds ratio relative
  /// to the strongest shown factor, shaded by the same magnitude (backlog #1b/#3). The OR value and
  /// factor:condition label are kept as text — the bar is an addition, not a replacement.
  Widget _factorBar(BuildContext context, TopFactor t, double maxOr) {
    final frac = maxOr <= 0 ? 0.0 : (t.oddsRatio / maxOr).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('${t.factor}: ${t.condition}')),
              const SizedBox(width: 8),
              Text('OR ${t.oddsRatio}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 8,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              color: _magnitudeColor(frac),
            ),
          ),
        ],
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
