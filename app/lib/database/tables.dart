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

  /// UTC offset (minutes east of UTC) of the zone the event was logged in — issue #17. Every
  /// local-calendar bucket (weekday, migraine-day, time of day, season, the History calendar) is
  /// taken from this, so an entry stays on the day it actually happened even when Analytics runs
  /// in another zone. Null on rows from before schema v2 and on imports that carry no offset;
  /// those fall back to the phone's current zone (the pre-v2 behaviour).
  IntColumn get startedAtOffsetMin => integer().nullable()();
  IntColumn get endedAtOffsetMin => integer().nullable()();

  /// Schema v4 (backlog #26). Tri-state: true / false / null(unknown). False marks an attack
  /// without headache (aura only, vertigo, the fatigue phase with no pain); null is treated as a
  /// headache everywhere, so rows from before v4 count exactly as they did.
  BoolColumn get headachePresent => boolean().nullable()();

  /// Schema v4 (backlog #20). JSON array of strings (vocab: symptom).
  TextColumn get symptoms => text().nullable()();

  /// Schema v4 (backlog #22a). One of [EventImpact]'s values, or null when not recorded.
  TextColumn get impact => text().nullable()();

  /// Schema v5 (backlog #19). JSON: [{name, helped}] (vocab: relief) — non-drug relief tried.
  TextColumn get reliefTried => text().nullable()();

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

/// §3.4 — user-editable option lists. kinds: trigger, head_location, medication, symptom, relief.
class Vocabularies extends Table {
  TextColumn get kind => text()();
  TextColumn get value => text()();
  IntColumn get sort => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {kind, value};
}

/// Schema v5 (backlog #18): the class of each acute medication, keyed by the name as entered on
/// events. Kept apart from [Vocabularies] so renaming or deleting a suggestion never loses the
/// class that past entries are counted by.
class MedicationClasses extends Table {
  TextColumn get name => text()();

  /// One of `MedClass`'s values.
  TextColumn get medClass => text()();

  @override
  Set<Column> get primaryKey => {name};
}

/// Schema v5 (backlog #19): preventive medications, taken daily and judged over months, so they
/// are a regimen with dates rather than something logged per attack.
class PreventiveRegimens extends Table {
  /// UUIDv4, client-generated.
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get dose => text().nullable()();

  /// Calendar dates as `yyyy-MM-dd`: a regimen starts on a day, not at an instant, so no zone.
  TextColumn get startedOn => text()();

  /// null = still taking it.
  TextColumn get stoppedOn => text().nullable()();
  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Schema v6 (backlog #16): a "No migraine today" check-in. A row's presence means the day was
/// clear; a day with a migraine entry wins over a check-in for the same date everywhere. Carries
/// the same optional self-report fields as an event, so they have a clear-day baseline.
class DayCheckins extends Table {
  /// The wall-clock date, `yyyy-MM-dd`, in the zone it was logged in.
  TextColumn get localDate => text()();

  /// UTC offset (minutes east) of that zone, as on events (issue #17).
  IntColumn get offsetMin => integer().nullable()();

  /// JSON array of strings (vocab: trigger).
  TextColumn get triggersSuspected => text().nullable()();
  RealColumn get sleepHoursPrior => real().nullable()();

  /// 1–5.
  IntColumn get stressLevel => integer().nullable()();

  /// JSON array of strings.
  TextColumn get foodsNotable => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {localDate};
}
