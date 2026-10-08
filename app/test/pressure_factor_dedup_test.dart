import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:megrim/analytics/pressure_baseline.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/repositories/megrim_repository.dart';

MegrimDatabase freshDb() => MegrimDatabase.forTesting(NativeDatabase.memory());

Future<void> _insertEvent(
    MegrimDatabase db, String id, DateTime startedAtUtc, double? delta) async {
  await db.into(db.migraineEvents).insert(MigraineEventsCompanion.insert(
        id: id,
        startedAt: startedAtUtc,
        createdAt: startedAtUtc,
        updatedAt: startedAtUtc,
      ));
  await db.into(db.derivedFactors).insert(DerivedFactorsCompanion(
        eventId: Value(id),
        pressureDelta24h: Value(delta),
        enrichedAt: Value(delta != null ? startedAtUtc : null),
      ));
}

/// The pressure factor reads BOTH sides from the cached daily series (2026-10-08): each migraine
/// day's bucket is that day's daily-mean change, the same measure as every other day. So a day
/// counts once however many migraines started on it, and the events' own hourly onset readings
/// (pressureDelta24h) no longer feed the factor — they used to, and their wider swings piled
/// migraine days into the extreme buckets.
void main() {
  test('pressure factor: one bucket per migraine day, from the daily series', () async {
    final db = freshDb();
    await db.setSetting('home_location',
        jsonEncode({'lat': 40.0, 'lon': -105.0, 'label': 'Home'}));

    // Two migraines on 1 June whose own hourly readings fall in different, extreme buckets. They
    // must count once, in 1 June's daily bucket ('0 to 5'), not in either hourly bucket.
    await _insertEvent(db, 'd1a', DateTime.utc(2024, 6, 1, 12), -12); // hourly: '< -10'
    await _insertEvent(db, 'd1b', DateTime.utc(2024, 6, 1, 18), 12); // hourly: '> 10'
    await _insertEvent(db, 'd2', DateTime.utc(2024, 6, 2, 12), null);
    await _insertEvent(db, 'd3', DateTime.utc(2024, 6, 3, 12), 2);
    await _insertEvent(db, 'd4', DateTime.utc(2024, 6, 4, 12), -3);
    await _insertEvent(db, 'd5', DateTime.utc(2024, 6, 5, 12), 12);

    // A current per-day cache for exactly repo.correlations()'s window, so no network call.
    final tag =
        pressureBaselineTag(DateTime(2024, 6, 1), DateTime(2024, 6, 5), 40.0, -105.0);
    const days = {
      '2024-06-01': '0 to 5',
      '2024-06-02': '-5 to 0',
      '2024-06-03': '0 to 5',
      '2024-06-04': '-5 to 0',
      // 5 June: no pressure value — leaves the pressure table on both sides.
    };
    await db.setSetting(
        'pressure_baseline',
        jsonEncode(const PressureBaseline('t', {'0 to 5': 2, '-5 to 0': 2}, dayBuckets: days)
            .toJson()
          ..['tag'] = tag));

    final baselineService = PressureBaselineService(
      db: db,
      httpClient: MockClient((req) async =>
          throw StateError('network should not be hit: the cache already matches')),
    );
    final repo = MegrimRepository(db: db);
    final corr = await repo.correlations(baselineService: baselineService);

    final rows = {for (final r in corr.factors['Pressure Δ 24h (hPa)']!) r.bucket: r};
    expect(rows.keys.toSet(), {'0 to 5', '-5 to 0'},
        reason: 'no extreme bucket: the hourly onset readings are not used');
    expect(rows['0 to 5']!.migraineDays, 2, reason: '1 June (once) and 3 June');
    expect(rows['-5 to 0']!.migraineDays, 2, reason: '2 and 4 June');
    expect(rows['0 to 5']!.totalDays + rows['-5 to 0']!.totalDays, 4,
        reason: '5 June has no value and is out of the pressure table');
    expect(corr.totalMigraineDays, 5, reason: 'the other factors still count all five days');

    baselineService.close();
    await db.close();
  });
}
