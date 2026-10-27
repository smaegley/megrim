import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/models/json_fields.dart';
import 'package:megrim/services/export_service.dart';
import 'package:megrim/services/import_service.dart';

/// Backlog #20 (symptoms), #22a (impact on the day) and #26 (attacks without headache), which
/// share schema v4.
final t0 = DateTime.utc(2026, 10, 1, 9);

MigraineEventsCompanion ev(String id,
        {bool? headache, List<String> symptoms = const [], String? impact, int? severity}) =>
    MigraineEventsCompanion.insert(
      id: id,
      startedAt: t0,
      createdAt: t0,
      updatedAt: t0,
      headachePresent: Value(headache),
      symptoms: Value(encodeStringList(symptoms)),
      impact: Value(impact),
      severity: Value(severity),
    );

void main() {
  group('schema v4', () {
    test('a fresh install seeds the default symptoms in order', () async {
      final db = MegrimDatabase.forTesting(NativeDatabase.memory());
      expect(await db.vocabValues(VocabKind.symptom), kDefaultSymptoms);
      expect(kDefaultSymptoms, containsAll([kSymptomVertigo, kSymptomDizziness]));
      await db.close();
    });

    test('v3 -> v4 adds the columns, keeps rows, and seeds symptoms once', () async {
      final dir = Directory.systemTemp.createTempSync('megrim-v4');
      final file = File('${dir.path}/v3.sqlite');

      // Build a current database, then demote it to v3 by hand (SQLite >= 3.35 DROP COLUMN).
      final v4 = MegrimDatabase.forTesting(NativeDatabase(file));
      await v4.into(v4.migraineEvents).insert(MigraineEventsCompanion.insert(
          id: 'old', startedAt: t0, severity: const Value(6), createdAt: t0, updatedAt: t0));
      await v4.customStatement("DELETE FROM vocabularies WHERE kind = 'symptom'");
      for (final c in ['headache_present', 'symptoms', 'impact']) {
        await v4.customStatement('ALTER TABLE migraine_events DROP COLUMN $c');
      }
      await v4.customStatement('PRAGMA user_version = 3');
      await v4.close();

      final upgraded = MegrimDatabase.forTesting(NativeDatabase(file));
      final old = (await upgraded.select(upgraded.migraineEvents).get()).single;
      expect(old.severity, 6);
      expect(old.headachePresent, isNull, reason: 'old rows read as "not recorded"');
      expect(old.symptoms, isNull);
      expect(old.impact, isNull);
      expect(await upgraded.vocabValues(VocabKind.symptom), kDefaultSymptoms);
      expect(await upgraded.getSetting('schema_version'), '4');
      await upgraded.close();
      dir.deleteSync(recursive: true);
    });

    test('the upgrade keeps symptoms the user already has', () async {
      final dir = Directory.systemTemp.createTempSync('megrim-v4b');
      final file = File('${dir.path}/v3.sqlite');
      final v4 = MegrimDatabase.forTesting(NativeDatabase(file));
      await v4.customStatement("DELETE FROM vocabularies WHERE kind = 'symptom'");
      await v4.addVocab(VocabKind.symptom, 'Fatigue');
      await v4.addVocab(VocabKind.symptom, 'Jaw pain');
      await v4.customStatement('PRAGMA user_version = 3');
      await v4.close();

      final upgraded = MegrimDatabase.forTesting(NativeDatabase(file));
      final symptoms = await upgraded.vocabValues(VocabKind.symptom);
      expect(symptoms.where((s) => s == 'Fatigue'), hasLength(1));
      expect(symptoms, contains('Jaw pain'));
      await upgraded.close();
      dir.deleteSync(recursive: true);
    });
  });

  group('export / import', () {
    test('the new fields round-trip through JSON, including null / true / false', () async {
      final src = MegrimDatabase.forTesting(NativeDatabase.memory());
      await src.into(src.migraineEvents).insert(ev('a',
          headache: false, symptoms: ['Fatigue', 'Brain fog'], impact: EventImpact.reduced));
      await src.into(src.migraineEvents).insert(ev('b', headache: true, severity: 7));
      await src.into(src.migraineEvents).insert(ev('c'));
      await src.addVocab(VocabKind.symptom, 'Jaw pain');
      final json = await ExportService(db: src).toJsonString();

      final byId = {
        for (final e in (jsonDecode(json)['events'] as List).cast<Map<String, dynamic>>())
          e['id']: e,
      };
      expect(byId['a']!['headache_present'], false);
      expect(byId['a']!['symptoms'], ['Fatigue', 'Brain fog']);
      expect(byId['a']!['impact'], 'reduced');
      expect(byId['b']!['headache_present'], true);
      expect(byId['c']!['headache_present'], isNull);
      expect(byId['c']!['symptoms'], isEmpty);
      expect((jsonDecode(json)['vocabularies'] as Map)['symptom'], contains('Jaw pain'));

      final dst = MegrimDatabase.forTesting(NativeDatabase.memory());
      await ImportService(dst).importJsonString(json, replace: true);
      final rows = {for (final r in await dst.select(dst.migraineEvents).get()) r.id: r};
      expect(rows['a']!.headachePresent, false);
      expect(decodeStringList(rows['a']!.symptoms), ['Fatigue', 'Brain fog']);
      expect(rows['a']!.impact, EventImpact.reduced);
      expect(rows['b']!.headachePresent, true);
      expect(rows['c']!.headachePresent, isNull);
      expect(rows['c']!.symptoms, isNull);
      expect(await dst.vocabValues(VocabKind.symptom), contains('Jaw pain'));
      await src.close();
      await dst.close();
    });

    test('an older file without the fields imports, and an unknown impact is dropped', () async {
      final dst = MegrimDatabase.forTesting(NativeDatabase.memory());
      await ImportService(dst).importJsonString(
          jsonEncode({
            'format': 'megrim-export',
            'format_version': 1,
            'events': [
              {'id': 'old', 'started_at': '2024-06-11T03:00:00Z', 'severity': 5},
              {'id': 'odd', 'started_at': '2024-06-12T03:00:00Z', 'impact': 'catastrophic'},
            ],
          }),
          replace: true);
      final rows = {for (final r in await dst.select(dst.migraineEvents).get()) r.id: r};
      expect(rows['old']!.headachePresent, isNull);
      expect(rows['old']!.symptoms, isNull);
      expect(rows['odd']!.impact, isNull);
      await dst.close();
    });

    test('CSV appends the three columns after the existing ones', () async {
      final db = MegrimDatabase.forTesting(NativeDatabase.memory());
      await db.into(db.migraineEvents).insert(
          ev('a', headache: false, symptoms: ['Vertigo', 'Nausea'], impact: EventImpact.unable));
      final lines = (await ExportService(db: db).toCsv()).trim().split('\n');
      expect(lines.first, endsWith('ended_at_offset_minutes,headache_present,symptoms,impact'));
      expect(lines[1], endsWith(',false,Vertigo;Nausea,unable'));
      await db.close();
    });
  });
}
