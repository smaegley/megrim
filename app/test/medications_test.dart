import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/analytics/medications.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/models/json_fields.dart';
import 'package:megrim/models/med_entry.dart';
import 'package:megrim/models/relief_entry.dart';
import 'package:megrim/repositories/megrim_repository.dart';
import 'package:megrim/services/export_service.dart';
import 'package:megrim/services/import_service.dart';

/// Backlog #18 (acute-medication days, the overuse notice) and #19 (preventives, non-drug
/// relief), which share schema v5.

/// "Today" for the counting tests: the last 3 complete months are July, August and September.
final now = DateTime(2026, 10, 15, 12);

/// One entry at noon local time on [day], with one dose of each of [meds].
MedEventInput on(DateTime day, List<String> meds, {List<ReliefEntry> relief = const []}) =>
    MedEventInput(
      startedAt: DateTime(day.year, day.month, day.day, 12).toUtc(),
      meds: [for (final m in meds) MedEntry(name: m)],
      relief: relief,
    );

/// Entries on the first [n] days of [month] 2026, each taking [meds].
List<MedEventInput> days(int month, int n, List<String> meds, {int from = 1}) =>
    [for (var d = from; d < from + n; d++) on(DateTime(2026, month, d), meds)];

const classes = {
  'Suma': MedClass.triptan,
  'Ibu': MedClass.simpleAnalgesic,
  'Para': MedClass.simpleAnalgesic,
  'Ubro': MedClass.gepant,
  'Codeine combo': MedClass.combinationAnalgesic,
};

/// Three qualifying-or-not months: the same pattern in July, August and September.
List<MedEventInput> threeMonths(List<MedEventInput> Function(int month) perMonth) =>
    [for (final m in [7, 8, 9]) ...perMonth(m)];

MedicationDays md(List<MedEventInput> events) => medicationDays(events, classes, now)!;

