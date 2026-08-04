import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/app.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/repositories/megrim_repository.dart';
import 'package:megrim/screens/onboarding_screen.dart';
import 'package:megrim/services/geocoder.dart';

/// A fake Geocoder returning one canned result instantly, so the full onboarding flow (including
/// selecting a location) can be driven end-to-end without a real network call — same
/// dependency-injection pattern already used for http.Client/FilePicker.platform elsewhere.
class _FakeGeocoder extends Geocoder {
  @override
  Future<List<GeoResult>> search(String query) async => const [
        GeoResult(label: 'Boulder, Colorado, United States', lat: 40.0, lon: -105.27),
      ];
}

/// Regression guard: completing onboarding (welcome → disclaimer → home location → Finish) must
/// transition straight to the main shell. Previously this relied on re-fetching a fresh
/// `isOnboarded` Future and waiting on FutureBuilder a second time; Steve reported this getting
/// stuck on a spinner indefinitely on real devices/emulators (Nexus S, Pixel, and previously a
/// Pixel 7 emulator) until the app was force-closed and relaunched — even though the home
/// location had, in fact, already been saved. Fixed by transitioning via a plain bool set
/// directly on completion (see app.dart), removing the async re-fetch from the critical path.
void main() {
  testWidgets(
      'onboarding completes end-to-end and lands on the main shell',
      (tester) async {
    final db = MegrimDatabase.forTesting(NativeDatabase.memory());
    final repo = MegrimRepository(db: db);

    await tester.pumpWidget(MegrimApp(repo: repo, geocoder: _FakeGeocoder()));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Megrim'), findsOneWidget);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Your home location'), findsOneWidget);

    // Search and select a location via the injected fake geocoder (debounced — advance real time).
    await tester.enterText(find.byType(TextField), 'Boulder');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Boulder, Colorado, United States'));
    await tester.pumpAndSettle();

    final continueButton =
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'));
    expect(continueButton.onPressed, isNotNull,
        reason: 'Continue should be enabled once a location is selected');
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    // The weather opt-in step (F-Droid review): switch defaults OFF; finishing without touching
    // it must leave enrichment disabled.
    expect(find.text('Weather enrichment'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse,
        reason: 'weather enrichment must be opt-in, not opt-out');

    await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
    // Bounded pumps, not pumpAndSettle: HomeShell's IndexedStack builds the Analytics tab
    // immediately even though "Log" is the visible one, and Analytics' own load touches
    // connectivity_plus's platform channel, which never resolves without a mock registered in
    // this test suite (a separate, pre-existing gap — AnalyticsScreen can't be pumped to
    // settlement at all right now). That's fine here: this test only needs the Log tab's content.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // The bug: this used to stay on a CircularProgressIndicator indefinitely instead of reaching
    // the main shell, even though the write itself had already succeeded.
    expect(find.text('LOG MIGRAINE'), findsOneWidget);
    expect(find.text('Welcome to Megrim'), findsNothing);
    expect(find.text('Your home location'), findsNothing);

    // The write really did happen (not just the UI transition).
    expect(await repo.isOnboarded, isTrue);
    expect(await repo.weatherEnrichmentEnabled, isFalse,
        reason: 'untouched opt-in switch means enrichment stays off');

    await db.close();
  });

  testWidgets('turning the weather switch on during onboarding persists the opt-in',
      (tester) async {
    final db = MegrimDatabase.forTesting(NativeDatabase.memory());
    final repo = MegrimRepository(db: db);
    var completed = false;

    // OnboardingScreen directly (not MegrimApp) so the run settles — the shell's Analytics tab
    // can't (connectivity_plus platform channel, the documented pre-existing gap).
    await tester.pumpWidget(MaterialApp(
      home: OnboardingScreen(
        repo: repo,
        geocoder: _FakeGeocoder(),
        onComplete: () => completed = true,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Boulder');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Boulder, Colorado, United States'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
    // Bounded pumps: unlike the real app, onComplete here doesn't replace the screen, so the
    // Finish button's saving spinner keeps animating and pumpAndSettle would never settle.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(completed, isTrue);
    expect(await repo.weatherEnrichmentEnabled, isTrue);

    await db.close();
  });
}
