import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/repositories/megrim_repository.dart';
import 'package:megrim/screens/event_detail_screen.dart';

/// Event Detail's Enrichment card must round for display. The stored values carry full double
/// precision: daylight comes from the NOAA sun math and the pressure deltas are a subtraction of
/// two readings, so they arrive with float artefacts. An F-Droid tester reported seeing the raw
/// values on-screen (fdroiddata!43692).
void main() {
  late MegrimDatabase db;
  late MegrimRepository repo;

  setUp(() {
    db = MegrimDatabase.forTesting(NativeDatabase.memory());
    repo = MegrimRepository(db: db);
  });
  tearDown(() => db.close());

  Future<void> seed({
    double? daylightHours,
    double? tempC,
    double? humidityPct,
    double? pressureHpa,
    double? pressureDelta24h,
    int? aqi,
  }) async {
    final now = DateTime.now().toUtc();
    await db.into(db.migraineEvents).insert(MigraineEventsCompanion.insert(
          id: 'e1',
          startedAt: DateTime.utc(2024, 6, 1, 9),
          createdAt: now,
          updatedAt: now,
        ));
    await db.into(db.derivedFactors).insert(DerivedFactorsCompanion(
          eventId: const Value('e1'),
          season: const Value('Summer'),
          timeOfDayBucket: const Value('morning'),
          moonPhase: const Value('Full Moon'),
          daylightHours: Value(daylightHours),
          tempC: Value(tempC),
          humidityPct: Value(humidityPct),
          pressureHpa: Value(pressureHpa),
          pressureDelta24h: Value(pressureDelta24h),
          aqi: Value(aqi),
          enrichedAt: Value(now),
        ));
  }

  Future<void> pumpDetail(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        MaterialApp(home: EventDetailScreen(repo: repo, eventId: 'e1')));
    await tester.pumpAndSettle();
  }

  testWidgets('rounds the raw float values that enrichment actually produces',
      (tester) async {
    // These are real values: the daylight figure is what computeAstro returns for Boulder on
    // 2024-06-01, and the delta is what 1006.1 - 1012.3 evaluates to in IEEE-754 doubles.
    await seed(
      daylightHours: 14.81900883878691,
      tempC: 22.4999,
      humidityPct: 50.0,
      pressureHpa: 1012.34,
      pressureDelta24h: -6.199999999999932,
      aqi: 42,
    );
    await pumpDetail(tester);

    expect(find.text('14.8 h'), findsOneWidget);
    expect(find.text('22.5 °C'), findsOneWidget);
    expect(find.text('50 %'), findsOneWidget, reason: 'humidity is a whole percent');
    expect(find.text('1012.3 hPa'), findsOneWidget);
    expect(find.text('-6.2 hPa'), findsOneWidget);
    expect(find.text('42'), findsOneWidget, reason: 'AQI is an int and stays as-is');

    // The bug: no raw float precision may reach the screen.
    expect(find.textContaining('14.81900883878691'), findsNothing);
    expect(find.textContaining('6.199999999999932'), findsNothing);
    expect(find.textContaining('50.0 %'), findsNothing);
  });

  testWidgets('a rising pressure delta carries an explicit + sign', (tester) async {
    await seed(pressureDelta24h: 3.0500000000000114);
    await pumpDetail(tester);
    expect(find.text('+3.1 hPa'), findsOneWidget);
  });

  testWidgets('missing values are still omitted entirely', (tester) async {
    await seed(daylightHours: 12.5);
    await pumpDetail(tester);

    expect(find.text('12.5 h'), findsOneWidget);
    // Weather was never fetched, so those rows must not render (not as "0.0" or "null").
    expect(find.textContaining('hPa'), findsNothing);
    expect(find.textContaining('°C'), findsNothing);
    expect(find.textContaining('%'), findsNothing);
  });
}
