import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/analytics/dashboard.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/models/json_fields.dart';
import 'package:megrim/repositories/megrim_repository.dart';
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
      expect(await upgraded.getSetting('schema_version'), '${upgraded.schemaVersion}');
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
      expect(lines.first, contains('ended_at_offset_minutes,headache_present,symptoms,impact,'));
      expect(lines[1], endsWith(',false,Vertigo;Nausea,unable,'));
      await db.close();
    });
  });

  group('analytics', () {
    // Noon UTC with a UTC offset of 0, so every event sits on its own calendar day.
    DateTime day(int d) => DateTime.utc(2026, 10, d, 12);
    final now = DateTime(2026, 10, 20, 18);
    EventStat stat(int d,
            {bool? headache,
            int? severity,
            String? impact,
            bool? aura,
            List<String> symptoms = const [],
            int hours = 2}) =>
        EventStat(
          startedAt: day(d),
          endedAt: day(d).add(Duration(hours: hours)),
          startOffsetMin: 0,
          endOffsetMin: 0,
          headachePresent: headache,
          severity: severity,
          impact: impact,
          aura: aura,
          symptoms: symptoms,
        );

    test('headache-free days count as migraine days and are split out; a day with both '
        'kinds counts once, as a headache day', () {
      final r = migraineDays([
        stat(1, headache: true),
        stat(3, headache: false),
        stat(5, headache: false),
        stat(5), // null = headache
        stat(7, headache: false),
        stat(7, headache: false), // two headache-free on one day: still one day
      ], now);
      expect(r.last30, 4);
      expect(r.last30WithoutHeadache, 2);
      final oct = r.byMonth.last;
      expect([oct.days, oct.daysWithoutHeadache], [4, 2]);
    });

    test('average severity leaves out attacks without headache, even if one carries a number',
        () {
      final d = computeDashboard([
        stat(1, severity: 8),
        stat(2, severity: 4, headache: true),
        stat(3, severity: 2, headache: false), // e.g. an imported file
      ], now: now);
      expect(d.summary.avgSeverity, 6.0);
      expect(d.byYear.single.avgSeverity, 6.0);
      expect(d.migraineDaysWithoutHeadacheLast30, 1);
    });

    test('impact days take the worst impact on each day, and count recorded days', () {
      final r = impactDays([
        stat(1, impact: EventImpact.reduced),
        stat(1, impact: EventImpact.unable),
        stat(2, impact: EventImpact.reduced),
        stat(3, impact: EventImpact.normal),
        stat(4), // a migraine day with nothing recorded
      ], now)!;
      expect(r.unableLast30, 1);
      expect(r.reducedLast30, 1);
      expect(r.recordedLast30, 3);
      expect(r.avgUnableLast3Months, isNull, reason: 'no complete months yet');
      expect(impactDays([stat(1), stat(2)], now), isNull);
    });

    test('impact averages need 3 complete months, like migraine days', () {
      final r = impactDays([
        EventStat(
            startedAt: DateTime.utc(2026, 7, 2, 12),
            startOffsetMin: 0,
            impact: EventImpact.unable),
        EventStat(
            startedAt: DateTime.utc(2026, 9, 2, 12),
            startOffsetMin: 0,
            impact: EventImpact.unable),
        EventStat(
            startedAt: DateTime.utc(2026, 9, 9, 12),
            startOffsetMin: 0,
            impact: EventImpact.reduced),
      ], now)!;
      expect(r.avgUnableLast3Months, 0.7); // (1 + 0 + 1) / 3
      expect(r.avgReducedLast3Months, 0.3);
    });

    test('impact averages count from the first impact, not the first entry', () {
      final r = impactDays([
        // Years of entries from before impact could be recorded...
        EventStat(startedAt: DateTime.utc(2024, 1, 5, 12), startOffsetMin: 0),
        // ...then the first impact, too recent for 3 complete months.
        EventStat(
            startedAt: DateTime.utc(2026, 9, 2, 12),
            startOffsetMin: 0,
            impact: EventImpact.unable),
      ], now)!;
      expect(r.avgUnableLast3Months, isNull, reason: 'not 0.3 over months nobody could record');
      expect(r.avgReducedLast3Months, isNull);
    });

    test('attacks without headache are summarised by kind, symptoms and median length', () {
      final d = computeDashboard([
        stat(1, headache: false, aura: true, symptoms: [kSymptomVertigo], hours: 1),
        stat(2, headache: false, symptoms: [kSymptomDizziness, 'Fatigue'], hours: 3),
        stat(3, headache: false, symptoms: ['Fatigue', 'Brain fog'], hours: 10),
        stat(4, headache: false, symptoms: ['Fatigue'], hours: 6),
        stat(5, symptoms: ['Nausea']),
      ], now: now);
      final w = d.withoutHeadache!;
      expect([w.events, w.totalEvents, w.pct], [4, 5, 80.0]);
      expect([w.withAura, w.withVertigo, w.other], [1, 1, 2],
          reason: 'aura wins over vertigo on the same attack');
      expect(w.symptoms.first.label, 'Fatigue');
      expect(w.symptoms.first.count, 3);
      expect(w.symptoms.map((s) => s.label), isNot(contains('Nausea')));
      expect(w.medianDurationHours, 4.5);
      expect(d.symptomFrequency.map((s) => s.label),
          containsAll(['Fatigue', 'Nausea', kSymptomVertigo]));
      expect(computeDashboard([stat(1)], now: now).withoutHeadache, isNull);
    });

    test('trigger correlations include attacks without headache', () async {
      final db = MegrimDatabase.forTesting(NativeDatabase.memory());
      for (var i = 0; i < 6; i++) {
        final at = DateTime.utc(2026, 9, 1 + i * 3, 12);
        await db.into(db.migraineEvents).insert(MigraineEventsCompanion.insert(
            id: 'e$i',
            startedAt: at,
            startedAtOffsetMin: const Value(0),
            headachePresent: Value(i.isEven ? false : true),
            createdAt: at,
            updatedAt: at));
      }
      final corr = await MegrimRepository(db: db).correlations();
      expect(corr.totalEvents, 6);
      await db.close();
    });
  });

  group('report', () {
    Future<MegrimRepository> seeded() async {
      final db = MegrimDatabase.forTesting(NativeDatabase.memory());
      Future<void> add(String id, int day,
              {bool? headache, bool? aura, List<String> symptoms = const [], String? impact}) =>
          db.into(db.migraineEvents).insert(MigraineEventsCompanion.insert(
                id: id,
                startedAt: DateTime.utc(2026, 10, day, 9),
                endedAt: Value(DateTime.utc(2026, 10, day, 13)),
                startedAtOffsetMin: const Value(0),
                endedAtOffsetMin: const Value(0),
                headachePresent: Value(headache),
                auraPresent: Value(aura),
                severity: Value(headache == false ? null : 6),
                symptoms: Value(encodeStringList(symptoms)),
                impact: Value(impact),
                createdAt: t0,
                updatedAt: t0,
              ));
      await add('a', 1, headache: false, aura: true, impact: EventImpact.reduced);
      await add('b', 3, headache: false, symptoms: [kSymptomVertigo, 'Fatigue']);
      await add('c', 5, symptoms: ['Nausea'], impact: EventImpact.unable);
      return MegrimRepository(db: db);
    }

    test('lists attacks without headache separately, with their kinds and symptoms', () async {
      final repo = await seeded();
      final c = await repo.reportContent(now: DateTime(2026, 10, 8));
      final w = c.withoutHeadache!;
      expect(w.summary, startsWith('2 of 3 entries (66.7%) were recorded without headache: '
          '1 with aura, 1 with vertigo or dizziness, 0 other.'));
      expect(w.summary, endsWith('Median length 4.0h.'));
      expect({for (final b in w.byKind) b.label: b.count},
          {'With aura': 1, 'With vertigo or dizziness': 1, 'Other': 0});
      expect(w.symptoms.map((b) => b.label), [kSymptomVertigo, 'Fatigue'].toList()..sort());
      expect(c.symptomFrequency.map((b) => b.label), containsAll(['Nausea', kSymptomVertigo]));
      expect(c.impact, contains('1 day unable to function, 1 day with reduced function'));
      expect(c.impact, contains('impact recorded on 2 of 3 migraine days'));
      final chart = c.charts.firstWhere((ch) => ch.title == 'Migraine days per month');
      expect(chart.note, contains('Includes 2 days with only attacks without headache.'));
      final rows = {for (final r in c.events) r.date: r};
      expect(rows['1 Oct 2026']!.severity, 'none');
      expect(rows['5 Oct 2026']!.severity, '6');
      expect(rows['3 Oct 2026']!.symptoms, '$kSymptomVertigo, Fatigue');
      await repo.db.close();
    });

    test('a diary with none of the new fields leaves the sections out', () async {
      final db = MegrimDatabase.forTesting(NativeDatabase.memory());
      await db.into(db.migraineEvents).insert(ev('x', severity: 5));
      final c = await MegrimRepository(db: db).reportContent(now: DateTime(2026, 10, 8));
      expect(c.withoutHeadache, isNull);
      expect(c.impact, isNull);
      expect(c.symptomFrequency, isEmpty);
      expect(c.events.single.severity, '5');
      await db.close();
    });
  });
}
