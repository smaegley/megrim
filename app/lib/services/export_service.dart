import 'dart:convert';

import '../database/database.dart';
import '../legal.dart' show kAppVersion;
import '../models/json_fields.dart';
import 'export_format.dart';

/// Builds the full-fidelity JSON backup (SPEC §7.1) and the analysis-friendly CSV (§7.2).
class ExportService {
  final MegrimDatabase db;
  final String appVersion;

  ExportService({required this.db, this.appVersion = kAppVersion});

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
      // Free-text columns (user-authored, or passed through from an external geocoder) use
      // _csvSafeText to guard against CSV/formula injection; numeric/enum/date columns use plain
      // _csv (they're never user-authored and can legitimately start with '-', e.g. a negative
      // pressure delta, which _csvSafeText would otherwise misinterpret as a formula prefix).
      final row = [
        _csv(e.id),
        _csv(e.startedAt.toUtc().toIso8601String()),
        _csv(e.endedAt?.toUtc().toIso8601String() ?? ''),
        _csv(e.severity?.toString() ?? ''),
        _csvSafeText(decodeStringList(e.locationHead).join(';')),
        _csv(e.auraPresent?.toString() ?? ''),
        _csvSafeText(e.auraDescription ?? ''),
        _csvSafeText(meds),
        _csvSafeText(decodeStringList(e.triggersSuspected).join(';')),
        _csv(e.sleepHoursPrior?.toString() ?? ''),
        _csv(e.stressLevel?.toString() ?? ''),
        _csvSafeText(decodeStringList(e.foodsNotable).join(';')),
        _csvSafeText(e.notes ?? ''),
        _csv(e.geoLat?.toString() ?? ''),
        _csv(e.geoLon?.toString() ?? ''),
        _csvSafeText(e.geoLabel ?? ''),
        _csv(d?.dayOfWeek?.toString() ?? ''),
        _csv(d?.season ?? ''),
        _csv(d?.timeOfDayBucket ?? ''),
        _csv(d?.daylightHours?.toString() ?? ''),
        _csv(d?.moonPhase ?? ''),
        _csv(d?.moonIllumination?.toString() ?? ''),
        _csv(d?.tempC?.toString() ?? ''),
        _csv(d?.humidityPct?.toString() ?? ''),
        _csv(d?.pressureHpa?.toString() ?? ''),
        _csv(d?.precipitationMm?.toString() ?? ''),
        _csv(d?.pressureDelta24h?.toString() ?? ''),
        _csv(d?.pressureDelta48h?.toString() ?? ''),
        _csv(d?.aqi?.toString() ?? ''),
      ];
      buf.writeln(row.join(','));
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

  /// CSV/formula-injection guard (OWASP): a field opened in a spreadsheet that starts with
  /// `=`, `+`, `-`, `@`, tab, or CR can be interpreted as a formula. Prefix with a single quote —
  /// spreadsheet apps render that as literal text — before the normal RFC-4180 escaping. Only
  /// apply this to free-text fields (see call sites); numeric columns can legitimately start
  /// with '-' and must not be mangled.
  static String _csvSafeText(String v) {
    if (v.isNotEmpty && '=+-@\t\r'.contains(v[0])) {
      return _csv("'$v");
    }
    return _csv(v);
  }
}
