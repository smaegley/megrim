import 'package:drift/drift.dart';

import 'connection.dart';
import 'tables.dart';

part 'database.g.dart';

/// Vocabulary "kinds" (SPEC §3.4).
class VocabKind {
  static const trigger = 'trigger';
  static const headLocation = 'head_location';
  static const medication = 'medication';
}

/// Default seed vocabularies, carried over from the private app (SPEC §3.4).
/// `medication` starts empty and is learned from entries.
const List<String> kDefaultTriggers = [
  'Stress',
  'Sleep change',
  'Bright light',
  'Exercise',
  'Weather / pressure',
  'Alcohol',
  'Caffeine',
  'Food',
  'Hormonal',
  'Strong smell',
  'Screen time',
];

const List<String> kDefaultHeadLocations = [
  'Left temple',
  'Right temple',
  'Behind left eye',
  'Behind right eye',
  'Forehead',
  'Top of head',
  'Back of head',
  'Neck',
  'Both sides',
];

@DriftDatabase(
  tables: [MigraineEvents, DerivedFactors, AppSettings, Vocabularies],
)
class MegrimDatabase extends _$MegrimDatabase {
  MegrimDatabase() : super(openConnection());

  /// Test constructor allowing an in-memory or custom executor.
  MegrimDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          if (details.wasCreated) {
            await _seedVocabularies();
            await setSetting('schema_version', '1');
          }
        },
      );

  Future<void> _seedVocabularies() async {
    await batch((b) {
      for (var i = 0; i < kDefaultTriggers.length; i++) {
        b.insert(
          vocabularies,
          VocabulariesCompanion.insert(
            kind: VocabKind.trigger,
            value: kDefaultTriggers[i],
            sort: Value(i),
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
      for (var i = 0; i < kDefaultHeadLocations.length; i++) {
        b.insert(
          vocabularies,
          VocabulariesCompanion.insert(
            kind: VocabKind.headLocation,
            value: kDefaultHeadLocations[i],
            sort: Value(i),
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  // ── app_settings helpers ────────────────────────────────────────────────

  Future<String?> getSetting(String key) async {
    final row = await (select(appSettings)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) async {
    await into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(key: key, value: value),
    );
  }

  // ── vocab helpers ───────────────────────────────────────────────────────

  Future<List<String>> vocabValues(String kind) async {
    final rows = await (select(vocabularies)
          ..where((t) => t.kind.equals(kind))
          ..orderBy([
            (t) => OrderingTerm(expression: t.sort),
            (t) => OrderingTerm(expression: t.value),
          ]))
        .get();
    return rows.map((r) => r.value).toList();
  }

  Future<void> addVocab(String kind, String value) async {
    final existing = await vocabValues(kind);
    await into(vocabularies).insert(
      VocabulariesCompanion.insert(
        kind: kind,
        value: value,
        sort: Value(existing.length),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<void> renameVocab(String kind, String oldValue, String newValue) async {
    // Renames do NOT rewrite historical events (SPEC §3.4).
    await transaction(() async {
      final row = await (select(vocabularies)
            ..where((t) => t.kind.equals(kind) & t.value.equals(oldValue)))
          .getSingleOrNull();
      if (row == null) return;
      await (delete(vocabularies)
            ..where((t) => t.kind.equals(kind) & t.value.equals(oldValue)))
          .go();
      await into(vocabularies).insert(
        VocabulariesCompanion.insert(
          kind: kind,
          value: newValue,
          sort: Value(row.sort),
        ),
        mode: InsertMode.insertOrIgnore,
      );
    });
  }

  Future<void> deleteVocab(String kind, String value) async {
    await (delete(vocabularies)
          ..where((t) => t.kind.equals(kind) & t.value.equals(value)))
        .go();
  }
}
