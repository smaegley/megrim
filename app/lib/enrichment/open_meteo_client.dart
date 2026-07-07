import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Open-Meteo weather enrichment (SPEC §5.1). Keyless HTTPS. This is the ONLY network host the
/// app ever contacts. Coordinates are rounded to 2 decimals (~1 km) before every request.
///
/// Network I/O and JSON parsing are kept separate: [extractHourlyWeather] and [extractAqi] are
/// pure functions over decoded JSON so they can be unit-tested with canned responses (no network
/// in tests).

const String kArchiveHost = 'archive-api.open-meteo.com';
const String kForecastHost = 'api.open-meteo.com';
const String kAirQualityHost = 'air-quality-api.open-meteo.com';

const List<String> _hourlyVars = [
  'temperature_2m',
  'relative_humidity_2m',
  'surface_pressure',
  'precipitation',
];

/// Round a coordinate to 2 decimals (~1 km privacy cell) — SPEC §5.1 / §3.1.
double roundCoord(double v) => (v * 100).round() / 100;

/// Weather values sampled at the hour of onset, plus pressure change vs 24h/48h earlier.
class WeatherResult {
  final double? tempC;
  final double? humidityPct;
  final double? pressureHpa;
  final double? precipitationMm;
  final double? pressureDelta24h;
  final double? pressureDelta48h;
  final int? aqi;

  const WeatherResult({
    this.tempC,
    this.humidityPct,
    this.pressureHpa,
    this.precipitationMm,
    this.pressureDelta24h,
    this.pressureDelta48h,
    this.aqi,
  });

  bool get isEmpty =>
      tempC == null &&
      humidityPct == null &&
      pressureHpa == null &&
      precipitationMm == null;
}

/// Thrown when all retries are exhausted; carries a human-readable reason for `enrich_error`.
class EnrichmentException implements Exception {
  final String message;
  EnrichmentException(this.message);
  @override
  String toString() => message;
}

class OpenMeteoClient {
  final http.Client _http;
  final Duration timeout;
  final int maxRetries;

  /// Archive lags real time by ~5 days, so events within this many days use the forecast API's
  /// `past_days` window instead (SPEC §5.1).
  static const int recentThresholdDays = 7;

  OpenMeteoClient({
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 15),
    this.maxRetries = 3,
  }) : _http = httpClient ?? http.Client();

  void close() => _http.close();

  /// Build the weather request URI for an event at [onsetUtc]. Uses the archive API for older
  /// events and the forecast API (with `past_days`) for recent ones.
  static Uri weatherUri(double lat, double lon, DateTime onsetUtc, {DateTime? now}) {
    final la = roundCoord(lat);
    final lo = roundCoord(lon);
    final ageDays = (now ?? DateTime.now().toUtc()).difference(onsetUtc).inDays;

    if (ageDays > recentThresholdDays) {
      final d = _dateOnly(onsetUtc);
      final start = d.subtract(const Duration(days: 2));
      return Uri.https(kArchiveHost, '/v1/archive', {
        'latitude': '$la',
        'longitude': '$lo',
        'start_date': _fmtDate(start),
        'end_date': _fmtDate(d),
        'hourly': _hourlyVars.join(','),
        'timezone': 'UTC',
      });
    }
    return Uri.https(kForecastHost, '/v1/forecast', {
      'latitude': '$la',
      'longitude': '$lo',
      'past_days': '$recentThresholdDays',
      'forecast_days': '1',
      'hourly': _hourlyVars.join(','),
      'timezone': 'UTC',
    });
  }

  static Uri airQualityUri(double lat, double lon, DateTime onsetUtc) {
    final d = _dateOnly(onsetUtc);
    return Uri.https(kAirQualityHost, '/v1/air-quality', {
      'latitude': '${roundCoord(lat)}',
      'longitude': '${roundCoord(lon)}',
      'start_date': _fmtDate(d),
      'end_date': _fmtDate(d),
      'hourly': 'us_aqi',
      'timezone': 'UTC',
    });
  }

  /// Fetch and assemble weather + AQI for an event. Throws [EnrichmentException] if the weather
  /// call fails after all retries. AQI is best-effort: a failure there leaves aqi null.
  Future<WeatherResult> fetchWeather(
    double lat,
    double lon,
    DateTime onsetUtc, {
    DateTime? now,
  }) async {
    final uri = weatherUri(lat, lon, onsetUtc, now: now);
    final body = await _getJsonWithRetry(uri);
    final w = extractHourlyWeather(body, onsetUtc);

    int? aqi;
    try {
      final aqBody = await _getJsonWithRetry(airQualityUri(lat, lon, onsetUtc));
      aqi = extractAqi(aqBody, onsetUtc);
    } catch (_) {
      // Best-effort — historical AQI coverage is limited (SPEC §5.1).
    }

    return WeatherResult(
      tempC: w.tempC,
      humidityPct: w.humidityPct,
      pressureHpa: w.pressureHpa,
      precipitationMm: w.precipitationMm,
      pressureDelta24h: w.pressureDelta24h,
      pressureDelta48h: w.pressureDelta48h,
      aqi: aqi,
    );
  }

  Future<Map<String, dynamic>> _getJsonWithRetry(Uri uri) async {
    Object? lastErr;
    for (var attempt = 0; attempt < maxRetries; attempt++) {
      if (attempt > 0) {
        // Exponential backoff: 1s, 2s, 4s…
        await Future<void>.delayed(Duration(seconds: 1 << (attempt - 1)));
      }
      try {
        final resp = await _http.get(uri).timeout(timeout);
        if (resp.statusCode == 200) {
          return jsonDecode(resp.body) as Map<String, dynamic>;
        }
        lastErr = 'HTTP ${resp.statusCode}';
      } on TimeoutException {
        lastErr = 'timeout';
      } catch (e) {
        lastErr = e;
      }
    }
    throw EnrichmentException('Weather fetch failed: $lastErr');
  }

  static DateTime _dateOnly(DateTime t) =>
      DateTime.utc(t.year, t.month, t.day);
  static String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Pure extraction of the onset-hour weather sample and pressure deltas from an Open-Meteo
