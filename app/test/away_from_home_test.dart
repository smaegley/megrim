import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/analytics/dashboard.dart';
import 'package:megrim/analytics/geo_distance.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/models/home_location.dart';
import 'package:megrim/repositories/megrim_repository.dart';

/// Backlog #13: a descriptive "away from home" share, plus "Travel" joining the default triggers
/// in schema v3. Deliberately NOT a suspected factor — see [AwayFromHome].
const home = (lat: 40.01, lon: -105.27); // Boulder, CO
const denver = (lat: 39.74, lon: -104.99); // ~40 km away — NOT "away"
const paris = (lat: 48.86, lon: 2.35);
const tokyo = (lat: 35.68, lon: 139.65);

EventStat stat(DateTime at, {({double lat, double lon})? at2, String? label}) => EventStat(
      startedAt: at,
      geoLat: at2?.lat,
      geoLon: at2?.lon,
      geoLabel: label,
    );

void main() {
  group('distanceKm', () {
    test('known city pairs, within 1% of the geodesic distance', () {
      // Reference values from the WGS-84 geodesic; a spherical model is close enough here.
      expect(distanceKm(home.lat, home.lon, denver.lat, denver.lon),
          closeTo(40.0, 4.0));
      expect(distanceKm(home.lat, home.lon, paris.lat, paris.lon),
          closeTo(7854, 79));
      expect(distanceKm(paris.lat, paris.lon, tokyo.lat, tokyo.lon),
          closeTo(9711, 97));
    });

    test('identical points are zero, and it is symmetric', () {
      expect(distanceKm(home.lat, home.lon, home.lat, home.lon), 0);
      expect(distanceKm(home.lat, home.lon, tokyo.lat, tokyo.lon),
          closeTo(distanceKm(tokyo.lat, tokyo.lon, home.lat, home.lon), 1e-9));
    });

    test('straddling the antimeridian takes the short way round', () {
      // +179.9 to -179.9 is 0.2° apart at the equator (~22 km), not 359.8°.
      expect(distanceKm(0, 179.9, 0, -179.9), closeTo(22.2, 1.0));
    });

    test('antipodal points do not produce NaN', () {
      final d = distanceKm(0, 0, 0, 180);
      expect(d.isNaN, isFalse);
      expect(d, closeTo(20015, 50)); // half the circumference
    });
  });

  group('AwayFromHome', () {
    final t0 = DateTime.utc(2026, 1, 1);
    DateTime day(int n) => t0.add(Duration(days: n));

    test('counts only entries beyond the threshold, over located entries', () {
      final d = computeDashboard([
        stat(day(0), at2: home, label: 'Boulder'),
        stat(day(1), at2: denver, label: 'Denver'), // ~40 km — within threshold
        stat(day(2), at2: paris, label: 'Paris'),
        stat(day(3), at2: paris, label: 'Paris'),
        stat(day(4)), // no coordinates at all
      ], homeLat: home.lat, homeLon: home.lon);

      final away = d.awayFromHome!;
      expect(away.locatedEvents, 4, reason: 'the unlocated entry is not a denominator');
      expect(away.awayEvents, 2);
      expect(away.awayPct, 50.0);
      expect(away.thresholdKm, kAwayFromHomeThresholdKm);
      expect(away.farthestKm, closeTo(7854, 100));
      expect(away.awayPlaces.map((p) => '${p.label}:${p.count}'), ['Paris:2']);
    });

    test('zero away is still reported, not hidden', () {
      final d = computeDashboard(
        [stat(day(0), at2: home), stat(day(1), at2: denver)],
        homeLat: home.lat,
        homeLon: home.lon,
      );
      expect(d.awayFromHome, isNotNull);
      expect(d.awayFromHome!.awayEvents, 0);
      expect(d.awayFromHome!.awayPct, 0);
      expect(d.awayFromHome!.awayPlaces, isEmpty);
    });

    test('null without a home location, and null when nothing is located', () {
      final events = [stat(day(0), at2: paris)];
      expect(computeDashboard(events).awayFromHome, isNull);
      expect(computeDashboard(events, homeLat: home.lat).awayFromHome, isNull);
      expect(
        computeDashboard([stat(day(0)), stat(day(1))],
                homeLat: home.lat, homeLon: home.lon)
            .awayFromHome,
        isNull,
      );
    });

    test('places sort by count then name; blank labels fall back to coordinates', () {
      final d = computeDashboard([
        stat(day(0), at2: tokyo, label: 'Tokyo'),
        stat(day(1), at2: paris, label: 'Paris'),
        stat(day(2), at2: paris, label: 'Paris'),
        stat(day(3), at2: (lat: 51.51, lon: -0.13), label: '  '), // blank label
      ], homeLat: home.lat, homeLon: home.lon);

      expect(d.awayFromHome!.awayPlaces.map((p) => p.label),
          ['Paris', '51.51, -0.13', 'Tokyo']);
    });

    test('just inside the threshold is home, just outside is away', () {
      // Due north of home: 1 degree of latitude is ~111.2 km.
      double northOf(double km) =>
          home.lat + km / (kEarthRadiusKm * math.pi / 180);
      int awayCountAt(double km) => computeDashboard(
            [stat(day(0), at2: (lat: northOf(km), lon: home.lon))],
            homeLat: home.lat,
            homeLon: home.lon,
          ).awayFromHome!.awayEvents;

      expect(awayCountAt(kAwayFromHomeThresholdKm - 1), 0);
      expect(awayCountAt(kAwayFromHomeThresholdKm + 1), 1);
    });
  });

  group('repository + export', () {
    late MegrimDatabase db;
    late MegrimRepository repo;
    setUp(() {
      db = MegrimDatabase.forTesting(NativeDatabase.memory());
      repo = MegrimRepository(db: db);
    });
    tearDown(() => db.close());

    Future<void> seed(({double lat, double lon}) at, String label) async {
      final now = DateTime.now().toUtc();
      await db.into(db.migraineEvents).insert(MigraineEventsCompanion.insert(
            id: '${label}_${at.lat}_${DateTime.now().microsecondsSinceEpoch}',
            startedAt: now,
            createdAt: now,
            updatedAt: now,
            geoLat: Value(at.lat),
            geoLon: Value(at.lon),
            geoLabel: Value(label),
          ));
    }

    test('dashboard() uses the stored home location', () async {
      await repo.setHomeLocation(
          const HomeLocation(lat: 40.01, lon: -105.27, label: 'Boulder'));
      await seed(home, 'Boulder');
      await seed(paris, 'Paris');
      final d = await repo.dashboard();
      expect(d.awayFromHome!.awayEvents, 1);
      expect(d.awayFromHome!.locatedEvents, 2);
    });

    test('the analytics export block carries it', () async {
      await repo.setHomeLocation(
          const HomeLocation(lat: 40.01, lon: -105.27, label: 'Boulder'));
      await seed(paris, 'Paris');
      final block = await repo.analyticsForExport();
      final a = (block['dashboard'] as Map)['away_from_home'] as Map;
      expect(a['located_events'], 1);
      expect(a['away_events'], 1);
      expect(a['away_pct'], 100.0);
      expect(a['threshold_km'], kAwayFromHomeThresholdKm);
      expect((a['away_places'] as List).single, {'label': 'Paris', 'count': 1});
    });

    test('with no home location the block carries null, not a zero', () async {
      await seed(paris, 'Paris');
      final block = await repo.analyticsForExport();
      expect((block['dashboard'] as Map)['away_from_home'], isNull);
    });
  });

  group('schema v3: the Travel trigger', () {
    test('is one of the defaults on a fresh install', () async {
      final db = MegrimDatabase.forTesting(NativeDatabase.memory());
      expect(await db.vocabValues(VocabKind.trigger), contains(kTravelTrigger));
      expect(kDefaultTriggers.last, kTravelTrigger,
          reason: 'appended, so existing installs keep their sort order');
      await db.close();
    });

    test('v2 -> v3 adds it exactly once, without disturbing the rest', () async {
      final dir = Directory.systemTemp.createTempSync('megrim-v3');
      final file = File('${dir.path}/v2.sqlite');

      // Build a v3 database, then demote it to v2 by hand.
      final v3 = MegrimDatabase.forTesting(NativeDatabase(file));
      await v3.customStatement(
          "DELETE FROM vocabularies WHERE kind = 'trigger' AND value = '$kTravelTrigger'");
      await v3.addVocab(VocabKind.trigger, 'My own trigger');
      await v3.customStatement('PRAGMA user_version = 2');
      await v3.close();

      final upgraded = MegrimDatabase.forTesting(NativeDatabase(file));
      final triggers = await upgraded.vocabValues(VocabKind.trigger);
      expect(triggers.where((t) => t == kTravelTrigger), hasLength(1));
      expect(triggers, contains('My own trigger'),
          reason: 'the migration must not touch the user\'s own vocabulary');
      expect(await upgraded.getSetting('schema_version'), '3');
      await upgraded.close();
      dir.deleteSync(recursive: true);
    });

    test('upgrading an install that already has its own "Travel" is a no-op', () async {
      final dir = Directory.systemTemp.createTempSync('megrim-v3b');
      final file = File('${dir.path}/v2.sqlite');
      final v3 = MegrimDatabase.forTesting(NativeDatabase(file));
      await v3.customStatement('PRAGMA user_version = 2');
      await v3.close();

      final upgraded = MegrimDatabase.forTesting(NativeDatabase(file));
      expect(
          (await upgraded.vocabValues(VocabKind.trigger))
              .where((t) => t == kTravelTrigger),
          hasLength(1));
      await upgraded.close();
      dir.deleteSync(recursive: true);
    });
  });
}
