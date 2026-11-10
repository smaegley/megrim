import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/l10n/l10n.dart';
import 'package:megrim/repositories/megrim_repository.dart';
import 'package:megrim/services/report_pdf.dart';
import 'package:pdf/pdf.dart' show TtfParser;

import '../integration_test/shots.dart';

/// Renders the app's screens to PNG for a visual review, in several configurations: languages,
/// themes, text sizes and screen widths. Not part of `flutter test` (it lives outside test/);
/// run it with `tools/review_screens.sh`, which also builds contact sheets.
///
/// Output: `build/review/<config>/<NN-name>.png`, `report.pdf`, and `problems.txt` (layout overflows
/// and steps that failed, collected instead of stopping the run).
///
/// The renders use Roboto (Flutter's bundled copy) rather than each phone's system font, and show
/// no animation. They catch layout and text problems, not how the app feels on a device.
void main() {
  final only = Platform.environment['REVIEW_CONFIGS']?.split(',').toSet();

  setUpAll(() async {
    final fonts = '${Platform.environment['FLUTTER_ROOT'] ?? '${Platform.environment['HOME']}/flutter'}'
        '/bin/cache/artifacts/material_fonts';
    await _loadFont('Roboto', [
      for (final w in ['Regular', 'Italic', 'Medium', 'Bold']) '$fonts/Roboto-$w.ttf',
    ]);
    await _loadFont('MaterialIcons', ['$fonts/MaterialIcons-Regular.otf']);
  });

  setUp(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockStreamHandler(
      const EventChannel('dev.fluttercommunity.plus/connectivity_status'),
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (_) async => ['none'],
    );
  });

  for (final c in _configs) {
    if (only != null && !only.contains(c.name)) continue;
    testWidgets('review ${c.name}', (tester) async {
      final r = _Review(tester, c);
      await r.run();
    }, skip: c.needsPseudo && !AppLocalizations.supportedLocales.contains(_pseudo));
  }
}

const _pseudo = Locale('en', 'XA');

class _Config {
  final String name;
  final List<Locale> locales;
  final double textScale;
  final Size size; // logical pixels
  final bool full; // every screen, or only the store shots
  const _Config(this.name, this.locales,
      {this.textScale = 1, this.size = const Size(412, 892), this.full = true});
  bool get needsPseudo => locales.contains(_pseudo);
}

const _configs = [
  _Config('en-US', [Locale('en', 'US')]),
  _Config('en-GB', [Locale('en', 'GB')], full: false),
  _Config('de-DE', [Locale('de', 'DE')], full: false),
  _Config('pseudo', [_pseudo]),
  _Config('large-text', [Locale('en', 'US')], textScale: 1.5),
  _Config('narrow', [Locale('en', 'US')], size: Size(320, 640)),
];

class _Review {
  final WidgetTester tester;
  final _Config c;
  late final Directory dir;
  final problems = <String>[];
  var step = '';
  var n = 0;

  _Review(this.tester, this.c) {
    // build/review/ holds only this tool's output: start each config afresh.
    dir = Directory('build/review/${c.name}');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
  }

  AppLocalizations get l => AppLocalizations.of(tester.element(find.byType(Scaffold).first));

