import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/enrichment/enrichment_service.dart';
import 'package:megrim/enrichment/open_meteo_client.dart';

Map<String, dynamic> fakeHourly(DateTime start) {
  final times = <String>[];
  final press = <double>[];
  final temp = <double>[];
  final hum = <double>[];
  final precip = <double>[];
  for (var i = 0; i < 72; i++) {
    final t = start.add(Duration(hours: i));
    times.add('${t.toIso8601String().substring(0, 13)}:00');
    press.add(1000.0 + i * 0.5);
    temp.add(15.0);
    hum.add(50.0);
    precip.add(0.0);
  }
  return {
    'hourly': {
      'time': times,
      'temperature_2m': temp,
      'relative_humidity_2m': hum,
      'surface_pressure': press,
      'precipitation': precip,
    }
  };
}

OpenMeteoClient okWeatherClient() {
  final start = DateTime.utc(2024, 6, 29, 0);
  return OpenMeteoClient(
    httpClient: MockClient((req) async {
      if (req.url.host == kAirQualityHost) {
        return http.Response(
            jsonEncode({
              'hourly': {
                'time': ['2024-07-01T00:00'],
                'us_aqi': [42]
              }
            }),
            200);
      }
      return http.Response(jsonEncode(fakeHourly(start)), 200);
    }),
    maxRetries: 1,
  );
}

OpenMeteoClient failingWeatherClient() => OpenMeteoClient(
      httpClient: MockClient((req) async => http.Response('down', 503)),
      maxRetries: 1,
      timeout: const Duration(milliseconds: 50),
    );

Future<void> insertEvent(MegrimDatabase db, String id, DateTime started,
    {double? lat, double? lon}) async {
  final now = DateTime.now().toUtc();
  await db.into(db.migraineEvents).insert(MigraineEventsCompanion.insert(
        id: id,
        startedAt: started,
        createdAt: now,
        updatedAt: now,
        geoLat: Value(lat),
        geoLon: Value(lon),
      ));
}

