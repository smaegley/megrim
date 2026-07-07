import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:megrim/analytics/pressure_baseline.dart';
import 'package:megrim/database/database.dart';

void main() {
  test('bucketDailyDeltas computes 24h deltas, skipping the first day', () {
    final dates = [
      DateTime(2024, 1, 1),
      DateTime(2024, 1, 2),
      DateTime(2024, 1, 3),
      DateTime(2024, 1, 4),
      DateTime(2024, 1, 5),
    ];
    final pressures = <double?>[1000, 1005, 1002, 995, 1010];
    final hist = bucketDailyDeltas(dates, pressures);
    expect(hist['5 to 10'], 1); // +5 (Jan2)
    expect(hist['-5 to 0'], 1); // -3 (Jan3)
    expect(hist['-10 to -5'], 1); // -7 (Jan4)
    expect(hist['> 10'], 1); // +15 (Jan5)
    expect(hist['0 to 5'], 0);
  });

  test('parseDailyPressure reads the archive daily shape', () {
    final json = {
      'daily': {
        'time': ['2024-01-01', '2024-01-02'],
        'surface_pressure_mean': [1013.2, null],
      }
    };
    final p = parseDailyPressure(json);
    expect(p.dates, hasLength(2));
    expect(p.pressures[0], closeTo(1013.2, 1e-9));
    expect(p.pressures[1], isNull);
  });

  test('service caches by tag and reuses without re-fetching', () async {
    final db = MegrimDatabase.forTesting(NativeDatabase.memory());
    await db.setSetting('home_location',
        jsonEncode({'lat': 40.0, 'lon': -105.0, 'label': 'Home'}));

    var httpCalls = 0;
    final client = MockClient((req) async {
      httpCalls++;
      return http.Response(
          jsonEncode({
            'daily': {
              'time': ['2024-01-01', '2024-01-02', '2024-01-03'],
              'surface_pressure_mean': [1000, 1008, 1001],
            }
          }),
          200);
    });
    final svc = PressureBaselineService(db: db, httpClient: client);

    final start = DateTime(2024, 1, 1);
    final end = DateTime(2024, 1, 3);
    final first = await svc.getOrBuild(start, end);
    expect(first, isNotNull);
    expect(httpCalls, 1);
    // +8 then -7 -> one in '5 to 10', one in '-10 to -5'
    expect(first!.histogram['5 to 10'], 1);
    expect(first.histogram['-10 to -5'], 1);

    // Second call with same window/location hits the cache — no new HTTP.
    final second = await svc.getOrBuild(start, end);
    expect(httpCalls, 1);
    expect(second!.tag, first.tag);

    svc.close();
    await db.close();
  });

  test('no home location yields null baseline', () async {
    final db = MegrimDatabase.forTesting(NativeDatabase.memory());
    final svc = PressureBaselineService(db: db);
    expect(await svc.getOrBuild(DateTime(2024), DateTime(2024, 2)), isNull);
    svc.close();
    await db.close();
  });
}
