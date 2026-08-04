import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/models/home_location.dart';
import 'package:megrim/services/geocoder.dart';
import 'package:megrim/services/location_input.dart';
import 'package:megrim/widgets/location_picker.dart';

/// A geocoder that fails the test if it is ever touched — manual entry (GPS / Plus Code) must be
/// a fully offline path, including while a manual-looking value is still being typed.
class _ExplodingGeocoder extends Geocoder {
  @override
  Future<List<GeoResult>> search(String query) async {
    fail('geocoder was queried with "$query" — manual entry must never hit the network');
  }
}

void main() {
  group('parseManualLocation', () {
    test('decimal GPS pairs in common separator styles', () {
      for (final input in ['40.01, -105.27', '40.01,-105.27', '40.01 -105.27', '40.01; -105.27']) {
        final loc = parseManualLocation(input);
        expect(loc, isNotNull, reason: input);
        expect(loc!.lat, closeTo(40.01, 1e-9));
        expect(loc.lon, closeTo(-105.27, 1e-9));
      }
      expect(parseManualLocation('-33.87, 151.21')!.label, '-33.87, 151.21');
    });

    test('full Plus Code decodes to its area center (pure local math)', () {
      // 849VCWC8+R9 is the Googleplex — a stable, publicly documented example code.
      final loc = parseManualLocation('849vcwc8+r9');
      expect(loc, isNotNull);
      expect(loc!.lat, closeTo(37.42, 0.01));
      expect(loc.lon, closeTo(-122.08, 0.01));
      expect(loc.label, '849VCWC8+R9');
    });

    test('rejects what it should', () {
      expect(parseManualLocation('Boulder'), isNull, reason: 'place names go to the geocoder');
      expect(parseManualLocation('91.0, 10.0'), isNull, reason: 'latitude out of range');
      expect(parseManualLocation('40.0, 181.0'), isNull, reason: 'longitude out of range');
      expect(parseManualLocation('CWC8+R9'), isNull,
          reason: 'short Plus Codes need a reference location, which would need a geocoder');
      expect(parseManualLocation('40.01'), isNull, reason: 'half-typed pair');
      expect(parseManualLocation(''), isNull);
    });

    test('looksLikeManualLocation guards partial input', () {
      expect(looksLikeManualLocation('4'), isTrue);
      expect(looksLikeManualLocation('-1'), isTrue);
      expect(looksLikeManualLocation('40.01, -1'), isTrue);
      expect(looksLikeManualLocation('CWC8+'), isTrue); // '+' anywhere
      expect(looksLikeManualLocation('Boulder'), isFalse);
      expect(looksLikeManualLocation(''), isFalse);
    });
  });

  group('LocationPickerField manual entry', () {
    testWidgets('GPS pair is offered offline and selected without any geocoder call',
        (tester) async {
      HomeLocation? selected;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LocationPickerField(
            geocoder: _ExplodingGeocoder(),
            onSelected: (loc) => selected = loc,
          ),
        ),
      ));

      // Type character by character: every intermediate value looks manual, so the
      // exploding geocoder proves no debounce ever fires along the way.
      await tester.enterText(find.byType(TextField), '40.016, -105.276');
      await tester.pump(const Duration(milliseconds: 600)); // beyond the debounce window
      expect(find.text('Use 40.02, -105.28'), findsOneWidget);
      expect(find.text('Entered directly — nothing sent online'), findsOneWidget);

      await tester.tap(find.text('Use 40.02, -105.28'));
      await tester.pump();
      expect(selected, isNotNull);
      expect(selected!.lat, closeTo(40.02, 1e-9), reason: 'rounded to 2 decimals like search results');
      expect(selected!.lon, closeTo(-105.28, 1e-9));
    });

    testWidgets('Plus Code is offered offline and selected', (tester) async {
      HomeLocation? selected;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LocationPickerField(
            geocoder: _ExplodingGeocoder(),
            onSelected: (loc) => selected = loc,
          ),
        ),
      ));

      await tester.enterText(find.byType(TextField), '849vcwc8+r9');
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Use 849VCWC8+R9'), findsOneWidget);

      await tester.tap(find.text('Use 849VCWC8+R9'));
      await tester.pump();
      expect(selected, isNotNull);
      expect(selected!.lat, closeTo(37.42, 0.01));
      expect(selected!.lon, closeTo(-122.08, 0.01));
      expect(selected!.label, '849VCWC8+R9');
    });
  });
}
