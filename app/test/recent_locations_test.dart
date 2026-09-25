import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/models/home_location.dart';
import 'package:megrim/repositories/megrim_repository.dart';
import 'package:megrim/services/geocoder.dart';
import 'package:megrim/widgets/location_picker.dart';

class _EmptyGeocoder extends Geocoder {
  @override
  Future<List<GeoResult>> search(String query) async => const [];
}

void main() {
  late MegrimDatabase db;
  late MegrimRepository repo;

  setUp(() {
    db = MegrimDatabase.forTesting(NativeDatabase.memory());
    repo = MegrimRepository(db: db);
  });

  tearDown(() async => db.close());

  Future<void> insertEvent(String id, DateTime startedAt,
      {double? lat, double? lon, String? label}) async {
    final now = DateTime.now().toUtc();
    await db.into(db.migraineEvents).insert(
          MigraineEventsCompanion.insert(
            id: id,
            startedAt: startedAt,
            createdAt: now,
            updatedAt: now,
            geoLat: lat == null ? const Value.absent() : Value(lat),
            geoLon: lon == null ? const Value.absent() : Value(lon),
            geoLabel: label == null ? const Value.absent() : Value(label),
          ),
        );
  }

  test('returns distinct locations, most-recent-first, capped', () async {
    final t0 = DateTime.utc(2026, 1, 1);
    await insertEvent('a', t0, lat: 40.01, lon: -105.25, label: 'Boulder');
    await insertEvent('b', t0.add(const Duration(days: 1)),
        lat: 39.74, lon: -104.99, label: 'Denver');
    await insertEvent('c', t0.subtract(const Duration(days: 1)),
        lat: 40.01, lon: -105.25, label: 'Boulder, CO');

    final locs = await repo.recentLocations();

    expect(locs, hasLength(2));
    expect(locs.first.label, 'Denver'); // newest startedAt
    expect(locs.last.label, 'Boulder'); // deduped, kept the most-recent occurrence
  });

  test('skips events with no recorded location', () async {
    await insertEvent('a', DateTime.utc(2026, 1, 1),
        lat: 40.01, lon: -105.25, label: 'Boulder');
    await insertEvent('b', DateTime.utc(2026, 1, 2)); // no coords

    final locs = await repo.recentLocations();

    expect(locs, hasLength(1));
    expect(locs.single, isA<HomeLocation>());
    expect(locs.single.label, 'Boulder');
  });

  test('empty history yields empty list', () async {
    expect(await repo.recentLocations(), isEmpty);
  });

  test('entries imported without a label fall back to coordinates', () async {
    await insertEvent('a', DateTime.utc(2026, 1, 1), lat: 40.01, lon: -105.25);
    final locs = await repo.recentLocations();
    expect(locs.single.label, '40.01, -105.25');
  });

  group('LocationPickerField recent locations', () {
    const recents = [
      HomeLocation(lat: 39.74, lon: -104.99, label: 'Denver'),
      HomeLocation(lat: 40.01, lon: -105.25, label: 'Boulder'),
    ];

    Future<void> pumpField(WidgetTester tester, ValueChanged<HomeLocation> onSelected) {
      return tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LocationPickerField(
            geocoder: _EmptyGeocoder(),
            recentLocations: recents,
            onSelected: onSelected,
          ),
        ),
      ));
    }

    testWidgets('offers recent locations as one-tap suggestions', (tester) async {
      HomeLocation? selected;
      await pumpField(tester, (loc) => selected = loc);

      expect(find.text('Recent'), findsOneWidget);
      expect(find.text('Denver'), findsOneWidget);

      await tester.tap(find.text('Denver'));
      await tester.pump();
      expect(selected, isNotNull);
      expect(selected!.label, 'Denver');
    });

    testWidgets('hides recents while typing and brings them back when cleared',
        (tester) async {
      HomeLocation? selected;
      await pumpField(tester, (loc) => selected = loc);
      expect(find.text('Recent'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Denv');
      await tester.pump(const Duration(milliseconds: 600)); // past the debounce
      expect(find.text('Recent'), findsNothing);
      expect(find.text('Denver'), findsNothing);
      expect(selected, isNull);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Recent'), findsOneWidget);
      expect(find.text('Denver'), findsOneWidget);
    });
  });
}
