import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../analytics/correlations.dart';
import '../analytics/dashboard.dart';
import '../legal.dart';
import '../repositories/megrim_repository.dart';

/// Analytics (SPEC §4.5): summary cards, per-factor charts, and the Top Suspected Factors card
/// with caveats. Computed locally. Includes the required Open-Meteo attribution footer.
class AnalyticsScreen extends StatefulWidget {
  final MegrimRepository repo;
  const AnalyticsScreen({super.key, required this.repo});

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

  Future<(DashboardResult, CorrelationResult)> _load() async {
    final dash = await widget.repo.dashboard();
    final corr = await widget.repo.correlations();
    return (dash, corr);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
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
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _summaryCard(dash.summary),
              const SizedBox(height: 16),
              _barCard('By day of week', dash.byDayOfWeek),
              const SizedBox(height: 16),
              _barCard('By time of day', dash.byTimeOfDay),
              const SizedBox(height: 16),
              _barCard('Pressure change (24h)', dash.pressureDelta),
              const SizedBox(height: 16),
              _barCard('By moon phase', dash.byMoonPhase),
              const SizedBox(height: 16),
              _correlationsCard(corr),
              const SizedBox(height: 24),
              Center(
                child: Text(kWeatherAttribution,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ],
          );
        },
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

  Widget _barCard(String title, List<LabeledCount> data) {
    final maxY = data.fold<double>(
        1, (m, e) => e.count > m ? e.count.toDouble() : m);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
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
                          color: Colors.purpleAccent,
                        ),
                      ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _correlationsCard(CorrelationResult corr) {
    if (!corr.available) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(corr.reason ?? 'Not enough data yet.'),
        ),
      );
    }
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
              for (final t in corr.topFactors)
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
            const Divider(height: 24),
            for (final c in kCorrelationCaveats)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('• $c',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
          ],
        ),
      ),
    );
  }
}
