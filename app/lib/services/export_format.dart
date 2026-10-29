import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/database.dart';
import '../models/json_fields.dart';
import '../models/medications.dart' show isoDay, parseIsoDay;

/// Pure (de)serialization for the Megrim export format (SPEC §7.1). Kept separate from file/IO so
/// the DB → JSON → DB round-trip can be property-tested with no filesystem or network.

const String kExportFormat = 'megrim-export';
const int kExportFormatVersion = 1;

String? _iso(DateTime? t) => t?.toUtc().toIso8601String();
DateTime? _parseIso(dynamic v) =>
    (v is String && v.isNotEmpty) ? DateTime.parse(v).toUtc() : null;

/// UTC offset carried by an ISO-8601 string's own `+hh:mm`/`-hh:mm` suffix, or null for `Z` /
/// bare local stamps. Lets an external file's explicit offsets survive import (issue #17).
int? _offsetFromIso(dynamic v) {
  if (v is! String) return null;
  final m = RegExp(r'([+-])(\d{2}):?(\d{2})$').firstMatch(v.trim());
  if (m == null) return null;
  final sign = m.group(1) == '-' ? -1 : 1;
  return sign * (int.parse(m.group(2)!) * 60 + int.parse(m.group(3)!));
}

int? _offsetField(Map<String, dynamic> j, String key, String isoKey) {
  final v = j[key];
  if (v is num) return v.toInt();
  return _offsetFromIso(j[isoKey]);
}

/// Serialize an event and its derived factors to a JSON-ready map. Array/object columns are
/// emitted as real JSON arrays/objects rather than the stringified DB form.
Map<String, dynamic> eventToJson(MigraineEvent e, DerivedFactor? d) {
  return {
    'id': e.id,
    'started_at': _iso(e.startedAt),
    'ended_at': _iso(e.endedAt),
    'started_at_offset_minutes': e.startedAtOffsetMin,
    'ended_at_offset_minutes': e.endedAtOffsetMin,
    'headache_present': e.headachePresent,
    'severity': e.severity,
    'location_head': decodeStringList(e.locationHead),
    'aura_present': e.auraPresent,
    'aura_description': e.auraDescription,
    'symptoms': decodeStringList(e.symptoms),
    'impact': e.impact,
    'meds_taken': decodeMeds(e.medsTaken).map((m) => m.toJson()).toList(),
    'relief_tried': decodeRelief(e.reliefTried).map((r) => r.toJson()).toList(),
    'triggers_suspected': decodeStringList(e.triggersSuspected),
    'sleep_hours_prior': e.sleepHoursPrior,
    'stress_level': e.stressLevel,
    'foods_notable': decodeStringList(e.foodsNotable),
    'notes': e.notes,
    'geo_lat': e.geoLat,
    'geo_lon': e.geoLon,
    'geo_label': e.geoLabel,
    'created_at': _iso(e.createdAt),
    'updated_at': _iso(e.updatedAt),
    if (d != null) 'derived': _derivedToJson(d),
  };
}

Map<String, dynamic> _derivedToJson(DerivedFactor d) => {
      'day_of_week': d.dayOfWeek,
      'season': d.season,
      'time_of_day_bucket': d.timeOfDayBucket,
      'daylight_hours': d.daylightHours,
      'sunrise_utc': _iso(d.sunriseUtc),
      'sunset_utc': _iso(d.sunsetUtc),
      'moon_phase': d.moonPhase,
      'moon_illumination': d.moonIllumination,
      'temp_c': d.tempC,
      'humidity_pct': d.humidityPct,
      'pressure_hpa': d.pressureHpa,
      'precipitation_mm': d.precipitationMm,
      'pressure_delta_24h': d.pressureDelta24h,
      'pressure_delta_48h': d.pressureDelta48h,
      'aqi': d.aqi,
      'enriched_at': _iso(d.enrichedAt),
      'enrich_error': d.enrichError,
    };

