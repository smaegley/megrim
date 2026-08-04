import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/repositories/megrim_repository.dart';
import 'package:megrim/screens/analytics_screen.dart';
import 'package:megrim/screens/event_detail_screen.dart';
import 'package:megrim/screens/settings_screen.dart';

/// UI surfaces of the weather-enrichment opt-in (F-Droid review): the Settings toggle, and the
/// "this is blank because enrichment is off" tags on weather-dependent analytics + Event Detail.
///
/// A useful property under test: with enrichment OFF, AnalyticsScreen settles — its
/// `weatherOn && await Connectivity()...` short-circuits, so the connectivity platform channel
/// (unmockable here, the documented gap) is never touched. With enrichment ON that gap remains,
/// which is why every test here runs opted-out.
void main() {
  late MegrimDatabase db;
  late MegrimRepository repo;

  setUp(() {
    db = MegrimDatabase.forTesting(NativeDatabase.memory());
    repo = MegrimRepository(db: db);
  });
  tearDown(() => db.close());

  /// A migraine on [day] with a locally-enriched (weather-less) derived row, bypassing the
  /// enrichment queue entirely so no fake weather client is needed.
  Future<void> seedLocalOnlyEvent(String id, DateTime day) async {
    final now = DateTime.now().toUtc();
    await db.into(db.migraineEvents).insert(MigraineEventsCompanion.insert(
          id: id,
          startedAt: day,
          severity: const Value(5),
          createdAt: now,
          updatedAt: now,
        ));
    await db.into(db.derivedFactors).insert(DerivedFactorsCompanion(
          eventId: Value(id),
          dayOfWeek: const Value(0),
          season: const Value('Summer'),
          timeOfDayBucket: const Value('morning'),
          daylightHours: const Value(14.0),
          moonPhase: const Value('Full Moon'),
          enrichedAt: Value(now),
        ));
  }

  testWidgets('Settings toggle flips the setting and reports each state', (tester) async {
    await tester.pumpWidget(MaterialApp(home: SettingsScreen(repo: repo)));
    await tester.pumpAndSettle();

    expect(await repo.weatherEnrichmentEnabled, isFalse);
    expect(find.text('Off — no automatic network use (only searches you type)'),
        findsOneWidget);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(await repo.weatherEnrichmentEnabled, isTrue);
    expect(
        find.text('Weather enrichment on — fetching weather for your entries…'),
        findsOneWidget);

    // Let the first snackbar expire — ScaffoldMessenger queues them, so the "off" one below
    // wouldn't be visible while the "on" one is still showing.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(await repo.weatherEnrichmentEnabled, isFalse);
    expect(
        find.text('Weather enrichment off — no more automatic network requests.'),
        findsOneWidget);
  });

  testWidgets('Analytics tags the pressure chart and correlations card when opted out',
      (tester) async {
    // Tall viewport: these screens are lazy ListViews, and the widgets under test sit below
    // the fold of the default 800px test surface — unbuilt widgets can't be found.
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // >= kMinEventsForCorrelations events so the correlations card is in its "available" state
    // (the pressure note renders inside it); distinct days for a sane base rate.
    for (var d = 1; d <= 5; d++) {
      await seedLocalOnlyEvent('e$d', DateTime.utc(2024, 6, d, 9));
    }

    await tester.pumpWidget(MaterialApp(home: AnalyticsScreen(repo: repo)));
    await tester.pumpAndSettle();

    expect(find.text('Needs weather enrichment (off) — enable it in Settings'),
        findsOneWidget);
    expect(
        find.textContaining('Pressure isn\'t analysed — weather enrichment is off'),
        findsOneWidget);
    // The non-weather charts must NOT carry the tag — they work fine opted out.
    expect(find.text('No data yet'), findsNothing,
        reason: 'seeded local factors populate every non-weather chart');
  });

  testWidgets('Event Detail explains missing weather rows when opted out', (tester) async {
    // Tall viewport: these screens are lazy ListViews, and the widgets under test sit below
    // the fold of the default 800px test surface — unbuilt widgets can't be found.
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await seedLocalOnlyEvent('e1', DateTime.utc(2024, 6, 1, 9));

    await tester.pumpWidget(
        MaterialApp(home: EventDetailScreen(repo: repo, eventId: 'e1')));
    await tester.pumpAndSettle();

    expect(
        find.text('Weather not fetched — weather enrichment is off (Settings).'),
        findsOneWidget);
  });

  testWidgets('Event Detail shows no such note once opted in', (tester) async {
    // Tall viewport: these screens are lazy ListViews, and the widgets under test sit below
    // the fold of the default 800px test surface — unbuilt widgets can't be found.
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await repo.setWeatherEnrichmentEnabled(true);
    await seedLocalOnlyEvent('e1', DateTime.utc(2024, 6, 1, 9));

    await tester.pumpWidget(
        MaterialApp(home: EventDetailScreen(repo: repo, eventId: 'e1')));
    await tester.pumpAndSettle();

    expect(find.textContaining('weather enrichment is off'), findsNothing);
  });
}
