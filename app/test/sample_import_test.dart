import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/repositories/megrim_repository.dart';
import 'package:megrim/services/import_service.dart';

/// Verifies the demo dataset (tools/generate_sample_data.py) imports cleanly and produces
/// populated analytics with real "top suspected factors" — the same path the app's Settings →
/// Import uses.
void main() {
  test('sample dataset imports and drives analytics', () async {
    final raw = File('test/fixtures/sample-data.json').readAsStringSync();
    final db = MegrimDatabase.forTesting(NativeDatabase.memory());
    final repo = MegrimRepository(db: db);

    final result = await ImportService(db).importJsonString(raw, replace: true);
    expect(result.imported, 55);
    expect(result.skipped, 0);

    // Dashboard populates.
    final dash = await repo.dashboard();
    expect(dash.isEmpty, isFalse);
    expect(dash.summary.totalEvents, 55);
    // Friday/Monday clusters are the biggest weekday bars.
    final fri = dash.byDayOfWeek.firstWhere((d) => d.label == 'Fri').count;
    final tue = dash.byDayOfWeek.firstWhere((d) => d.label == 'Tue').count;
    expect(fri, greaterThan(tue));

    // Correlations available with real top factors above chance.
    final corr = await repo.correlations();
    expect(corr.available, isTrue);
    expect(corr.topFactors, isNotEmpty);
    for (final t in corr.topFactors) {
      expect(t.oddsRatio, greaterThan(1.0));
      expect(t.migraineDays, greaterThanOrEqualTo(3));
    }
    // The engineered signals should surface as suspected factors.
    final conditions = corr.topFactors.map((t) => t.condition).toSet();
    expect(
      conditions.intersection({'Mon', 'Fri', 'Full Moon', 'Winter'}),
      isNotEmpty,
      reason: 'expected an engineered factor in the top list; got $conditions',
    );

    await db.close();
  });
}
