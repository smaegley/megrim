import 'package:drift/drift.dart';

import '../database/database.dart';
import '../models/home_location.dart';
import 'astro.dart';
import 'calendar_factors.dart';
import 'open_meteo_client.dart';

/// Orchestrates on-device enrichment (SPEC §5). For each event it computes:
///   1. calendar factors (local, always)
///   2. astronomical factors (local math, always)
///   3. weather (Open-Meteo, may fail → row stays queued with an error)
///
/// Calendar + astro are written even when weather fails, so partial enrichment is useful and the
/// row is retried later (a null `enriched_at` marks it as pending — §3.2).
class EnrichmentService {
  final MegrimDatabase db;
  final OpenMeteoClient weather;

  /// Throttle for bulk jobs (SPEC §5.1: ~2 req/s to stay well under Open-Meteo's rate limit).
  final Duration bulkThrottle;

  EnrichmentService({
    required this.db,
    OpenMeteoClient? weatherClient,
    this.bulkThrottle = const Duration(milliseconds: 500),
  }) : weather = weatherClient ?? OpenMeteoClient();

  /// Resolve the coordinates to enrich against: the event's own (rounded) location if present,
  /// otherwise the configured home location. Returns null if neither is available.
  Future<({double lat, double lon})?> _coordsFor(MigraineEvent e) async {
    if (e.geoLat != null && e.geoLon != null) {
      return (lat: e.geoLat!, lon: e.geoLon!);
    }
    final home = HomeLocation.tryDecode(await db.getSetting('home_location'));
    if (home != null) return (lat: home.lat, lon: home.lon);
    return null;
  }

  /// Enrich a single event by id. Never throws — failures are recorded in `enrich_error` and the
  /// row is left pending for a later retry. Returns true if fully enriched (weather included).
  Future<bool> enrichEvent(String eventId) async {
    final event = await (db.select(db.migraineEvents)
          ..where((t) => t.id.equals(eventId)))
        .getSingleOrNull();
    if (event == null) return false;

    final coords = await _coordsFor(event);
    if (coords == null) {
      await _writeDerived(
        eventId,
        error: 'No location set — set a home location to enable enrichment.',
        enriched: false,
      );
      return false;
    }

    final startedUtc = event.startedAt.toUtc();
    final cal = computeCalendarFactors(event.startedAt.toLocal(), coords.lat);
    final astro = computeAstro(startedUtc, coords.lat, coords.lon);

    WeatherResult? w;
    String? error;
    try {
      w = await weather.fetchWeather(coords.lat, coords.lon, startedUtc);
    } on EnrichmentException catch (e) {
      error = e.message;
    } catch (e) {
      error = 'Weather error: $e';
    }

    await _writeDerived(
      eventId,
      cal: cal,
      astro: astro,
      weather: w,
      error: error,
      enriched: w != null,
    );
    return w != null;
  }

  Future<void> _writeDerived(
    String eventId, {
    CalendarFactors? cal,
    AstroResult? astro,
    WeatherResult? weather,
    String? error,
    required bool enriched,
  }) async {
    final companion = DerivedFactorsCompanion(
      eventId: Value(eventId),
      dayOfWeek: Value(cal?.dayOfWeek),
      season: Value(cal?.season),
      timeOfDayBucket: Value(cal?.timeOfDayBucket),
      daylightHours: Value(astro?.daylightHours),
      sunriseUtc: Value(astro?.sunriseUtc),
      sunsetUtc: Value(astro?.sunsetUtc),
      moonPhase: Value(astro?.moonPhase),
      moonIllumination: Value(astro?.moonIllumination),
      tempC: Value(weather?.tempC),
      humidityPct: Value(weather?.humidityPct),
      pressureHpa: Value(weather?.pressureHpa),
      precipitationMm: Value(weather?.precipitationMm),
      pressureDelta24h: Value(weather?.pressureDelta24h),
      pressureDelta48h: Value(weather?.pressureDelta48h),
      aqi: Value(weather?.aqi),
      enrichedAt: Value(enriched ? DateTime.now().toUtc() : null),
      enrichError: Value(error),
    );
    await db.into(db.derivedFactors).insertOnConflictUpdate(companion);
  }

  /// Enqueue an event for enrichment by ensuring a pending derived_factors row exists.
  /// Callers (save/edit/import) use this, then trigger [processQueue].
  Future<void> enqueue(String eventId) async {
    await db.into(db.derivedFactors).insertOnConflictUpdate(
          DerivedFactorsCompanion(
            eventId: Value(eventId),
            enrichedAt: const Value(null),
          ),
        );
  }

  /// Event ids that still need enrichment (no derived row, or `enriched_at` is null).
  Future<List<String>> pendingEventIds() async {
    final query = db.customSelect(
      'SELECT e.id AS id FROM migraine_events e '
      'LEFT JOIN derived_factors d ON d.event_id = e.id '
      'WHERE d.event_id IS NULL OR d.enriched_at IS NULL '
      'ORDER BY e.started_at DESC',
      readsFrom: {db.migraineEvents, db.derivedFactors},
    );
    final rows = await query.get();
    return rows.map((r) => r.read<String>('id')).toList();
  }

  /// Process the pending queue (SPEC §5). Retried on app start / connectivity regain / bulk jobs.
  /// [onProgress] reports (done, total) for the bulk "computing…" UI. Throttled to respect the
  /// Open-Meteo rate limit.
  Future<void> processQueue({
    void Function(int done, int total)? onProgress,
    bool throttle = true,
  }) async {
    final ids = await pendingEventIds();
    for (var i = 0; i < ids.length; i++) {
      await enrichEvent(ids[i]);
      onProgress?.call(i + 1, ids.length);
      if (throttle && i < ids.length - 1) {
        await Future<void>.delayed(bulkThrottle);
      }
    }
  }
}
