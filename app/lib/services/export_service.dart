import 'dart:convert';

import '../database/database.dart';
import '../models/json_fields.dart';
import 'export_format.dart';

/// Builds the full-fidelity JSON backup (SPEC §7.1) and the analysis-friendly CSV (§7.2).
class ExportService {
  final MegrimDatabase db;
  final String appVersion;

  ExportService({required this.db, this.appVersion = '0.1.0'});

  /// The complete export document as a map.
  Future<Map<String, dynamic>> buildExport({DateTime? now}) async {
    final events = await db.select(db.migraineEvents).get();
    final derived = await db.select(db.derivedFactors).get();
    final derivedById = {for (final d in derived) d.eventId: d};

    final home = await db.getSetting('home_location');

    return {
      'format': kExportFormat,
      'format_version': kExportFormatVersion,
      'exported_at': (now ?? DateTime.now().toUtc()).toIso8601String(),
      'app_version': appVersion,
      'settings': {
        if (home != null) 'home_location': jsonDecode(home),
      },
      'vocabularies': {
        'trigger': await db.vocabValues(VocabKind.trigger),
        'head_location': await db.vocabValues(VocabKind.headLocation),
        'medication': await db.vocabValues(VocabKind.medication),
      },
      'events': [
        for (final e in events) eventToJson(e, derivedById[e.id]),
      ],
    };
  }

  Future<String> toJsonString({DateTime? now}) async =>
      const JsonEncoder.withIndent('  ').convert(await buildExport(now: now));

  /// Suggested filename: megrim-export-YYYYMMDD.json
  static String jsonFilename(DateTime now) =>
      'megrim-export-${now.year.toString().padLeft(4, '0')}'
      '${now.month.toString().padLeft(2, '0')}'
      '${now.day.toString().padLeft(2, '0')}.json';

  static const List<String> _csvHeader = [
    'id', 'started_at', 'ended_at', 'severity', 'location_head', 'aura_present',
    'aura_description', 'meds_taken', 'triggers_suspected', 'sleep_hours_prior',
    'stress_level', 'foods_notable', 'notes', 'geo_lat', 'geo_lon', 'geo_label',
    'day_of_week', 'season', 'time_of_day_bucket', 'daylight_hours', 'moon_phase',
    'moon_illumination', 'temp_c', 'humidity_pct', 'pressure_hpa',
    'precipitation_mm', 'pressure_delta_24h', 'pressure_delta_48h', 'aqi' //
  ];

  /// One row per event; arrays joined with ';'; derived columns flattened (SPEC §7.2).
  Future<String> toCsv() async {
    final events = await db.select(db.migraineEvents).get();
    final derived = await db.select(db.derivedFactors).get();
    final derivedById = {for (final d in derived) d.eventId: d};

    final buf = StringBuffer()..writeln(_csvHeader.map(_csv).join(','));
    for (final e in events) {
      final d = derivedById[e.id];
      final meds = decodeMeds(e.medsTaken)
          .map((m) => [m.name, if (m.dose != null) m.dose].join(' '))
          .join(';');
      final row = [
        e.id,
        e.startedAt.toUtc().toIso8601String(),
        e.endedAt?.toUtc().toIso8601String() ?? '',
        e.severity?.toString() ?? '',
        decodeStringList(e.locationHead).join(';'),
        e.auraPresent?.toString() ?? '',
        e.auraDescription ?? '',
        meds,
        decodeStringList(e.triggersSuspected).join(';'),
        e.sleepHoursPrior?.toString() ?? '',
        e.stressLevel?.toString() ?? '',
        decodeStringList(e.foodsNotable).join(';'),
        e.notes ?? '',
        e.geoLat?.toString() ?? '',
        e.geoLon?.toString() ?? '',
        e.geoLabel ?? '',
        d?.dayOfWeek?.toString() ?? '',
        d?.season ?? '',
        d?.timeOfDayBucket ?? '',
        d?.daylightHours?.toString() ?? '',
        d?.moonPhase ?? '',
        d?.moonIllumination?.toString() ?? '',
        d?.tempC?.toString() ?? '',
        d?.humidityPct?.toString() ?? '',
        d?.pressureHpa?.toString() ?? '',
        d?.precipitationMm?.toString() ?? '',
        d?.pressureDelta24h?.toString() ?? '',
        d?.pressureDelta48h?.toString() ?? '',
        d?.aqi?.toString() ?? '',
      ];
      buf.writeln(row.map(_csv).join(','));
    }
    return buf.toString();
  }

  static String csvFilename(DateTime now) =>
      'megrim-export-${now.year.toString().padLeft(4, '0')}'
      '${now.month.toString().padLeft(2, '0')}'
      '${now.day.toString().padLeft(2, '0')}.csv';

  /// RFC-4180 field escaping.
  static String _csv(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }
}