/// hourly response. Times in the response are assumed UTC (we always request timezone=UTC).
WeatherResult extractHourlyWeather(Map<String, dynamic> json, DateTime onsetUtc) {
  final hourly = json['hourly'];
  if (hourly is! Map) return const WeatherResult();

  final times = (hourly['time'] as List?)?.cast<String>() ?? const [];
  if (times.isEmpty) return const WeatherResult();

  final temps = _nums(hourly['temperature_2m']);
  final hums = _nums(hourly['relative_humidity_2m']);
  final press = _nums(hourly['surface_pressure']);
  final precip = _nums(hourly['precipitation']);

  final onsetHour = DateTime.utc(
      onsetUtc.year, onsetUtc.month, onsetUtc.day, onsetUtc.hour);
  final idx = _closestHourIndex(times, onsetHour);
  if (idx < 0) return const WeatherResult();

  double? at(List<double?> series, int i) =>
      (i >= 0 && i < series.length) ? series[i] : null;

  final pNow = at(press, idx);
  final p24 = at(press, idx - 24);
  final p48 = at(press, idx - 48);

  return WeatherResult(
    tempC: at(temps, idx),
    humidityPct: at(hums, idx),
    pressureHpa: pNow,
    precipitationMm: at(precip, idx),
    pressureDelta24h: (pNow != null && p24 != null) ? pNow - p24 : null,
    pressureDelta48h: (pNow != null && p48 != null) ? pNow - p48 : null,
  );
}

/// Pure extraction of the onset-hour US AQI value.
int? extractAqi(Map<String, dynamic> json, DateTime onsetUtc) {
  final hourly = json['hourly'];
  if (hourly is! Map) return null;
  final times = (hourly['time'] as List?)?.cast<String>() ?? const [];
  final vals = _nums(hourly['us_aqi']);
  if (times.isEmpty) return null;
  final onsetHour = DateTime.utc(
      onsetUtc.year, onsetUtc.month, onsetUtc.day, onsetUtc.hour);
  final idx = _closestHourIndex(times, onsetHour);
  if (idx < 0 || idx >= vals.length) return null;
  return vals[idx]?.round();
}

List<double?> _nums(dynamic list) {
  if (list is! List) return const [];
  return list.map((e) => (e as num?)?.toDouble()).toList();
}

/// Index of the hourly slot at or nearest to [onsetHour]. Open-Meteo hourly series are
/// contiguous, so we locate the first slot >= onset and pick whichever neighbour is closer.
int _closestHourIndex(List<String> times, DateTime onsetHour) {
  int best = -1;
  int bestDiff = 1 << 62;
  for (var i = 0; i < times.length; i++) {
    final t = DateTime.tryParse('${times[i]}Z') ?? DateTime.tryParse(times[i]);
    if (t == null) continue;
    final diff = (t.toUtc().difference(onsetHour).inMinutes).abs();
    if (diff < bestDiff) {
      bestDiff = diff;
      best = i;
    }
  }
  return best;
}
