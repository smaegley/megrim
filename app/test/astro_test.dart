import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/enrichment/astro.dart';

void main() {
  group('sun times — physical invariants', () {
    test('equator has ~12h daylight year round', () {
      for (final month in [1, 3, 6, 9, 12]) {
        final r = sunTimes(DateTime.utc(2024, month, 15, 12), 0.0, 0.0);
        expect(r.daylightHours, closeTo(12.0, 0.3),
            reason: 'equator month $month');
      }
    });

    test('equinox gives ~12h daylight across latitudes', () {
      for (final lat in [-40.0, 0.0, 40.0, 60.0]) {
        final r = sunTimes(DateTime.utc(2024, 3, 20, 12), lat, 0.0);
        expect(r.daylightHours, closeTo(12.0, 0.3),
            reason: 'equinox lat $lat');
      }
    });

    test('northern summer solstice: more daylight at higher latitude', () {
      final low = sunTimes(DateTime.utc(2024, 6, 21, 12), 10.0, 0.0);
      final mid = sunTimes(DateTime.utc(2024, 6, 21, 12), 40.0, 0.0);
      final high = sunTimes(DateTime.utc(2024, 6, 21, 12), 60.0, 0.0);
      expect(low.daylightHours, lessThan(mid.daylightHours));
      expect(mid.daylightHours, lessThan(high.daylightHours));
    });

    test('hemispheric symmetry: 40N in June ≈ 40S in December', () {
      final north = sunTimes(DateTime.utc(2024, 6, 21, 12), 40.0, 0.0);
      final south = sunTimes(DateTime.utc(2024, 12, 21, 12), -40.0, 0.0);
      expect(north.daylightHours, closeTo(south.daylightHours, 0.2));
    });

    test('polar night and polar day', () {
      final night = sunTimes(DateTime.utc(2024, 12, 21, 12), 80.0, 0.0);
      expect(night.daylightHours, 0.0);
      expect(night.sunrise, isNull);

      final day = sunTimes(DateTime.utc(2024, 6, 21, 12), 80.0, 0.0);
      expect(day.daylightHours, 24.0);
      expect(day.sunset, isNull);
    });

    test('Greenwich equinox sunrise ~06:00 UTC, ~12h daylight', () {
      final r = sunTimes(DateTime.utc(2024, 3, 20, 12), 51.4769, 0.0);
      expect(r.daylightHours, closeTo(12.1, 0.3));
      expect(r.sunrise!.toUtc().hour, inInclusiveRange(5, 6));
      expect(r.sunset!.toUtc().hour, inInclusiveRange(17, 18));
    });

    test('sunrise precedes sunset', () {
      final r = sunTimes(DateTime.utc(2024, 7, 4, 12), 39.96, -105.05);
      expect(r.sunrise!.isBefore(r.sunset!), isTrue);
    });
  });

  group('moon phase & illumination', () {
    test('illumination always in [0,1]', () {
      for (var d = 0; d < 60; d++) {
        final illum = moonIllumination(DateTime.utc(2024, 1, 1).add(Duration(days: d)));
        expect(illum, inInclusiveRange(0.0, 1.0));
      }
    });

    test('known new moon 2024-01-11 reads as New Moon, ~0 illumination', () {
      final t = DateTime.utc(2024, 1, 11, 11, 57);
      expect(moonPhaseName(t), 'New Moon');
      expect(moonIllumination(t), lessThan(0.05));
    });

    test('known full moon 2024-01-25 reads as Full Moon, ~1 illumination', () {
      final t = DateTime.utc(2024, 1, 25, 17, 54);
      expect(moonPhaseName(t), 'Full Moon');
      expect(moonIllumination(t), greaterThan(0.95));
    });

    test('epoch is a new moon', () {
      final t = DateTime.utc(2000, 1, 6, 18, 14);
      expect(moonPhaseName(t), 'New Moon');
      expect(moonIllumination(t), closeTo(0.0, 0.01));
    });

    test('phase names cover a full cycle in order', () {
      final seen = <String>{};
      final start = DateTime.utc(2024, 1, 11, 12); // near a new moon
      for (var d = 0; d < 30; d++) {
        seen.add(moonPhaseName(start.add(Duration(days: d))));
      }
      // A full synodic month should touch every named phase.
      expect(seen, containsAll(kMoonPhases));
    });
  });

  test('computeAstro assembles both sun and moon', () {
    final r = computeAstro(DateTime.utc(2024, 6, 21, 15), 40.0, -105.0);
    expect(r.daylightHours, greaterThan(14.0)); // long northern summer day
    expect(kMoonPhases, contains(r.moonPhase));
    expect(r.moonIllumination, inInclusiveRange(0.0, 1.0));
  });
}