/// Rebuild insert companions from an exported event map.
({MigraineEventsCompanion event, DerivedFactorsCompanion? derived})
    eventFromJson(Map<String, dynamic> j) {
  final id = j['id'] as String;
  final event = MigraineEventsCompanion.insert(
    id: id,
    startedAt: _parseIso(j['started_at'])!,
    endedAt: Value(_parseIso(j['ended_at'])),
    startedAtOffsetMin:
        Value(_offsetField(j, 'started_at_offset_minutes', 'started_at')),
    endedAtOffsetMin: Value(_offsetField(j, 'ended_at_offset_minutes', 'ended_at')),
    headachePresent: Value(j['headache_present'] as bool?),
    severity: Value(j['severity'] as int?),
    locationHead: Value(encodeStringList(_strList(j['location_head']))),
    auraPresent: Value(j['aura_present'] as bool?),
    auraDescription: Value(j['aura_description'] as String?),
    symptoms: Value(encodeStringList(_strList(j['symptoms']))),
    impact: Value(_impact(j['impact'])),
    medsTaken: Value(_encodeMedsRaw(j['meds_taken'])),
    reliefTried: Value(_encodeMedsRaw(j['relief_tried'])),
    triggersSuspected: Value(encodeStringList(_strList(j['triggers_suspected']))),
    sleepHoursPrior: Value((j['sleep_hours_prior'] as num?)?.toDouble()),
    stressLevel: Value(j['stress_level'] as int?),
    foodsNotable: Value(encodeStringList(_strList(j['foods_notable']))),
    notes: Value(j['notes'] as String?),
    geoLat: Value((j['geo_lat'] as num?)?.toDouble()),
    geoLon: Value((j['geo_lon'] as num?)?.toDouble()),
    geoLabel: Value(j['geo_label'] as String?),
    createdAt: _parseIso(j['created_at']) ?? DateTime.now().toUtc(),
    updatedAt: _parseIso(j['updated_at']) ?? DateTime.now().toUtc(),
  );

  DerivedFactorsCompanion? derived;
  final dj = j['derived'];
  if (dj is Map) {
    final d = Map<String, dynamic>.from(dj);
    derived = DerivedFactorsCompanion(
      eventId: Value(id),
      dayOfWeek: Value(d['day_of_week'] as int?),
      season: Value(d['season'] as String?),
      timeOfDayBucket: Value(d['time_of_day_bucket'] as String?),
      daylightHours: Value((d['daylight_hours'] as num?)?.toDouble()),
      sunriseUtc: Value(_parseIso(d['sunrise_utc'])),
      sunsetUtc: Value(_parseIso(d['sunset_utc'])),
      moonPhase: Value(d['moon_phase'] as String?),
      moonIllumination: Value((d['moon_illumination'] as num?)?.toDouble()),
      tempC: Value((d['temp_c'] as num?)?.toDouble()),
      humidityPct: Value((d['humidity_pct'] as num?)?.toDouble()),
      pressureHpa: Value((d['pressure_hpa'] as num?)?.toDouble()),
      precipitationMm: Value((d['precipitation_mm'] as num?)?.toDouble()),
      pressureDelta24h: Value((d['pressure_delta_24h'] as num?)?.toDouble()),
      pressureDelta48h: Value((d['pressure_delta_48h'] as num?)?.toDouble()),
      aqi: Value(d['aqi'] as int?),
      enrichedAt: Value(_parseIso(d['enriched_at'])),
      enrichError: Value(d['enrich_error'] as String?),
    );
  }
  return (event: event, derived: derived);
}

/// An unrecognised impact value (a newer app, a hand-edited file) is dropped rather than stored,
/// so the column only ever holds the values the app understands.
String? _impact(dynamic v) => EventImpact.all.contains(v) ? v as String : null;

List<String> _strList(dynamic v) =>
    v is List ? v.map((e) => e.toString()).toList() : const [];

/// Medication classes (schema v5, backlog #18) as exported: name → class. Unknown classes are
/// dropped, like an unknown impact.
Map<String, dynamic> medicationClassesToJson(Map<String, String> classes) =>
    {for (final name in classes.keys.toList()..sort()) name: classes[name]};

Map<String, String> medicationClassesFromJson(dynamic v) => {
      if (v is Map)
        for (final MapEntry(:key, :value) in v.entries)
          if (MedClass.all.contains(value)) key.toString(): value as String,
    };

/// A preventive regimen (schema v5, backlog #19). Dates stay `yyyy-MM-dd`.
Map<String, dynamic> preventiveToJson(PreventiveRegimen p) => {
      'id': p.id,
      'name': p.name,
      'dose': p.dose,
      'started_on': p.startedOn,
      'stopped_on': p.stoppedOn,
      'notes': p.notes,
      'created_at': _iso(p.createdAt),
      'updated_at': _iso(p.updatedAt),
    };

/// Null when the entry lacks an id, a name or a valid start date.
PreventiveRegimensCompanion? preventiveFromJson(Map<String, dynamic> j) {
  final id = j['id'], name = j['name'];
  final started = _isoDayOrNull(j['started_on']);
  if (id is! String || name is! String || name.trim().isEmpty || started == null) return null;
  return PreventiveRegimensCompanion.insert(
    id: id,
    name: name.trim(),
    dose: Value(j['dose'] as String?),
    startedOn: started,
    stoppedOn: Value(_isoDayOrNull(j['stopped_on'])),
    notes: Value(j['notes'] as String?),
    createdAt: _parseIso(j['created_at']) ?? DateTime.now().toUtc(),
    updatedAt: _parseIso(j['updated_at']) ?? DateTime.now().toUtc(),
  );
}

String? _isoDayOrNull(dynamic v) {
  final d = v is String ? parseIsoDay(v) : null;
  return d == null ? null : isoDay(d);
}

String? _encodeMedsRaw(dynamic v) {
  if (v is! List || v.isEmpty) return null;
  // Re-encode straight from the exported maps to preserve the exact structure.
  return jsonEncode(v);
}
