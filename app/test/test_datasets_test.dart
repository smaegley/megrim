import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/analytics/correlations.dart' show kDaylightBuckets;
import 'package:megrim/analytics/dashboard.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/repositories/megrim_repository.dart';
import 'package:megrim/services/import_service.dart';

/// Validates the themed test fixtures (tools/generate_test_datasets.py): each one imports cleanly
/// and its engineered bias shows up in both the dashboard distribution and the Top Suspected
/// Factors, so they are trustworthy for hands-on testing.
Future<MegrimRepository> _import(String name) async {
  final raw =
      File('test/fixtures/datasets/$name').readAsStringSync();
  final db = MegrimDatabase.forTesting(NativeDatabase.memory());
  final repo = MegrimRepository(db: db);
  await ImportService(db).importJsonString(raw, replace: true);
  return repo;
}

String _maxLabel(List<LabeledCount> data) =>
    data.reduce((a, b) => b.count > a.count ? b : a).label;

void main() {
  test('01 weekday-monday: Monday dominates and is a suspected factor', () async {
    final repo = await _import('01-weekday-monday.json');
    final dash = await repo.dashboard();
    expect(dash.summary.totalEvents, 30);
    expect(_maxLabel(dash.byDayOfWeek), 'Mon');

    final corr = await repo.correlations();
    expect(corr.available, isTrue);
    final mon = corr.topFactors
        .where((t) => t.factor == 'Day of week' && t.condition == 'Mon');
    expect(mon, isNotEmpty, reason: 'expected a Monday factor; got ${corr.topFactors.map((t) => "${t.factor}:${t.condition}")}');
    expect(mon.first.oddsRatio, greaterThan(1.5));
    await repo.db.close();
  });

  test('02 season-winter: Winter dominates and is a suspected factor', () async {
    final repo = await _import('02-season-winter.json');
    final dash = await repo.dashboard();
    expect(dash.summary.totalEvents, 30);
    expect(_maxLabel(dash.bySeason), 'Winter');

    final corr = await repo.correlations();
    expect(corr.available, isTrue);
    final winter = corr.topFactors
        .where((t) => t.factor == 'Season' && t.condition == 'Winter');
    expect(winter, isNotEmpty);
    expect(winter.first.oddsRatio, greaterThan(1.5));
    await repo.db.close();
  });

  test('03 moon-fullmoon: Full Moon dominates and is a suspected factor', () async {
    final repo = await _import('03-moon-fullmoon.json');
    final dash = await repo.dashboard();
    expect(dash.summary.totalEvents, 28);
    expect(_maxLabel(dash.byMoonPhase), 'Full Moon');

    final corr = await repo.correlations();
    expect(corr.available, isTrue);
    final full = corr.topFactors
        .where((t) => t.factor == 'Moon phase' && t.condition == 'Full Moon');
    expect(full, isNotEmpty);
    expect(full.first.oddsRatio, greaterThan(1.5));
    await repo.db.close();
  });

  test('06 daylight-short: short daylight is a suspected factor, distinct from season', () async {
    final repo = await _import('06-daylight-short.json');
    final dash = await repo.dashboard();
    expect(dash.summary.totalEvents, 30);
    final shortBand = kDaylightBuckets[1]; // '9.5–11 h'
    expect(_maxLabel(dash.byDaylight), shortBand);

    final corr = await repo.correlations();
    expect(corr.available, isTrue);
    final daylight = corr.topFactors
        .where((t) => t.factor == 'Daylight hours' && t.condition == shortBand);
    expect(daylight, isNotEmpty,
        reason: 'expected a short-daylight factor; got '
            '${corr.topFactors.map((t) => "${t.factor}:${t.condition}")}');
    expect(daylight.first.oddsRatio, greaterThan(1.5));

    // The point of this dataset: daylight beats season here (the short-daylight days span autumn
    // and winter), so no single season should out-rank the daylight factor.
    final seasonORs = corr.topFactors
        .where((t) => t.factor == 'Season')
        .map((t) => t.oddsRatio);
    final maxSeason = seasonORs.isEmpty ? 0.0 : seasonORs.reduce((a, b) => a > b ? a : b);
    expect(daylight.first.oddsRatio, greaterThanOrEqualTo(maxSeason));
    await repo.db.close();
  });

  test('04 mixed-no-signal: correlations run but nothing stands out strongly', () async {
    final repo = await _import('04-mixed-no-signal.json');
    final dash = await repo.dashboard();
    expect(dash.summary.totalEvents, 40);

    final corr = await repo.correlations();
    expect(corr.available, isTrue);
    // Evenly spread data should not produce a strong odds ratio for any factor.
    for (final t in corr.topFactors) {
      expect(t.oddsRatio, lessThan(2.5),
          reason: 'unexpected strong factor in "no signal" set: '
              '${t.factor}:${t.condition} OR ${t.oddsRatio}');
    }
    await repo.db.close();
  });

  test('05 sparse-below-threshold: correlations unavailable under 5 events', () async {
    final repo = await _import('05-sparse-below-threshold.json');
    final dash = await repo.dashboard();
    expect(dash.summary.totalEvents, 4);

    final corr = await repo.correlations();
    expect(corr.available, isFalse);
    expect(corr.reason, contains('at least 5'));
    await repo.db.close();
  });
}
