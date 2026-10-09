/// The store-screenshot flow, shared by the device run (`screenshots_test.dart`, via
/// `tools/screenshots.sh`) and a VM check (`test/screenshot_flow_test.dart`) that runs the same
/// steps without capturing, so a UI change that breaks a shot fails `flutter test`.
///
/// Data: the 55 made-up migraines of `test/fixtures/sample-data.json`, moved forward by whole
/// weeks (weekdays stay put) so the latest one was a few days ago, relocated to a New York decoy
/// home (three of them in Chicago, for the Away-from-home card), with weather enrichment OFF so no
/// shot touches the network. Nothing here is real data.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/app.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/models/home_location.dart';
import 'package:megrim/repositories/megrim_repository.dart';
import 'package:megrim/services/app_shortcuts.dart';
import 'package:megrim/services/import_service.dart';

import 'demo_data.dart';

const HomeLocation kDemoHome = HomeLocation(lat: 40.71, lon: -74.01, label: 'New York, NY');
const _awayLat = 41.88, _awayLon = -87.63, _awayLabel = 'Chicago, IL';

/// The shots, in carousel order. `tools/screenshots.py` copies them under these names.
const List<String> kShotNames = [
  '01-log',
  '02-analytics-overview',
  '03-suspected-factors',
  '04-analytics-charts',
  '05-history-list',
  '06-history-calendar',
  '07-entry-detail',
  '08-settings-privacy',
  '09-analytics-dark',
  '10-log-dark',
];

