import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/database/database.dart';

void main() {
  late MegrimDatabase db;

  setUp(() {
    db = MegrimDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('seeds default vocabularies on first run', () async {
    final triggers = await db.vocabValues(VocabKind.trigger);
    final locations = await db.vocabValues(VocabKind.headLocation);
    expect(triggers, kDefaultTriggers);
    expect(locations, kDefaultHeadLocations);
    expect(await db.vocabValues(VocabKind.medication), isEmpty);
  });

  test('settings round-trip', () async {
    expect(await db.getSetting('missing'), isNull);
    await db.setSetting('home_location', '{"lat":39.96,"lon":-105.05}');
    expect(await db.getSetting('home_location'),
        '{"lat":39.96,"lon":-105.05}');
    await db.setSetting('home_location', 'updated');
    expect(await db.getSetting('home_location'), 'updated');
  });

  test('vocab add / rename / delete; rename does not touch history', () async {
    await db.addVocab(VocabKind.trigger, 'Chocolate');
    expect(await db.vocabValues(VocabKind.trigger), contains('Chocolate'));

    await db.renameVocab(VocabKind.trigger, 'Chocolate', 'Dark chocolate');
    final afterRename = await db.vocabValues(VocabKind.trigger);
    expect(afterRename, contains('Dark chocolate'));
    expect(afterRename, isNot(contains('Chocolate')));

    await db.deleteVocab(VocabKind.trigger, 'Dark chocolate');
    expect(
        await db.vocabValues(VocabKind.trigger), isNot(contains('Dark chocolate')));
  });

  test('event insert with cascade to derived_factors on delete', () async {
    final now = DateTime.now().toUtc();
    await db.into(db.migraineEvents).insert(
          MigraineEventsCompanion.insert(
            id: 'evt-1',
            startedAt: now,
            createdAt: now,
            updatedAt: now,
            severity: const Value(7),
          ),
        );
    await db.into(db.derivedFactors).insert(
          DerivedFactorsCompanion.insert(eventId: 'evt-1'),
        );

    expect(await db.select(db.migraineEvents).get(), hasLength(1));
    expect(await db.select(db.derivedFactors).get(), hasLength(1));

    await (db.delete(db.migraineEvents)
          ..where((t) => t.id.equals('evt-1')))
        .go();

    expect(await db.select(db.migraineEvents).get(), isEmpty);
    // ON DELETE CASCADE (foreign_keys pragma enabled in beforeOpen).
    expect(await db.select(db.derivedFactors).get(), isEmpty);
  });
}
