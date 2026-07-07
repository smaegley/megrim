import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:megrim/enrichment/open_meteo_client.dart';

/// Build a synthetic 72-hour UTC hourly series starting at [start], with pressure rising
/// linearly by [pressureStep] hPa per hour so 24h/48h deltas are exactly predictable.
Map<String, dynamic> fakeHourly(DateTime start, {double pressureStep = 0.5}) {
  final times = <String>[];
  final temp = <double>[];
  final hum = <double>[];
  final press = <double>[];
  final precip = <double>[];
  for (var i = 0; i < 72; i++) {
    final t = start.add(Duration(hours: i));
    times.add('${t.toIso8601String().substring(0, 13)}:00');
    temp.add(15.0 + i * 0.1);
    hum.add(50.0);
    press.add(1000.0 + i * pressureStep);
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

void main() {
  group('roundCoord', () {
    test('rounds to 2 decimals (~1 km)', () {
      expect(roundCoord(39.9612345), 39.96);
      expect(roundCoord(-105.0567), -105.06);
      expect(roundCoord(0.0), 0.0);
    });
  });

  group('weatherUri', () {
    final onset = DateTime.utc(2024, 6, 1, 12);
    test('old events use the archive host', () {
      final now = DateTime.utc(2024, 7, 1);
      final uri = OpenMeteoClient.weatherUri(39.9612, -105.0567, onset, now: now);
      expect(uri.host, kArchiveHost);
      expect(uri.queryParameters['latitude'], '39.96');
      expect(uri.queryParameters['longitude'], '-105.06');
      // 3-day window ending on the event date.
      expect(uri.queryParameters['start_date'], '2024-05-30');
      expect(uri.queryParameters['end_date'], '2024-06-01');
    });

    test('recent events use the forecast host with past_days', () {
      final now = DateTime.utc(2024, 6, 4); // 3 days after onset
      final uri = OpenMeteoClient.weatherUri(10.0, 20.0, onset, now: now);
      expect(uri.host, kForecastHost);
      expect(uri.queryParameters['past_days'], '7');
    });
  });

  group('extractHourlyWeather', () {
    test('samples the onset hour and computes pressure deltas', () {
      final start = DateTime.utc(2024, 6, 29, 0); // index 0
      final json = fakeHourly(start); // pressure = 1000 + i*0.5
      final onset = DateTime.utc(2024, 7, 1, 0, 20); // index 48, nearest hour
      final w = extractHourlyWeather(json, onset);

      expect(w.pressureHpa, closeTo(1024.0, 1e-9)); // 1000 + 48*0.5
      expect(w.pressureDelta24h, closeTo(12.0, 1e-9)); // 24 hours * 0.5
      expect(w.pressureDelta48h, closeTo(24.0, 1e-9)); // 48 hours * 0.5
      expect(w.tempC, closeTo(15.0 + 48 * 0.1, 1e-9));
      expect(w.humidityPct, 50.0);
    });

    test('missing earlier hours leave deltas null', () {
      final start = DateTime.utc(2024, 7, 1, 0); // onset at index 0
      final json = fakeHourly(start);
      final onset = DateTime.utc(2024, 7, 1, 0);
      final w = extractHourlyWeather(json, onset);
      expect(w.pressureHpa, isNotNull);
      expect(w.pressureDelta24h, isNull); // no data 24h before the first slot
      expect(w.pressureDelta48h, isNull);
    });

    test('empty/garbage json yields an empty result', () {
      expect(extractHourlyWeather(const {}, DateTime.utc(2024)).isEmpty, isTrue);
      expect(
          extractHourlyWeather(const {'hourly': {}}, DateTime.utc(2024)).isEmpty,
          isTrue);
    });
  });

  group('extractAqi', () {
    test('reads the onset-hour us_aqi', () {
      final json = {
        'hourly': {
          'time': ['2024-07-01T00:00', '2024-07-01T01:00', '2024-07-01T02:00'],
          'us_aqi': [40, 55, 60],
        }
      };
      expect(extractAqi(json, DateTime.utc(2024, 7, 1, 1, 10)), 55);
    });

    test('missing aqi yields null', () {
      expect(extractAqi(const {'hourly': {}}, DateTime.utc(2024)), isNull);
    });
  });

  group('fetchWeather (mocked http)', () {
    test('assembles weather; AQI failure is tolerated', () async {
      final start = DateTime.utc(2024, 6, 29, 0);
      final weatherJson = fakeHourly(start);
      final client = MockClient((req) async {
        if (req.url.host == kAirQualityHost) {
          return http.Response('error', 500); // AQI unavailable
        }
        return http.Response(jsonEncode(weatherJson), 200);
      });
      final om = OpenMeteoClient(httpClient: client, maxRetries: 1);
      final onset = DateTime.utc(2024, 7, 1, 0);
      final w = await om.fetchWeather(39.96, -105.05, onset,
          now: DateTime.utc(2024, 7, 20));
      expect(w.pressureHpa, closeTo(1024.0, 1e-9));
      expect(w.aqi, isNull); // best-effort AQI failed but weather still returned
      om.close();
    });

    test('throws EnrichmentException after retries when weather fails', () async {
      final client = MockClient((req) async => http.Response('nope', 503));
      final om = OpenMeteoClient(
        httpClient: client,
        maxRetries: 2,
        timeout: const Duration(milliseconds: 100),
      );
      expect(
        () => om.fetchWeather(0, 0, DateTime.utc(2024, 1, 1),
            now: DateTime.utc(2024, 2, 1)),
        throwsA(isA<EnrichmentException>()),
      );
      om.close();
    });
  });
}