void main() {
  group('medication days', () {
    test('no medication anywhere gives null', () {
      expect(medicationDays([on(DateTime(2026, 9, 1), [])], classes, now), isNull);
    });

    test('two doses on one day, in one entry or two, count as one day', () {
      final r = md([
        on(DateTime(2026, 10, 10), ['Suma', 'Suma']),
        on(DateTime(2026, 10, 10), ['Suma']),
      ]);
      expect(r.last30, 1);
      expect(r.byClassLast30, {MedClass.triptan: 1});
    });

    test('a dose taken after midnight belongs to the next local day', () {
      // Logged in Denver (UTC-6 in July) at 22:00; the dose at 01:00 the next morning.
      final r = medicationDays([
        MedEventInput(
          startedAt: DateTime.utc(2026, 7, 2, 4), // 22:00 on 1 July in Denver
          startOffsetMin: -360,
          meds: [MedEntry(name: 'Suma', time: DateTime.utc(2026, 7, 2, 7).toIso8601String())],
        ),
      ], classes, now)!;
      expect(r.byMonth.first.key, '2026-07');
      final july = r.byMonth.first;
      expect(july.days, 1);
      expect(
          doseDay(
            MedEntry(name: 'Suma', time: DateTime.utc(2026, 7, 2, 7).toIso8601String()),
            DateTime.utc(2026, 7, 2, 4),
            -360,
          ),
          DateTime(2026, 7, 2));
      expect(doseDay(const MedEntry(name: 'Suma'), DateTime.utc(2026, 7, 2, 4), -360),
          DateTime(2026, 7, 1),
          reason: 'without a time, the dose is on the entry\'s start day');
    });

    test('classes are matched ignoring case and spaces; the rest are listed as unclassified', () {
      expect(classOf(' suma ', classes), MedClass.triptan);
      final r = md([on(DateTime(2026, 10, 1), ['SUMA', 'Mystery pill', 'Mystery pill'])]);
      expect(r.byClassLast30, {MedClass.triptan: 1, kUnclassified: 1});
      expect(r.unclassifiedNames, ['Mystery pill']);
    });

    test('the last 30 days are today and the 29 before', () {
      final r = md([
        on(DateTime(2026, 9, 15), ['Ibu']), // 30 days back: just outside
        on(DateTime(2026, 9, 16), ['Ibu']),
        on(DateTime(2026, 10, 15), ['Ibu']),
      ]);
      expect(r.last30, 2);
    });

    test('months run from the first medication through the current month, gaps included', () {
      final r = md([on(DateTime(2026, 6, 3), ['Ibu']), on(DateTime(2026, 9, 3), ['Ibu'])]);
      expect(r.byMonth.map((m) => m.key), ['2026-06', '2026-07', '2026-08', '2026-09', '2026-10']);
      expect(r.byMonth.map((m) => m.days), [1, 0, 0, 1, 0]);
    });
  });

  group('reference levels in a month', () {
    MedMonth month(List<MedEventInput> events) => md(events).byMonth.first;

    test('triptan: 9 days is under, 10 reaches it', () {
      expect(month(days(7, 9, ['Suma'])).reachedLevel, isFalse);
      expect(month(days(7, 10, ['Suma'])).levelsReached, [MedClass.triptan]);
    });

    test('simple pain relievers are one class with a level of 15: 14 under, 15 reaches it', () {
      // Paracetamol and ibuprofen on alternate days add up (ICHD-3 8.2.3).
      final fourteen = [
        for (var d = 1; d <= 14; d++) on(DateTime(2026, 7, d), [d.isEven ? 'Ibu' : 'Para']),
      ];
      expect(month(fourteen).reachedLevel, isFalse,
          reason: 'one class under its own level is not the mixed rule either');
      expect(month([...fourteen, on(DateTime(2026, 7, 15), ['Para'])]).levelsReached,
          [MedClass.simpleAnalgesic]);
    });

    test('a mix of classes on 10 days in total reaches the mixed level (ICHD-3 8.2.6)', () {
      // 6 triptan days + 5 simple-pain-reliever days, all different days = 11.
      final r = month([...days(7, 6, ['Suma']), ...days(7, 5, ['Ibu'], from: 7)]);
      expect(r.overuseClassDays, 11);
      expect(r.levelsReached, [kMixedClasses]);
    });

    test('the mixed total counts days, so two classes on one day count once', () {
      // Triptan on days 1–6, ibuprofen on days 2–6 as well: 6 days in total.
      final r = month([...days(7, 6, ['Suma']), ...days(7, 5, ['Ibu'], from: 2)]);
      expect(r.overuseClassDays, 6);
      expect(r.reachedLevel, isFalse);
    });

    test('a class at its own level is reported as that class, not as mixed', () {
      final r = month([...days(7, 10, ['Suma']), ...days(7, 5, ['Ibu'], from: 11)]);
      expect(r.levelsReached, [MedClass.triptan]);
    });

    test('gepants and unclassified medications never reach a level', () {
      final r = month([...days(7, 20, ['Ubro']), ...days(7, 20, ['Mystery pill'])]);
      expect(r.days, 20);
      expect(r.overuseClassDays, 0);
      expect(r.reachedLevel, isFalse);
      // And they don't make up a mix with an overuse class either.
      expect(month([...days(7, 9, ['Suma']), ...days(7, 5, ['Ubro'], from: 10)]).reachedLevel,
          isFalse);
    });

    test('combination pain relievers count toward the mixed total', () {
      final r = month([...days(7, 5, ['Suma']), ...days(7, 5, ['Codeine combo'], from: 6)]);
      expect(r.levelsReached, [kMixedClasses]);
    });
  });

  group('the overuse notice', () {
    test('appears when each of the last 3 complete months reaches a level', () {
      final r = md(threeMonths((m) => days(m, 10, ['Suma'])));
      expect(r.notice!.map((m) => m.key), ['2026-07', '2026-08', '2026-09']);
    });

    test('a different level in each month still counts', () {
      final r = md([
        ...days(7, 10, ['Suma']),
        ...days(8, 15, ['Ibu']),
        ...days(9, 6, ['Suma']),
        ...days(9, 5, ['Ibu'], from: 10),
      ]);
      expect(r.notice, isNotNull);
    });

    test('two qualifying months then one under: no notice', () {
      final r = md([...days(7, 10, ['Suma']), ...days(8, 10, ['Suma']), ...days(9, 9, ['Suma'])]);
      expect(r.notice, isNull);
    });

    test('one under then two qualifying: no notice yet', () {
      final r = md([...days(7, 9, ['Suma']), ...days(8, 10, ['Suma']), ...days(9, 10, ['Suma'])]);
      expect(r.notice, isNull);
    });

    test('the current month never counts, however high', () {
      final r = md([...days(8, 10, ['Suma']), ...days(9, 10, ['Suma']), ...days(10, 15, ['Suma'])]);
      expect(r.notice, isNull, reason: 'only August and September are complete');
    });

    test('a bad last 30 days alone never raises it', () {
      final r = md(days(10, 15, ['Suma']));
      expect(r.last30, 15);
      expect(r.notice, isNull);
    });
  });

  group('what helped', () {
    test('counts helped / didn\'t / unknown, and leaves unknowns out of the rate', () {
      final rows = whatHelped([
        MedEventInput(startedAt: DateTime.utc(2026, 9, 1), meds: const [
          MedEntry(name: 'Suma', helped: true),
          MedEntry(name: 'suma', helped: false),
          MedEntry(name: 'Suma'),
        ], relief: const [
          ReliefEntry(name: 'Dark room', helped: true),
        ]),
        MedEventInput(startedAt: DateTime.utc(2026, 9, 2), relief: const [
          ReliefEntry(name: 'Dark room', helped: true),
          ReliefEntry(name: 'Cold pack'),
        ]),
      ]);
      expect(rows.map((r) => (r.name, r.relief, r.tried)), [
        ('Suma', false, 3),
        ('Dark room', true, 2),
        ('Cold pack', true, 1),
      ]);
      final suma = rows.first;
      expect((suma.helped, suma.notHelped, suma.unknown, suma.helpedPct), (1, 1, 1, 50));
      expect(rows[1].helpedPct, 100);
      expect(rows[2].helpedPct, isNull, reason: 'no answer recorded');
    });

    test('empty when nothing is recorded', () {
      expect(whatHelped([MedEventInput(startedAt: DateTime.utc(2026, 9, 1))]), isEmpty);
    });
  });

  group('schema v5', () {
    test('a fresh install seeds the default relief methods and has no classes', () async {
      final db = MegrimDatabase.forTesting(NativeDatabase.memory());
      expect(await db.vocabValues(VocabKind.relief), kDefaultRelief);
      expect(await db.medicationClassMap(), isEmpty);
      await db.close();
    });

    test('v4 -> v5 adds the column and tables, keeps rows, and seeds relief once', () async {
      final dir = Directory.systemTemp.createTempSync('megrim-v5');
      final file = File('${dir.path}/v4.sqlite');
      final t0 = DateTime.utc(2026, 10, 1, 9);

      // Build a current database, then demote it to v4 by hand.
      final cur = MegrimDatabase.forTesting(NativeDatabase(file));
      await cur.into(cur.migraineEvents).insert(MigraineEventsCompanion.insert(
          id: 'old',
          startedAt: t0,
          medsTaken: Value(encodeMeds(const [MedEntry(name: 'Suma', helped: true)])),
          createdAt: t0,
          updatedAt: t0));
      await cur.customStatement("DELETE FROM vocabularies WHERE kind = 'relief'");
      await cur.customStatement('ALTER TABLE migraine_events DROP COLUMN relief_tried');
      await cur.customStatement('DROP TABLE medication_classes');
      await cur.customStatement('DROP TABLE preventive_regimens');
      await cur.customStatement('PRAGMA user_version = 4');
      await cur.close();

      final upgraded = MegrimDatabase.forTesting(NativeDatabase(file));
      final old = (await upgraded.select(upgraded.migraineEvents).get()).single;
      expect(decodeMeds(old.medsTaken).single.name, 'Suma');
      expect(old.reliefTried, isNull);
      expect(await upgraded.vocabValues(VocabKind.relief), kDefaultRelief);
      expect(await upgraded.medicationClassMap(), isEmpty);
      expect(await upgraded.select(upgraded.preventiveRegimens).get(), isEmpty);
      expect(await upgraded.getSetting('schema_version'), '${upgraded.schemaVersion}');
      await upgraded.close();
      dir.deleteSync(recursive: true);
    });

    test('the upgrade keeps relief methods the user already has', () async {
      final dir = Directory.systemTemp.createTempSync('megrim-v5b');
      final file = File('${dir.path}/v4.sqlite');
      final cur = MegrimDatabase.forTesting(NativeDatabase(file));
      await cur.customStatement("DELETE FROM vocabularies WHERE kind = 'relief'");
      await cur.addVocab(VocabKind.relief, 'Sleep');
      await cur.addVocab(VocabKind.relief, 'Ginger tea');
      await cur.customStatement('PRAGMA user_version = 4');
      await cur.close();

      final upgraded = MegrimDatabase.forTesting(NativeDatabase(file));
      final relief = await upgraded.vocabValues(VocabKind.relief);
      expect(relief.where((s) => s == 'Sleep'), hasLength(1));
      expect(relief, contains('Ginger tea'));
      await upgraded.close();
      dir.deleteSync(recursive: true);
    });

    test('renaming a medication gives the new name its class and keeps the old one', () async {
      final db = MegrimDatabase.forTesting(NativeDatabase.memory());
      await db.addVocab(VocabKind.medication, 'Suma');
      await db.setMedicationClass('Suma', MedClass.triptan);
      await db.renameVocab(VocabKind.medication, 'Suma', 'Sumatriptan');
      expect(await db.medicationClassMap(),
          {'Suma': MedClass.triptan, 'Sumatriptan': MedClass.triptan});
      // Deleting the suggestion keeps the class past entries are counted by.
      await db.deleteVocab(VocabKind.medication, 'Sumatriptan');
      expect(await db.medicationClassOf('Sumatriptan'), MedClass.triptan);
      await db.setMedicationClass('Suma', null);
      expect(await db.medicationClassOf('Suma'), isNull);
      await db.close();
    });
  });

  group('preventives', () {
    test('save, update, list oldest first, delete', () async {
      final db = MegrimDatabase.forTesting(NativeDatabase.memory());
      final repo = MegrimRepository(db: db);
      final b = await repo.savePreventive(name: 'Propranolol', startedOn: '2026-03-01');
      await repo.savePreventive(name: 'Topiramate', dose: '50 mg', startedOn: '2025-11-10');
      expect((await repo.preventives()).map((p) => p.name), ['Topiramate', 'Propranolol']);
      await repo.savePreventive(
          id: b, name: 'Propranolol', startedOn: '2026-03-01', stoppedOn: '2026-09-30');
      expect((await repo.preventives()).last.stoppedOn, '2026-09-30');
      await repo.deletePreventive(b);
      expect((await repo.preventives()).single.name, 'Topiramate');
      expect((await repo.dashboard()).preventives.single.name, 'Topiramate');
      await db.close();
    });
  });

  group('export / import', () {
    final t0 = DateTime.utc(2026, 10, 1, 9);

    Future<MegrimDatabase> source() async {
      final db = MegrimDatabase.forTesting(NativeDatabase.memory());
      await db.into(db.migraineEvents).insert(MigraineEventsCompanion.insert(
            id: 'e1',
            startedAt: t0,
            medsTaken: Value(encodeMeds(const [MedEntry(name: 'Suma', helped: true)])),
            reliefTried: Value(encodeRelief(const [
              ReliefEntry(name: 'Dark room', helped: true),
              ReliefEntry(name: 'Cold pack'),
            ])),
            createdAt: t0,
            updatedAt: t0,
          ));
      await db.setMedicationClass('Suma', MedClass.triptan);
      await db.addVocab(VocabKind.relief, 'Ginger tea');
      await MegrimRepository(db: db)
          .savePreventive(name: 'Propranolol', dose: '40 mg', startedOn: '2026-03-01');
      return db;
    }

    test('relief, classes and preventives round-trip through JSON', () async {
      final src = await source();
      final json = await ExportService(db: src).toJsonString();
      final doc = jsonDecode(json) as Map<String, dynamic>;
      expect((doc['events'] as List).single['relief_tried'], [
        {'name': 'Dark room', 'helped': true},
        {'name': 'Cold pack'},
      ]);
      expect(doc['medication_classes'], {'Suma': 'triptan'});
      expect((doc['preventives'] as List).single['started_on'], '2026-03-01');
      expect(doc['vocabularies']['relief'], contains('Ginger tea'));

      final dst = MegrimDatabase.forTesting(NativeDatabase.memory());
      await ImportService(dst).importJsonString(json);
      final e = (await dst.select(dst.migraineEvents).get()).single;
      expect(decodeRelief(e.reliefTried).map((r) => (r.name, r.helped)),
          [('Dark room', true), ('Cold pack', null)]);
      expect(await dst.medicationClassMap(), {'Suma': MedClass.triptan});
      final p = (await dst.select(dst.preventiveRegimens).get()).single;
      expect((p.name, p.dose, p.startedOn, p.stoppedOn), ('Propranolol', '40 mg', '2026-03-01', null));
      expect(await dst.vocabValues(VocabKind.relief), contains('Ginger tea'));
      await src.close();
      await dst.close();
    });

    test('merge keeps the classes and preventives already here; replace takes the file\'s',
        () async {
      final src = await source();
      final json = await ExportService(db: src).toJsonString();
      final srcId = (await src.select(src.preventiveRegimens).get()).single.id;

      final dst = MegrimDatabase.forTesting(NativeDatabase.memory());
      final repo = MegrimRepository(db: dst);
      await dst.setMedicationClass('Suma', MedClass.other);
      await repo.savePreventive(name: 'Mine', startedOn: '2026-01-01');

      await ImportService(dst).importJsonString(json);
      expect(await dst.medicationClassOf('Suma'), MedClass.other);
      expect((await repo.preventives()).map((p) => p.name), ['Mine', 'Propranolol']);
      // Importing the same file again adds nothing.
      await ImportService(dst).importJsonString(json);
      expect(await repo.preventives(), hasLength(2));

      await ImportService(dst).importJsonString(json, replace: true);
      expect(await dst.medicationClassOf('Suma'), MedClass.triptan);
      expect((await repo.preventives()).single.id, srcId);
      await src.close();
      await dst.close();
    });

    test('an unknown class or a preventive without a start date is dropped', () async {
      final dst = MegrimDatabase.forTesting(NativeDatabase.memory());
      await ImportService(dst).importJson({
        'format': 'megrim-export',
        'format_version': 1,
        'events': [],
        'medication_classes': {'Suma': 'triptan', 'Odd': 'not-a-class'},
        'preventives': [
          {'id': 'p1', 'name': 'No date'},
          {'id': 'p2', 'name': 'Bad date', 'started_on': 'March'},
          {'id': 'p3', 'name': 'Good', 'started_on': '2026-03-01', 'stopped_on': 'never'},
        ],
      });
      expect(await dst.medicationClassMap(), {'Suma': MedClass.triptan});
      final p = (await dst.select(dst.preventiveRegimens).get()).single;
      expect((p.id, p.stoppedOn), ('p3', null));
      await dst.close();
    });

    test('an export from before v5 imports with no relief, classes or preventives', () async {
      final dst = MegrimDatabase.forTesting(NativeDatabase.memory());
      await ImportService(dst).importJson({
        'format': 'megrim-export',
        'format_version': 1,
        'events': [
          {'id': 'old', 'started_at': '2026-09-01T09:00:00.000Z', 'meds_taken': [{'name': 'Suma'}]},
        ],
      });
      final e = (await dst.select(dst.migraineEvents).get()).single;
      expect(e.reliefTried, isNull);
      expect(decodeMeds(e.medsTaken).single.name, 'Suma');
      expect(await dst.medicationClassMap(), isEmpty);
      await dst.close();
    });

    test('CSV appends relief_tried after the v4 columns', () async {
      final src = await source();
      final lines = (await ExportService(db: src).toCsv()).trim().split('\n');
      expect(lines.first, endsWith(',headache_present,symptoms,impact,relief_tried'));
      expect(lines[1], endsWith(',Dark room;Cold pack'));
      await src.close();
    });

    test('the analytics block carries medication days and what helped', () async {
      final src = await source();
      final block = await MegrimRepository(db: src).analyticsForExport(now: DateTime(2026, 10, 15));
      final dash = block['dashboard'] as Map<String, dynamic>;
      expect(dash['medication_days']['by_class_last_30'], {'triptan': 1});
      expect(dash['medication_days']['overuse_notice_months'], isNull);
      expect((dash['what_helped'] as List).map((r) => r['name']), ['Suma', 'Cold pack', 'Dark room']);
      await src.close();
    });
  });
}