/// The sample export, moved to end a few days before [now] and relocated to the decoy home.
String demoExportJson(DateTime now) {
  final doc = jsonDecode(kDemoExportJson) as Map<String, dynamic>;
  final events = (doc['events'] as List).cast<Map<String, dynamic>>()
    ..sort((a, b) => (a['started_at'] as String).compareTo(b['started_at'] as String));
  final latest = DateTime.parse(events.last['started_at'] as String);
  final weeks = now.toUtc().subtract(const Duration(days: 4)).difference(latest).inDays ~/ 7;
  final shift = Duration(days: weeks * 7);

  String? moved(Object? iso) =>
      iso == null ? null : DateTime.parse(iso as String).add(shift).toUtc().toIso8601String();

  for (var i = 0; i < events.length; i++) {
    final e = events[i];
    for (final k in ['started_at', 'ended_at', 'created_at', 'updated_at']) {
      e[k] = moved(e[k]);
    }
    for (final m in (e['meds_taken'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      m['time'] = moved(m['time']);
    }
    final d = e['derived'] as Map<String, dynamic>?;
    if (d != null) d['enriched_at'] = moved(d['enriched_at']);
    final away = i == 12 || i == 27 || i == 41;
    e['geo_lat'] = away ? _awayLat : kDemoHome.lat;
    e['geo_lon'] = away ? _awayLon : kDemoHome.lon;
    e['geo_label'] = away ? _awayLabel : kDemoHome.label;
  }

  // The most recent migraine runs into a second day and carries details, so the calendar shows a
  // multi-day migraine and the entry-detail shot has medications to show.
  final last = events.last;
  final start = DateTime.parse(last['started_at'] as String);
  last['ended_at'] = start.add(const Duration(hours: 30)).toIso8601String();
  last['severity'] = 7;
  last['triggers_suspected'] = ['Poor sleep', 'Stress', 'Weather / pressure'];
  last['meds_taken'] = [
    {'name': 'Sumatriptan', 'dose': '50 mg', 'helped': true},
    {'name': 'Ibuprofen', 'dose': '400 mg', 'helped': false},
  ];
  last['notes'] = 'Started after a long day at the screen.';

  doc['events'] = events;
  doc['settings'] = {'home_location': kDemoHome.toJson()};
  doc['exported_at'] = now.toUtc().toIso8601String();
  return jsonEncode(doc);
}

/// The sample export exactly as stored, for tests that compare before and after the move.
String demoExportJsonUnshiftedForTest() => kDemoExportJson;

/// Loads the demo data into [repo] and sets the app up as onboarded, weather off, with the backup
/// reminder on and a backup 12 days ago (the green "Last backup" line on the Log screen).
Future<void> seedDemo(MegrimDatabase db, MegrimRepository repo, DateTime now) async {
  await ImportService(db).importJsonString(demoExportJson(now), replace: true);
  await repo.acceptDisclaimer();
  await repo.setHomeLocation(kDemoHome);
  await repo.setWeatherEnrichmentEnabled(false);
  await repo.setBackupReminderDays(30);
  await repo.markBackedUp(now.toUtc().subtract(const Duration(days: 12)));
  // Recompute weekday, season, time of day, moon and daylight for the moved dates and the new
  // home. Weather is off, so this is offline and keeps the sample's stored weather values.
  await repo.reEnrichAll();
}

class _NoShortcuts implements ShortcutSource {
  @override
  Future<String?> initialAction() async => null;
  @override
  void listen(void Function(String action) onAction) {}
}

Widget demoApp(MegrimRepository repo) => MegrimApp(
  repo: repo,
  shortcuts: AppShortcuts(source: _NoShortcuts()),
);

/// Lets real async work (database, file I/O) finish, then settles frames.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Finder _nav(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

Finder get _page =>
    find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);

Future<void> _tab(WidgetTester tester, String label) async {
  await tester.tap(_nav(label));
  await settle(tester);
}

/// Scroll the visible page so [target] sits near the top ([alignment] 0 = top edge).
Future<void> _bringToTop(WidgetTester tester, Finder target, {double alignment = 0.02}) async {
  await tester.scrollUntilVisible(target, 300, scrollable: _page.first);
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(tester.element(target), alignment: alignment);
  await tester.pumpAndSettle();
}

Future<void> _toTop(WidgetTester tester) async {
  tester.state<ScrollableState>(_page.first).position.jumpTo(0);
  await tester.pumpAndSettle();
}

/// Runs every shot in [kShotNames] order. [capture] takes the screenshot (or, in the VM check,
/// just records the name). Each step asserts it reached the right screen before capturing.
Future<void> runShots(
  WidgetTester tester,
  Future<void> Function(String name) capture, {
  required void Function(Brightness? brightness) setBrightness,
}) async {
  setBrightness(Brightness.light);
  await settle(tester);

  // 01 — Log, with the days-since card and the backup line.
  await _tab(tester, 'Log');
  expect(find.text('LOG MIGRAINE'), findsOneWidget);
  expect(find.textContaining('Last backup:'), findsOneWidget);
  await capture(kShotNames[0]);

  // 02 — Analytics from the top: days since, Summary, Migraine days per month.
  await _tab(tester, 'Analytics');
  await _toTop(tester);
  expect(find.text('Migraine days per month'), findsOneWidget);
  await capture(kShotNames[1]);

  // 03 — Top suspected factors.
  await _bringToTop(tester, find.text('Top suspected factors'));
  await capture(kShotNames[2]);

  // 04 — A descriptive chart, expanded.
  final byWeekday = find.text('By day of week');
  await _bringToTop(tester, byWeekday, alignment: 0.15);
  await tester.tap(byWeekday);
  await tester.pumpAndSettle();
  await capture(kShotNames[3]);

  // 05 — History list.
  await _tab(tester, 'History');
  await tester.tap(find.text('List'));
  await settle(tester);
  final tiles = find.descendant(of: find.byType(ListView), matching: find.byType(ListTile));
  expect(tiles, findsWidgets);
  await capture(kShotNames[4]);

  // 06 — History calendar (the latest migraine spans two days).
  await tester.tap(find.text('Calendar'));
  await settle(tester);
  await capture(kShotNames[5]);

  // 07 — Entry detail of the latest migraine (triggers, medications).
  await tester.tap(find.text('List'));
  await settle(tester);
  await tester.tap(tiles.first);
  await settle(tester);
  expect(find.text('Started'), findsOneWidget);
  // Start at the triggers so triggers, sleep and medications are all in frame.
  await _bringToTop(tester, find.text('Suspected triggers'));
  await capture(kShotNames[6]);
  await tester.pageBack();
  await settle(tester);

  // 08 — Settings › Privacy (app lock).
  await _tab(tester, 'Settings');
  await _bringToTop(tester, find.text('App lock'), alignment: 0.3);
  await capture(kShotNames[7]);

  // 09, 10 — dark mode.
  setBrightness(Brightness.dark);
  await settle(tester);
  await _tab(tester, 'Analytics');
  await _toTop(tester);
  await capture(kShotNames[8]);
  await _tab(tester, 'Log');
  await capture(kShotNames[9]);

  setBrightness(null);
  await settle(tester);
}
