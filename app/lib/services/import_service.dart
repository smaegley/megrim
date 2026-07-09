import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/database.dart';
import 'export_format.dart';

class ImportResult {
  final int imported;
  final int skipped;
  final bool replaced;
  const ImportResult(
      {required this.imported, required this.skipped, required this.replaced});
}

class ImportException implements Exception {
  final String message;
  ImportException(this.message);
  @override
  String toString() => message;
}

/// Imports a Megrim JSON export (SPEC §7.3). v1 imports only this format.
///  - merge (default): insert events whose id is not already present; existing ids are skipped.
///  - replace: destructive — wipe all events/derived first (double-confirm in the UI).
/// Events missing a `derived` block are left without a derived row, so the enrichment queue picks
/// them up (a missing derived row counts as pending).
class ImportService {
  final MegrimDatabase db;
  ImportService(this.db);

  /// Decode raw file bytes as UTF-8 (export files are always UTF-8 JSON) before parsing, so
  /// non-ASCII text (accented labels, emoji in notes) round-trips correctly.
  Future<ImportResult> importJsonBytes(List<int> bytes, {bool replace = false}) {
    final String raw;
    try {
      raw = utf8.decode(bytes);
    } on FormatException {
      throw ImportException('File is not valid UTF-8 text.');
    }
    return importJsonString(raw, replace: replace);
  }

  Future<ImportResult> importJsonString(String raw, {bool replace = false}) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw ImportException('File is not valid JSON.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw ImportException('Unexpected file structure.');
    }
    return importJson(decoded, replace: replace);
  }

  Future<ImportResult> importJson(Map<String, dynamic> doc,
      {bool replace = false}) async {
    if (doc['format'] != kExportFormat) {
      throw ImportException('Not a Megrim export file.');
    }
    final version = doc['format_version'];
    if (version is! int || version > kExportFormatVersion) {
      throw ImportException(
          'Unsupported export version: $version (this app supports $kExportFormatVersion).');
    }

    final events = (doc['events'] as List?) ?? const [];
    var imported = 0;
    var skipped = 0;

    await db.transaction(() async {
      if (replace) {
        await db.delete(db.derivedFactors).go();
        await db.delete(db.migraineEvents).go();
      }

      final existing = replace
          ? <String>{}
          : (await db.select(db.migraineEvents).map((e) => e.id).get()).toSet();

      for (final raw in events) {
        if (raw is! Map) continue;
        final j = Map<String, dynamic>.from(raw);
        final id = j['id'];
        if (id is! String) continue;
        if (existing.contains(id)) {
          skipped++;
          continue;
        }
        try {
          final parsed = eventFromJson(j);
          await db.into(db.migraineEvents).insert(parsed.event);
          if (parsed.derived != null) {
            await db.into(db.derivedFactors).insert(parsed.derived!);
          }
        } on ImportException {
          rethrow;
        } catch (e) {
          throw ImportException('Event "$id" is malformed ($e). Nothing was imported.');
        }
        existing.add(id);
        imported++;
      }

      // Settings + vocab are applied on replace, or filled in if missing on merge.
      await _applySettingsAndVocab(doc, replace: replace);
    });

    return ImportResult(imported: imported, skipped: skipped, replaced: replace);
  }

  Future<void> _applySettingsAndVocab(Map<String, dynamic> doc,
      {required bool replace}) async {
    final settings = doc['settings'];
    if (settings is Map && settings['home_location'] != null) {
      final hasHome = await db.getSetting('home_location') != null;
      if (replace || !hasHome) {
        await db.setSetting(
            'home_location', jsonEncode(settings['home_location']));
      }
    }

    final vocab = doc['vocabularies'];
    if (vocab is Map) {
      for (final entry in {
        'trigger': VocabKind.trigger,
        'head_location': VocabKind.headLocation,
        'medication': VocabKind.medication,
      }.entries) {
        final values = vocab[entry.key];
        if (values is List) {
          for (var i = 0; i < values.length; i++) {
            await db.into(db.vocabularies).insert(
                  VocabulariesCompanion.insert(
                    kind: entry.value,
                    value: values[i].toString(),
                    sort: Value(i),
                  ),
                  mode: InsertMode.insertOrIgnore,
                );
          }
        }
      }
    }
  }
}
