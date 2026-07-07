import 'package:drift/drift.dart';

/// Schema v1 (SPEC §3). All timestamps are stored in UTC; display converts to local.
/// JSON-array/object fields are stored as TEXT and encoded/decoded in the repository layer.

/// §3.1 — one row per logged migraine. User-owned, editable.
class MigraineEvents extends Table {
  /// UUIDv4, client-generated.
  TextColumn get id => text()();

  DateTimeColumn get startedAt => dateTime()();

  /// null = ongoing.
  DateTimeColumn get endedAt => dateTime().nullable()();

  /// 1–10.
  IntColumn get severity => integer().nullable()();

  /// JSON array of strings (vocab: head_location).
  TextColumn get locationHead => text().nullable()();

  /// Tri-state: true / false / null(unknown).
  BoolColumn get auraPresent => boolean().nullable()();
  TextColumn get auraDescription => text().nullable()();

  /// JSON: [{name, dose, time, helped}].
  TextColumn get medsTaken => text().nullable()();

  /// JSON array of strings (vocab: trigger).
  TextColumn get triggersSuspected => text().nullable()();

  RealColumn get sleepHoursPrior => real().nullable()();

  /// 1–5.
  IntColumn get stressLevel => integer().nullable()();

  /// JSON array of strings.
  TextColumn get foodsNotable => text().nullable()();

  TextColumn get notes => text().nullable()();

  /// Rounded to 2 decimals (~1 km) at capture time — precise coords are never stored.
  RealColumn get geoLat => real().nullable()();
  RealColumn get geoLon => real().nullable()();
  TextColumn get geoLabel => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// §3.2 — computed enrichment, 1:1 with events, never user-edited.
class DerivedFactors extends Table {
  TextColumn get eventId =>
      text().references(MigraineEvents, #id, onDelete: KeyAction.cascade)();

  /// 0=Mon .. 6=Sun, local date of startedAt.
  IntColumn get dayOfWeek => integer().nullable()();

  /// Meteorological season, hemisphere-aware.
  TextColumn get season => text().nullable()();

  /// morning / afternoon / evening / night (local).
  TextColumn get timeOfDayBucket => text().nullable()();

  RealColumn get daylightHours => real().nullable()();
  DateTimeColumn get sunriseUtc => dateTime().nullable()();
  DateTimeColumn get sunsetUtc => dateTime().nullable()();

  /// One of 8 named phases.
  TextColumn get moonPhase => text().nullable()();

  /// 0–1.
  RealColumn get moonIllumination => real().nullable()();

  RealColumn get tempC => real().nullable()();
  RealColumn get humidityPct => real().nullable()();
  RealColumn get pressureHpa => real().nullable()();
  RealColumn get precipitationMm => real().nullable()();

  RealColumn get pressureDelta24h => real().nullable()();
  RealColumn get pressureDelta48h => real().nullable()();

  IntColumn get aqi => integer().nullable()();

  /// null / partial ⇒ row is in the enrichment retry queue.
  DateTimeColumn get enrichedAt => dateTime().nullable()();

  /// Last failure reason, surfaced in UI.
  TextColumn get enrichError => text().nullable()();

  @override
  Set<Column> get primaryKey => {eventId};
}

/// §3.3 — key/value settings, values are JSON strings.
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// §3.4 — user-editable option lists. kinds: trigger, head_location, medication.
class Vocabularies extends Table {
  TextColumn get kind => text()();
  TextColumn get value => text()();
  IntColumn get sort => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {kind, value};
}