void main() {
  late MegrimDatabase db;

  setUp(() async {
    db = MegrimDatabase.forTesting(NativeDatabase.memory());
    // These tests exercise the opted-IN behavior; weather enrichment is opt-in (default off)
    // since the F-Droid review, so consent is granted explicitly here. The opt-out behavior has
    // its own group below.
    await db.setSetting('weather_enrichment', '1');
  });
  tearDown(() => db.close());

  test('fully enriches using event coordinates', () async {
    await insertEvent(db, 'e1', DateTime.utc(2024, 7, 1, 0),
        lat: 39.96, lon: -105.05);
    final svc = EnrichmentService(db: db, weatherClient: okWeatherClient());

    final ok = await svc.enrichEvent('e1');
    expect(ok, isTrue);

    final d = await (db.select(db.derivedFactors)
          ..where((t) => t.eventId.equals('e1')))
        .getSingle();
    expect(d.enrichedAt, isNotNull);
    expect(d.enrichError, isNull);
    expect(d.pressureHpa, closeTo(1024.0, 1e-6));
    expect(d.pressureDelta24h, closeTo(12.0, 1e-6));
    expect(d.aqi, 42);
    // Calendar + astro were computed locally.
    expect(d.season, isNotNull);
    expect(d.moonPhase, isNotNull);
    expect(d.dayOfWeek, isNotNull);
  });

  test('falls back to home location when the event has no coordinates',
      () async {
    await db.setSetting('home_location',
        jsonEncode({'lat': 51.48, 'lon': 0.0, 'label': 'London'}));
    await insertEvent(db, 'e2', DateTime.utc(2024, 7, 1, 0));
    final svc = EnrichmentService(db: db, weatherClient: okWeatherClient());

    expect(await svc.enrichEvent('e2'), isTrue);
    final d = await (db.select(db.derivedFactors)
          ..where((t) => t.eventId.equals('e2')))
        .getSingle();
    expect(d.enrichedAt, isNotNull);
    expect(d.pressureHpa, isNotNull);
  });

  test('weather failure writes partial data and stays pending', () async {
    await insertEvent(db, 'e3', DateTime.utc(2024, 7, 1, 0),
        lat: 40.0, lon: -105.0);
    final svc = EnrichmentService(db: db, weatherClient: failingWeatherClient());

    expect(await svc.enrichEvent('e3'), isFalse);
    final d = await (db.select(db.derivedFactors)
          ..where((t) => t.eventId.equals('e3')))
        .getSingle();
    expect(d.enrichedAt, isNull); // still queued
    expect(d.enrichError, isNotNull);
    expect(d.moonPhase, isNotNull); // astro still computed locally
    expect(d.pressureHpa, isNull); // weather absent
    expect(await svc.pendingEventIds(), contains('e3'));
  });

  test('no location at all is recorded as an error', () async {
    await insertEvent(db, 'e4', DateTime.utc(2024, 7, 1, 0));
    final svc = EnrichmentService(db: db, weatherClient: okWeatherClient());
    expect(await svc.enrichEvent('e4'), isFalse);
    final d = await (db.select(db.derivedFactors)
          ..where((t) => t.eventId.equals('e4')))
        .getSingle();
    expect(d.enrichError, contains('location'));
  });

  test('a failed re-enrich preserves previously fetched weather', () async {
    await insertEvent(db, 'e5', DateTime.utc(2024, 7, 1, 0),
        lat: 40.0, lon: -105.0);

    // First enrichment succeeds.
    final okSvc = EnrichmentService(db: db, weatherClient: okWeatherClient());
    expect(await okSvc.enrichEvent('e5'), isTrue);
    final firstPass = await (db.select(db.derivedFactors)
          ..where((t) => t.eventId.equals('e5')))
        .getSingle();
    expect(firstPass.pressureHpa, isNotNull);
    expect(firstPass.moonPhase, isNotNull);
    final storedPressure = firstPass.pressureHpa;
    final storedMoon = firstPass.moonPhase;

    // Simulate an edit re-enqueuing the event, then a re-enrich whose weather fetch fails
    // (e.g. offline). Weather previously stored must survive; the row goes back to pending.
    await okSvc.enqueue('e5');
    final failSvc = EnrichmentService(db: db, weatherClient: failingWeatherClient());
    expect(await failSvc.enrichEvent('e5'), isFalse);

    final afterFailure = await (db.select(db.derivedFactors)
          ..where((t) => t.eventId.equals('e5')))
        .getSingle();
    expect(afterFailure.pressureHpa, storedPressure,
        reason: 'weather from the prior success must not be nulled out');
    expect(afterFailure.moonPhase, storedMoon);
    expect(afterFailure.enrichedAt, isNull, reason: 'row goes back to pending');
    expect(afterFailure.enrichError, isNotNull);

    // A subsequent successful enrich fully restores/refreshes everything and clears the error.
    expect(await okSvc.enrichEvent('e5'), isTrue);
    final afterRecovery = await (db.select(db.derivedFactors)
          ..where((t) => t.eventId.equals('e5')))
        .getSingle();
    expect(afterRecovery.enrichedAt, isNotNull);
    expect(afterRecovery.enrichError, isNull);
  });

  test('processQueue enriches all pending events', () async {
    await insertEvent(db, 'a', DateTime.utc(2024, 7, 1, 0),
        lat: 40.0, lon: -105.0);
    await insertEvent(db, 'b', DateTime.utc(2024, 6, 15, 0),
        lat: 40.0, lon: -105.0);
    final svc = EnrichmentService(db: db, weatherClient: okWeatherClient());

    expect((await svc.pendingEventIds()).length, 2);
    final progress = <int>[];
    await svc.processQueue(
        throttle: false, onProgress: (done, total) => progress.add(done));
    expect(progress, [1, 2]);
    expect(await svc.pendingEventIds(), isEmpty);
  });

  group('opt-in gate (weather_enrichment setting)', () {
    test('opted out (the default): no HTTP at all, row completes with local factors', () async {
      await db.setSetting('weather_enrichment', '0');
      await insertEvent(db, 'g1', DateTime.utc(2024, 7, 1, 0),
          lat: 40.0, lon: -105.0);
      var calls = 0;
      final svc = EnrichmentService(
        db: db,
        weatherClient: OpenMeteoClient(
          httpClient: MockClient((req) async {
            calls++;
            return http.Response('should never be called', 500);
          }),
          maxRetries: 1,
        ),
      );

      // Returns false ("not fully enriched with weather") but the row is complete.
      expect(await svc.enrichEvent('g1'), isFalse);
      expect(calls, 0, reason: 'opt-out must mean zero network requests');

      final d = await (db.select(db.derivedFactors)
            ..where((t) => t.eventId.equals('g1')))
          .getSingle();
      expect(d.enrichedAt, isNotNull,
          reason: 'row is complete — the queue must drain without network');
      expect(d.enrichError, isNull);
      expect(d.season, isNotNull); // local factors still computed
      expect(d.moonPhase, isNotNull);
      expect(d.daylightHours, isNotNull);
      expect(d.pressureHpa, isNull); // no weather anywhere
      expect(d.tempC, isNull);
      expect(d.aqi, isNull);
      expect(await svc.pendingEventIds(), isEmpty);
    });

    test('the setting missing entirely behaves as opted out', () async {
      // A fresh database that never saw the setting (a brand-new install).
      final fresh = MegrimDatabase.forTesting(NativeDatabase.memory());
      addTearDown(fresh.close);
      await insertEvent(fresh, 'g2', DateTime.utc(2024, 7, 1, 0),
          lat: 40.0, lon: -105.0);
      var calls = 0;
      final svc = EnrichmentService(
        db: fresh,
        weatherClient: OpenMeteoClient(
          httpClient: MockClient((req) async {
            calls++;
            return http.Response('nope', 500);
          }),
          maxRetries: 1,
        ),
      );
      await svc.enrichEvent('g2');
      expect(calls, 0);
    });

    test('opting in later backfills weather on re-enrich', () async {
      await db.setSetting('weather_enrichment', '0');
      await insertEvent(db, 'g3', DateTime.utc(2024, 7, 1, 0),
          lat: 40.0, lon: -105.0);
      final svc = EnrichmentService(db: db, weatherClient: okWeatherClient());

      await svc.enrichEvent('g3');
      var d = await (db.select(db.derivedFactors)
            ..where((t) => t.eventId.equals('g3')))
          .getSingle();
      expect(d.pressureHpa, isNull);

      // The Settings toggle re-enqueues everything (reEnrichAll) after enabling.
      await db.setSetting('weather_enrichment', '1');
      await svc.enqueue('g3');
      await svc.processQueue(throttle: false);

      d = await (db.select(db.derivedFactors)
            ..where((t) => t.eventId.equals('g3')))
          .getSingle();
      expect(d.pressureHpa, isNotNull, reason: 'weather backfilled after opt-in');
      expect(d.enrichedAt, isNotNull);
    });
  });
}
