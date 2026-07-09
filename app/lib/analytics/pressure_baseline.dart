import 'dart:convert';

import 'package:http/http.dart' as http;

import '../database/database.dart';
import '../enrichment/open_meteo_client.dart' show kArchiveHost, roundCoord;
import '../models/home_location.dart';
import 'correlations.dart' show kPressureBuckets, pressureBucket;

/// Builds and caches the all-days 24h pressure-delta histogram used as the non-migraine-day
/// baseline for the pressure correlation factor (SPEC §6.2).
///
/// One bulk Open-Meteo archive fetch of `surface_pressure_mean` over the study window at the home
/// location, bucketed and cached in app_settings under `pressure_baseline`. Refreshed only when
/// the window grows or the home location changes (keyed by a range+location tag).

class PressureBaseline {
  final String tag;
  final Map<String, int> histogram;
  const PressureBaseline(this.tag, this.histogram);

  Map<String, dynamic> toJson() => {'tag': tag, 'histogram': histogram};

  static PressureBaseline? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final hist = (j['histogram'] as Map).map(
          (k, v) => MapEntry(k.toString(), (v as num).toInt()));
      return PressureBaseline(j['tag'] as String, hist);
    } catch (_) {
      return null;
    }
  }
}

String pressureBaselineTag(DateTime start, DateTime end, double lat, double lon) =>
    '${_d(start)}_${_d(end)}_${roundCoord(lat)}_${roundCoord(lon)}';

/// Bucket a daily-mean pressure series into a 24h-delta histogram. Pure/testable.
/// [dates] and [pressures] are parallel; nulls are skipped. A day's delta needs the prior day.
Map<String, int> bucketDailyDeltas(List<DateTime> dates, List<double?> pressures) {
  final hist = {for (final b in kPressureBuckets) b: 0};
  final byDate = <DateTime, double>{};
  for (var i = 0; i < dates.length; i++) {
    final p = i < pressures.length ? pressures[i] : null;
    if (p != null) byDate[_dateOnly(dates[i])] = p;
  }
  byDate.forEach((date, p) {
    final prev = byDate[date.subtract(const Duration(days: 1))];
    if (prev != null) {
      hist[pressureBucket(p - prev)] = hist[pressureBucket(p - prev)]! + 1;
    }
  });
  return hist;
}

/// Parse an Open-Meteo archive `daily` response into (dates, pressures). Pure/testable.
({List<DateTime> dates, List<double?> pressures}) parseDailyPressure(
    Map<String, dynamic> json) {
  final daily = json['daily'];
  if (daily is! Map) return (dates: <DateTime>[], pressures: <double?>[]);
  final times = (daily['time'] as List?)?.cast<String>() ?? const [];
  final press = (daily['surface_pressure_mean'] as List?) ?? const [];
  final dates = times.map((t) => DateTime.parse(t)).toList();
  final pressures =
      press.map((e) => (e as num?)?.toDouble()).toList().cast<double?>();
  return (dates: dates, pressures: pressures);
}

class PressureBaselineService {
  final MegrimDatabase db;
  final http.Client _http;
  final Duration timeout;

  PressureBaselineService({
    required this.db,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 60),
  }) : _http = httpClient ?? http.Client();

  void close() => _http.close();

  static Uri dailyUri(double lat, double lon, DateTime start, DateTime end) =>
      Uri.https(kArchiveHost, '/v1/archive', {
        'latitude': '${roundCoord(lat)}',
        'longitude': '${roundCoord(lon)}',
        // One prior day so the first in-range day has a delta. Subtract on a UTC copy of the
        // date fields (not `start` directly) so a local-time DST transition can't shift this by
        // a day.
        'start_date':
            _d(DateTime.utc(start.year, start.month, start.day).subtract(const Duration(days: 1))),
        'end_date': _d(end),
        'daily': 'surface_pressure_mean',
        'timezone': 'UTC',
      });

  /// Return the cached baseline if its tag matches, else fetch/build/cache. Returns null if there
  /// is no home location or the fetch fails (the pressure factor is then simply omitted).
  ///
  /// [allowFetch] gates the network call: pass false when offline so the Analytics screen never
  /// blocks on a request — it then returns the cached baseline (or null) immediately.
  Future<PressureBaseline?> getOrBuild(DateTime start, DateTime end,
      {bool allowFetch = true}) async {
    final home = HomeLocation.tryDecode(await db.getSetting('home_location'));
    if (home == null) return null;
    final tag = pressureBaselineTag(start, end, home.lat, home.lon);

    final cached = PressureBaseline.tryDecode(
        await db.getSetting('pressure_baseline'));
    if (cached != null && cached.tag == tag) return cached;
    if (!allowFetch) return cached; // offline: use cache if any, never hit the network

    try {
      final uri = dailyUri(home.lat, home.lon, start, end);
      final resp = await _http.get(uri).timeout(timeout);
      if (resp.statusCode != 200) return cached; // keep stale over nothing
      final parsed =
          parseDailyPressure(jsonDecode(resp.body) as Map<String, dynamic>);
      final hist = bucketDailyDeltas(parsed.dates, parsed.pressures);
      final baseline = PressureBaseline(tag, hist);
      await db.setSetting('pressure_baseline', jsonEncode(baseline.toJson()));
      return baseline;
    } catch (_) {
      return cached;
    }
  }
}

// UTC (not local) so `date.subtract(Duration(days: 1))` in bucketDailyDeltas lands exactly on
// the prior calendar day's key even across a local DST transition (UTC has no DST).
DateTime _dateOnly(DateTime t) => DateTime.utc(t.year, t.month, t.day);
String _d(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
