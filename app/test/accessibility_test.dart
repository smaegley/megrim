import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/models/json_fields.dart';
import 'package:megrim/models/med_entry.dart';
import 'package:megrim/repositories/megrim_repository.dart';
import 'package:megrim/screens/event_detail_screen.dart';
import 'package:megrim/screens/history_screen.dart';
import 'package:megrim/screens/manage_vocab_screen.dart';
import 'package:megrim/screens/onboarding_screen.dart';
import 'package:megrim/screens/quick_log_screen.dart';
import 'package:megrim/screens/settings_screen.dart';
import 'package:megrim/theme.dart';

/// Accessibility pass (SPEC Phase 5): touch-target size, tappable-widget labeling, and text
/// contrast, checked automatically via Flutter's built-in accessibility guidelines against every
/// screen this VM can pump (no device/emulator available here). AnalyticsScreen is excluded — its
/// FutureBuilder never settles in this test suite regardless of theme or data (connectivity_plus's
/// platform channel has no mock registered), a pre-existing, documented gap unrelated to
/// accessibility; it needs a manual TalkBack pass on-device instead.
///
/// Each screen is checked in both the light and dark theme, since Megrim follows the system
/// setting and either could independently fail contrast.
void main() {
  late MegrimDatabase db;
  late MegrimRepository repo;

  setUp(() {
    db = MegrimDatabase.forTesting(NativeDatabase.memory());
    repo = MegrimRepository(db: db);
  });
  tearDown(() => db.close());

  // Drift's StreamQueryStore only schedules its query-stream-close timer once a StreamBuilder
  // actually disposes, which the test framework normally defers past the test body — leaving a
  // "Timer is still pending" teardown failure. History's Calendar/List views watch a live stream,
  // so its tests must force early disposal and drain the resulting timer before ending.
  Future<void> disposeAndDrain(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> checkGuidelines(WidgetTester tester, Widget child, ThemeData theme) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(theme: theme, home: child));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  }

  Future<String> seedRichEvent(MegrimRepository repo) async {
    final id = await repo.startEvent(severity: 6);
    await repo.endEvent(id);
    await repo.updateEvent(MigraineEventsCompanion(
      id: Value(id),
      auraPresent: const Value(true),
      auraDescription: const Value('shimmering zigzag lines'),
      locationHead: Value(encodeStringList(['Left temple'])),
      triggersSuspected: Value(encodeStringList(['Stress'])),
      foodsNotable: Value(encodeStringList(['Chocolate'])),
      medsTaken: Value(encodeMeds(
          const [MedEntry(name: 'Sumatriptan', dose: '50 mg', helped: true)])),
      notes: const Value('test notes'),
    ));
    return id;
  }

  for (final theme in [
    (name: 'light', data: megrimLightTheme()),
    (name: 'dark', data: megrimDarkTheme()),
  ]) {
    group('${theme.name} theme', () {
      testWidgets('Onboarding: welcome step', (tester) async {
        await checkGuidelines(
          tester,
          OnboardingScreen(repo: repo, onComplete: () {}),
          theme.data,
        );
      });

      testWidgets('Onboarding: disclaimer step', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(MaterialApp(
          theme: theme.data,
          home: OnboardingScreen(repo: repo, onComplete: () {}),
        ));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Get started'));
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });

      testWidgets('Quick Log: idle view', (tester) async {
        await checkGuidelines(tester, QuickLogScreen(repo: repo), theme.data);
      });

      testWidgets('Quick Log: active (in-progress) view', (tester) async {
        await repo.startEvent(severity: 5);
        await checkGuidelines(tester, QuickLogScreen(repo: repo), theme.data);
      });

      testWidgets('History: empty Calendar view', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(MaterialApp(theme: theme.data, home: HistoryScreen(repo: repo)));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Calendar'));
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
        await disposeAndDrain(tester);
      });

      testWidgets('History: populated List + Calendar views', (tester) async {
        await seedRichEvent(repo);
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(MaterialApp(theme: theme.data, home: HistoryScreen(repo: repo)));
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

        await tester.tap(find.text('Calendar'));
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
        await disposeAndDrain(tester);
      });

      testWidgets('Settings', (tester) async {
        await checkGuidelines(tester, SettingsScreen(repo: repo), theme.data);
      });

      testWidgets('Event Detail: a fully-populated entry', (tester) async {
        final id = await seedRichEvent(repo);
        await checkGuidelines(
          tester,
          EventDetailScreen(repo: repo, eventId: id),
          theme.data,
        );
      });

      testWidgets('Manage Vocab: triggers with entries', (tester) async {
        await repo.addVocab(VocabKind.trigger, 'Stress');
        await repo.addVocab(VocabKind.trigger, 'Caffeine');
        await checkGuidelines(
          tester,
          ManageVocabScreen(repo: repo, kind: VocabKind.trigger, title: 'Triggers'),
          theme.data,
        );
      });
    });
  }
}
