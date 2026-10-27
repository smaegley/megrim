import 'package:drift/drift.dart';

import 'connection.dart';
import 'tables.dart';

part 'database.g.dart';

/// Vocabulary "kinds" (SPEC §3.4).
class VocabKind {
  static const trigger = 'trigger';
  static const headLocation = 'head_location';
  static const medication = 'medication';
  static const symptom = 'symptom';
}

/// Values of `migraine_events.impact` (schema v4, backlog #22a): how far the attack stopped the
/// user that day. Stored as these strings; ordered mildest first, so a day's impact is the
/// highest index among the attacks covering it.
class EventImpact {
  static const normal = 'normal';
  static const reduced = 'reduced';
  static const unable = 'unable';
  static const all = [normal, reduced, unable];
}

/// Default seed vocabularies, carried over from the private app (SPEC §3.4).
/// `medication` starts empty and is learned from entries.
/// Added to the default triggers in schema v3 (backlog #13) so travel can be self-reported like
/// any other trigger. Appended, never inserted mid-list: existing installs already have sort
/// values 0..n for the others, and an upgraded vocabulary should order the same as a fresh one.
const String kTravelTrigger = 'Travel';

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
  kTravelTrigger,
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

/// The symptom names an attack without headache is labelled by (backlog #26): "with vertigo"
/// when either is ticked. Matched by value, so a user who renames these loses the label — the
/// symptoms themselves are kept either way.
const String kSymptomVertigo = 'Vertigo';
const String kSymptomDizziness = 'Dizziness';

/// Default symptoms, seeded in schema v4 (backlog #20 + #26): the usual migraine symptoms plus
/// the ones that mark vestibular migraine and the prodrome / postdrome.
const List<String> kDefaultSymptoms = [
  'Nausea',
  'Vomiting',
  'Light sensitivity',
  'Sound sensitivity',
  'Smell sensitivity',
  'Neck pain / stiffness',
  kSymptomDizziness,
  kSymptomVertigo,
  'Motion sensitivity',
  'Fatigue',
  'Brain fog',
  'Yawning',
];

@DriftDatabase(
  tables: [MigraineEvents, DerivedFactors, AppSettings, Vocabularies],
)
class MegrimDatabase extends _$MegrimDatabase {
  MegrimDatabase() : super(openConnection());

  /// Test constructor allowing an in-memory or custom executor.
  MegrimDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // v2 (issue #17): per-event UTC offsets. Additive and nullable — existing rows keep
            // null and are bucketed in the phone's zone exactly as before.
            await m.addColumn(migraineEvents, migraineEvents.startedAtOffsetMin);
            await m.addColumn(migraineEvents, migraineEvents.endedAtOffsetMin);
          }
          if (from < 3) {
            // v3 (backlog #13): "Travel" joins the default triggers. _seedVocabularies only runs
            // on create, so existing installs need this one-time insert. insertOrIgnore can't
            // duplicate a "Travel" the user already added themselves, and because this runs once
            // it can't resurrect one they later delete (which seeding on every open would).
            await into(vocabularies).insert(
              VocabulariesCompanion.insert(
                kind: VocabKind.trigger,
                value: kTravelTrigger,
                sort: Value(kDefaultTriggers.indexOf(kTravelTrigger)),
              ),
              mode: InsertMode.insertOrIgnore,
            );
          }
          if (from < 4) {
            // v4 (backlog #20, #22a, #26): symptoms, impact, and whether there was a headache.
            // Additive and nullable — existing rows read as "headache, nothing else recorded".
            final existing = {
              for (final r in await customSelect('PRAGMA table_info(migraine_events)').get())
                r.read<String>('name'),
            };
            for (final c in [
              migraineEvents.headachePresent,
              migraineEvents.symptoms,
              migraineEvents.impact,
            ]) {
              // Guarded so a database whose user_version was rolled back by hand (the migration
              // tests do this) doesn't fail on a duplicate column.
              if (!existing.contains(c.name)) await m.addColumn(migraineEvents, c);
            }
            // Seeded once, like "Travel" in v3: insertOrIgnore keeps anything the user has.
            await _seedSymptoms();
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          if (details.wasCreated) {
            await _seedVocabularies();
          }
          if (details.wasCreated || details.hadUpgrade) {
            await setSetting('schema_version', '$schemaVersion');
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
    await _seedSymptoms();
  }

  Future<void> _seedSymptoms() async {
    await batch((b) {
      for (var i = 0; i < kDefaultSymptoms.length; i++) {
        b.insert(
          vocabularies,
          VocabulariesCompanion.insert(
            kind: VocabKind.symptom,
            value: kDefaultSymptoms[i],
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
