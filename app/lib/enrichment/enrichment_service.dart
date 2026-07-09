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

  /// Writes computed factors, leaving a group's columns untouched (rather than nulling them) when
  /// that group's inputs are null — e.g. a re-enrich whose weather fetch failed must not erase
  /// weather already stored from a previous successful enrichment.
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
      dayOfWeek: cal != null ? Value(cal.dayOfWeek) : const Value.absent(),
      season: cal != null ? Value(cal.season) : const Value.absent(),
      timeOfDayBucket: cal != null ? Value(cal.timeOfDayBucket) : const Value.absent(),
      daylightHours: astro != null ? Value(astro.daylightHours) : const Value.absent(),
      sunriseUtc: astro != null ? Value(astro.sunriseUtc) : const Value.absent(),
      sunsetUtc: astro != null ? Value(astro.sunsetUtc) : const Value.absent(),
      moonPhase: astro != null ? Value(astro.moonPhase) : const Value.absent(),
      moonIllumination:
          astro != null ? Value(astro.moonIllumination) : const Value.absent(),
      tempC: weather != null ? Value(weather.tempC) : const Value.absent(),
      humidityPct: weather != null ? Value(weather.humidityPct) : const Value.absent(),
      pressureHpa: weather != null ? Value(weather.pressureHpa) : const Value.absent(),
      precipitationMm:
          weather != null ? Value(weather.precipitationMm) : const Value.absent(),
      pressureDelta24h:
          weather != null ? Value(weather.pressureDelta24h) : const Value.absent(),
      pressureDelta48h:
          weather != null ? Value(weather.pressureDelta48h) : const Value.absent(),
      aqi: weather != null ? Value(weather.aqi) : const Value.absent(),
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