  Future<void> run() async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = c.size * 2;
    tester.platformDispatcher.localesTestValue = c.locales;
    tester.platformDispatcher.textScaleFactorTestValue = c.textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    // flutter_test draws shadows as hard black edges; draw them as the phone does.
    debugDisableShadows = false; // reset in the finally below, before the binding checks it
    final previous = FlutterError.onError;
    FlutterError.onError = (d) {
      final first = d.exceptionAsString().split('\n').first;
      problems.add('[$step] $first');
    };
    try {
      await _onboarding();
      final db = MegrimDatabase.forTesting(NativeDatabase.memory());
      final repo = MegrimRepository(db: db);
      await tester.runAsync(() => seedDemo(db, repo, DateTime.now()));
      await _pumpApp(repo);
      await _storeShots();
      if (c.full) await _moreScreens();
      await _report(repo);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(() => db.close());
    } finally {
      debugDisableShadows = true;
      FlutterError.onError = previous;
      File('${dir.path}/problems.txt').writeAsStringSync(
          problems.isEmpty ? 'none\n' : '${problems.toSet().join('\n')}\n');
    }
  }

  Future<void> _pumpApp(MegrimRepository repo) async {
    await tester.pumpWidget(RepaintBoundary(
      key: const Key('review'),
      child: demoApp(repo, supportedLocales: const [Locale('en'), _pseudo]),
    ));
    await settle(tester);
  }

  Future<void> _shot(String name) async {
    n++;
    final rb = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('review')));
    final bytes = await tester.runAsync(() async {
      final img = await rb.toImage(pixelRatio: 1);
      return img.toByteData(format: ui.ImageByteFormat.png);
    });
    File('${dir.path}/${n.toString().padLeft(2, '0')}-$name.png')
        .writeAsBytesSync(bytes!.buffer.asUint8List());
  }

  /// Runs [body]; a failure is recorded and the review goes on.
  Future<void> _try(String name, Future<void> Function() body) async {
    step = name;
    try {
      await body();
    } catch (e, st) {
      final where = st.toString().split('\n').firstWhere(
          (f) => f.contains('package:megrim/') || f.contains('review_screens_test'),
          orElse: () => '');
      problems.add('[$name] step failed: ${e.toString().split('\n').first}  ${where.trim()}');
    }
  }

  Future<void> _onboarding() => _try('onboarding', () async {
        final db = MegrimDatabase.forTesting(NativeDatabase.memory());
        final repo = MegrimRepository(db: db);
        try {
          await _pumpApp(repo);
          await _shot('onboarding-welcome');
          await tester.tap(find.text(l.onboardingGetStarted));
          await settle(tester);
          await _shot('onboarding-disclaimer');
          await tester.tap(find.text(l.onboardingAccept));
          await settle(tester);
          await tester.tap(find.text(l.onboardingContinue));
          await settle(tester);
          await _shot('onboarding-home');
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 1));
          await tester.runAsync(() => db.close());
        }
      });

  Future<void> _storeShots() => _try('store shots', () async {
        await runShots(tester, (name) async {
          step = name;
          await _shot(name);
        }, setBrightness: (b) {
          if (b == null) {
            tester.platformDispatcher.clearPlatformBrightnessTestValue();
          } else {
            tester.platformDispatcher.platformBrightnessTestValue = b;
          }
        });
      });

  Finder get _page =>
      find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);

  /// Every page of the current scrolling screen, top to bottom.
  Future<void> _pages(String name) async {
    final state = tester.state<ScrollableState>(_page.first);
    state.position.jumpTo(0);
    await tester.pumpAndSettle();
    for (var i = 1; i <= 12; i++) {
      await _shot('$name-p$i');
      final pos = state.position;
      if (pos.pixels >= pos.maxScrollExtent - 1) break;
      pos.jumpTo((pos.pixels + pos.viewportDimension * 0.85).clamp(0, pos.maxScrollExtent));
      await tester.pumpAndSettle();
    }
    state.position.jumpTo(0);
    await tester.pumpAndSettle();
  }

  /// Taps [target] after scrolling it into view (on a small screen it may be below the fold).
  Future<void> _tapOn(Finder target) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
  }

  /// Scrolls the current screen from the top until [target] is visible.
  Future<void> _scrollTo(Finder target) async {
    tester.state<ScrollableState>(_page.first).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(target, 300, scrollable: _page.first);
    await tester.pumpAndSettle();
  }

  Future<void> _tab(String label) async {
    await tester.tap(
        find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
    await settle(tester);
  }

  Future<void> _back() async {
    await tester.pageBack();
    await settle(tester);
  }

  /// Closes the dialog or sheet on top, as a user would: a tap outside it.
  Future<void> _dismissDialog() async {
    await tester.tapAt(const Offset(4, 4));
    await settle(tester);
  }

  Future<void> _moreScreens() async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await settle(tester);

    await _try('analytics pages', () async {
      await _tab(l.homeTabAnalytics);
      await _pages('analytics');
    });
    await _try('settings pages', () async {
      await _tab(l.homeTabSettings);
      await _pages('settings');
    });
    await _try('entry pages', () async {
      await _tab(l.homeTabHistory);
      await _tapOn(find.text(l.historyViewList));
      await settle(tester);
      await tester.tap(find.byType(ListTile).first);
      await settle(tester);
      await _pages('entry');
    });
    await _try('manage symptoms', () async {
      final manage = find.text(l.commonManage);
      await _scrollTo(find.text(l.entrySymptoms));
      await tester.pumpAndSettle();
      final row = find.ancestor(of: find.text(l.entrySymptoms), matching: find.byType(Row)).first;
      await tester.tap(find.descendant(of: row, matching: manage));
      await settle(tester);
      await _shot('manage-symptoms');
      await _back();
      await _back(); // the entry
    });
    await _try('history calendar day sheet', () async {
      await _tapOn(find.text(l.historyViewCalendar));
      await settle(tester);
      await _shot('history-calendar');
      // The 1st of the month shown is in the past or today: tap it for the day sheet.
      await _tapOn(find.text('1').first);
      await settle(tester);
      await _shot('history-day-sheet');
      await _dismissDialog();
    });
    await _try('log migraine', () async {
      await _tab(l.homeTabLog);
      await _tapOn(find.text(l.quickLogStart));
      await settle(tester);
      await settle(tester); // the first start offers the in-progress notification, after a check
      if (find.text(l.quickLogNotNow).evaluate().isNotEmpty) {
        await _shot('log-offer-ongoing');
        await _tapOn(find.text(l.quickLogNotNow));
        await settle(tester);
      }
      await _shot('log-active');
      await _tapOn(find.text(l.quickLogDiscard).last);
      await settle(tester);
      await _shot('log-discard-dialog');
      await _tapOn(find.text(l.quickLogDiscard).last);
      await settle(tester);
    });
    await _try('check-in', () async {
      await _tab(l.homeTabLog);
      // The demo data may already have today's check-in.
      if (find.text(l.quickLogNoMigraineToday).evaluate().isNotEmpty) {
        await _tapOn(find.text(l.quickLogNoMigraineToday));
        await settle(tester);
      }
      await _shot('log-checked-in');
      await _tapOn(find.text(l.quickLogAddDetails));
      await settle(tester);
      await _pages('checkin');
      await _back();
    });
    await _try('medications', () async {
      await _tab(l.homeTabSettings);
      await _scrollTo(find.text(l.settingsManageMedications));
      await _tapOn(find.text(l.settingsManageMedications));
      await settle(tester);
      await _shot('medications');
      await _back();
    });
    await _try('backup reminder dialog', () async {
      await _scrollTo(find.text(l.settingsLastBackup));
      await _tapOn(find.text(l.settingsLastBackup));
      await settle(tester);
      await _shot('backup-reminder-dialog');
      await _dismissDialog();
    });
    await _try('daily reminder dialog', () async {
      await _scrollTo(find.text(l.settingsDailyReminder));
      await _tapOn(find.text(l.settingsDailyReminder));
      await settle(tester);
      await _shot('daily-reminder-dialog');
      await _dismissDialog();
    });
    await _try('about', () async {
      await _scrollTo(find.text(l.settingsAbout));
      await _tapOn(find.text(l.settingsAbout));
      await settle(tester);
      await _shot('about');
      await _dismissDialog();
    });
  }

  /// The PDF report, as Settings › Export report builds it.
  Future<void> _report(MegrimRepository repo) => _try('report', () async {
        final l10n = lookupAppLocalizations(basicLocaleListResolution(
            c.locales, const [Locale('en'), _pseudo]));
        final bytes = await tester.runAsync(() async {
          final regular = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
          final bold = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
          final coverage = TtfParser(regular).charToGlyphIndexMap;
          final content = await repo.reportContent(canRender: coverage.containsKey, l10n: l10n);
          return renderReportPdf(content, regular: regular, bold: bold, l10n: l10n);
        });
        File('${dir.path}/report.pdf').writeAsBytesSync(bytes!);
      });
}

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    final f = File(p);
    if (f.existsSync()) loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
  }
  await loader.load();
}
