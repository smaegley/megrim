import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../analytics/correlations.dart';
import '../analytics/dashboard.dart';
import '../analytics/pressure_baseline.dart';
import '../database/database.dart';
import '../enrichment/enrichment_service.dart';
import '../models/home_location.dart';
import '../services/export_service.dart';
import '../services/import_service.dart';

/// Single entry point the UI uses to reach data + services. Keeps widgets free of Drift details.
class MegrimRepository {
  final MegrimDatabase db;
  final EnrichmentService enrichment;
  final _uuid = const Uuid();

  MegrimRepository({required this.db, EnrichmentService? enrichment})
      : enrichment = enrichment ?? EnrichmentService(db: db);

  // ── Onboarding gates ──────────────────────────────────────────────────────
  Future<bool> get disclaimerAccepted async =>
      (await db.getSetting('disclaimer_accepted_at')) != null;

  Future<void> acceptDisclaimer() =>
      db.setSetting('disclaimer_accepted_at', DateTime.now().toUtc().toIso8601String());

  Future<HomeLocation?> get homeLocation async =>
      HomeLocation.tryDecode(await db.getSetting('home_location'));

  Future<void> setHomeLocation(HomeLocation loc) =>
      db.setSetting('home_location', loc.encode());

  Future<bool> get isOnboarded async =>
      (await disclaimerAccepted) && (await homeLocation) != null;

  // ── Events ──────────────────────────────────────────────────────────────
  Stream<List<MigraineEvent>> watchEvents() {
    return (db.select(db.migraineEvents)
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .watch();
  }

  Future<MigraineEvent?> getEvent(String id) =>
      (db.select(db.migraineEvents)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<DerivedFactor?> getDerived(String id) =>
      (db.select(db.derivedFactors)..where((t) => t.eventId.equals(id)))
          .getSingleOrNull();

  /// Start a new event now. Returns the new id. Enqueues enrichment.
  Future<String> startEvent({int? severity, double? lat, double? lon, String? label}) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();
    await db.into(db.migraineEvents).insert(MigraineEventsCompanion.insert(
          id: id,
          startedAt: now,
          severity: Value(severity),
          geoLat: Value(lat),
          geoLon: Value(lon),
          geoLabel: Value(label),
          createdAt: now,
          updatedAt: now,
        ));
    await enrichment.enqueue(id);
    return id;
  }

  Future<void> updateEvent(MigraineEventsCompanion patch) async {
    await (db.update(db.migraineEvents)
          ..where((t) => t.id.equals(patch.id.value)))
        .write(patch.copyWith(updatedAt: Value(DateTime.now().toUtc())));
  }

  Future<void> endEvent(String id) async {
    await (db.update(db.migraineEvents)..where((t) => t.id.equals(id))).write(
      MigraineEventsCompanion(
        endedAt: Value(DateTime.now().toUtc()),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  /// Hard delete (SPEC §3.1: no tombstones). Returns the deleted rows so the UI can offer undo.
  Future<({MigraineEvent event, DerivedFactor? derived})?> deleteEvent(
      String id) async {
    final event = await getEvent(id);
    if (event == null) return null;
    final derived = await getDerived(id);
    await (db.delete(db.migraineEvents)..where((t) => t.id.equals(id))).go();
    return (event: event, derived: derived);
  }

  Future<void> restoreEvent(MigraineEvent event, DerivedFactor? derived) async {
    await db.into(db.migraineEvents).insert(event.toCompanion(true));
    if (derived != null) {
      await db.into(db.derivedFactors).insert(derived.toCompanion(true));
    }
  }

  // ── Analytics ────────────────────────────────────────────────────────────
  Future<DashboardResult> dashboard() async {
    final events = await db.select(db.migraineEvents).get();
    final derived = await db.select(db.derivedFactors).get();
    final dById = {for (final d in derived) d.eventId: d};
    final stats = events
        .map((e) => EventStat(
              startedAt: e.startedAt,
              endedAt: e.endedAt,
              severity: e.severity,
              dayOfWeek: dById[e.id]?.dayOfWeek,
              season: dById[e.id]?.season,
              timeOfDayBucket: dById[e.id]?.timeOfDayBucket,
              moonPhase: dById[e.id]?.moonPhase,
              pressureDelta24h: dById[e.id]?.pressureDelta24h,
            ))
        .toList();
    return computeDashboard(stats);
  }

  Future<CorrelationResult> correlations(
      {PressureBaselineService? baselineService}) async {
    final events = await db.select(db.migraineEvents).get();
    if (events.length < kMinEventsForCorrelations) {
      return computeCorrelations(eventStarts: events.map((e) => e.startedAt).toList());
    }
    final derived = await db.select(db.derivedFactors).get();
    final deltas = derived
        .where((d) => d.pressureDelta24h != null)
        .map((d) => d.pressureDelta24h!)
        .toList();

    final dates = events.map((e) => e.startedAt.toLocal()).toList()..sort();
    final home = await homeLocation;
    Map<String, int>? baseline;
    if (baselineService != null && home != null) {
      final b = await baselineService.getOrBuild(
        DateTime(dates.first.year, dates.first.month, dates.first.day),
        DateTime(dates.last.year, dates.last.month, dates.last.day),
      );
      baseline = b?.histogram;
    }

    return computeCorrelations(
      eventStarts: events.map((e) => e.startedAt).toList(),
      migrainePressureDeltas: deltas,
      pressureBaseline: baseline,
      homeLat: home?.lat ?? 40.0,
    );
  }

  // ── Vocab ────────────────────────────────────────────────────────────────
  Future<List<String>> vocab(String kind) => db.vocabValues(kind);
  Future<void> addVocab(String kind, String value) => db.addVocab(kind, value);
  Future<void> renameVocab(String kind, String from, String to) =>
      db.renameVocab(kind, from, to);
  Future<void> deleteVocab(String kind, String value) =>
      db.deleteVocab(kind, value);

  // ── Export / import ──────────────────────────────────────────────────────
  ExportService get exporter => ExportService(db: db);
  ImportService get importer => ImportService(db);

  // ── Enrichment ───────────────────────────────────────────────────────────
  Future<void> processEnrichmentQueue(
          {void Function(int, int)? onProgress}) =>
      enrichment.processQueue(onProgress: onProgress);

  /// Re-enqueue every event (used after a home-location change) and process.
  Future<void> reEnrichAll({void Function(int, int)? onProgress}) async {
    final ids = await db.select(db.migraineEvents).map((e) => e.id).get();
    for (final id in ids) {
      await enrichment.enqueue(id);
    }
    await enrichment.processQueue(onProgress: onProgress);
  }
}
