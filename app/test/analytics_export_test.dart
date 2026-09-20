import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/repositories/megrim_repository.dart';
import 'package:megrim/services/analytics_export.dart';
import 'package:megrim/services/import_service.dart';

/// Issue #16: the JSON export carries an `analytics` block — the app's own computed dashboard and
/// odds-ratio results — so external renderers format numbers instead of re-implementing the math.
/// The block must be (1) exactly what the analytics pipeline returns, (2) ignored on import, and
/// (3) stable against a checked-in reference that renderers can diff themselves against.
void main() {
  late MegrimDatabase db;
  late MegrimRepository repo;

  setUp(() async {
    db = MegrimDatabase.forTesting(NativeDatabase.memory());
    repo = MegrimRepository(db: db);
    final sample = File('test/fixtures/sample-data.json').readAsStringSync();
    await ImportService(db).importJsonString(sample, replace: true);
  });
  tearDown(() => db.close());

  /// The block minus its volatile computation instant / zone, for equality checks.
  Map<String, dynamic> stable(Map<String, dynamic> block) =>
      Map.of(block)..remove('computed_at')..remove('timezone');

  test('export carries an analytics block with the expected shape', () async {
    final doc = jsonDecode(await repo.exportJson()) as Map<String, dynamic>;
    final a = doc['analytics'] as Map<String, dynamic>;
    expect(a.keys, containsAll(['computed_at', 'timezone', 'home_location', 'method', 'dashboard', 'correlations']));
    expect(a['home_location'], {'lat': 39.96, 'lon': -105.05, 'label': 'Boulder, Colorado, United States'});
    final corr = a['correlations'] as Map<String, dynamic>;
    expect(corr['available'], isTrue);
    expect(corr['total_events'], 55);
    expect((corr['factors'] as Map).keys, containsAll(['Day of week', 'Season', 'Month', 'Moon phase', 'Daylight hours']));
    // A fresh DB has no cached pressure baseline and export never fetches, so no pressure factor.
    expect((corr['factors'] as Map).keys, isNot(contains('Pressure Δ 24h (hPa)')));
    expect(corr['top_factors'], isNotEmpty);
    final dash = a['dashboard'] as Map<String, dynamic>;
    expect((dash['summary'] as Map)['total_events'], 55);
    expect(dash['by_day_of_week'], hasLength(7));
    expect(dash.keys, isNot(contains('calendar')));
  });

  test('the block is exactly what the analytics pipeline returns', () async {
    final exported = stable((jsonDecode(await repo.exportJson()) as Map<String, dynamic>)['analytics']);
    final direct = stable(await repo.analyticsForExport());
    expect(jsonEncode(exported), jsonEncode(direct));
    // And the sub-blocks are the plain serialization of the same computations.
    expect(jsonEncode(direct['dashboard']), jsonEncode(dashboardToJson(await repo.dashboard())));
    expect(jsonEncode(direct['correlations']), jsonEncode(correlationsToJson(await repo.correlations())));
  });

  test('the block is ignored on import', () async {
    final json = await repo.exportJson();
    final dst = MegrimDatabase.forTesting(NativeDatabase.memory());
    final result = await ImportService(dst).importJsonString(json, replace: true);
    expect(result.imported, 55);
    // Re-exporting the imported data yields the same analytics (the block was not "restored", it
    // was recomputed from the events — and matches).
    final again = stable((jsonDecode(await MegrimRepository(db: dst).exportJson()) as Map<String, dynamic>)['analytics']);
    expect(jsonEncode(again), jsonEncode(stable(await repo.analyticsForExport())));
    await dst.close();
  });

  // The reference file external renderers diff against. Day bucketing is local-calendar, so the
  // reference is defined under UTC; the Denver CI run skips it. Regenerate deliberately with
  // `MEGRIM_WRITE_GOLDEN=1 TZ=UTC flutter test test/analytics_export_test.dart`.
  final isUtc = DateTime.now().timeZoneOffset == Duration.zero;
  test('matches the checked-in reference (test/fixtures/sample-data.analytics.json)', () async {
    final file = File('test/fixtures/sample-data.analytics.json');
    final actual = stable(await repo.analyticsForExport());
    final pretty = const JsonEncoder.withIndent('  ').convert(actual);
    if (Platform.environment['MEGRIM_WRITE_GOLDEN'] == '1') {
      file.writeAsStringSync('$pretty\n');
      return;
    }
    expect(file.existsSync(), isTrue, reason: 'reference missing — see the comment above');
    expect(jsonEncode(actual), jsonEncode(jsonDecode(file.readAsStringSync())));
  }, skip: isUtc ? false : 'reference is defined under TZ=UTC');
}
