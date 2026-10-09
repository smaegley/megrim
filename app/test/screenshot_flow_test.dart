import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/repositories/megrim_repository.dart';

import '../integration_test/shots.dart';

/// Runs the store-screenshot flow (integration_test/shots.dart) on the VM without capturing, so a
/// UI change that breaks a shot fails here instead of in the middle of a device run.
void main() {
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

  test('demo data: ends a few days ago, decoy home, weekdays kept, nothing real', () {
    final now = DateTime.utc(2026, 10, 9, 12);
    final doc = jsonDecode(demoExportJson(now)) as Map<String, dynamic>;
    final events = (doc['events'] as List).cast<Map<String, dynamic>>();
    expect(events, hasLength(55));
    final latest = events
        .map((e) => DateTime.parse(e['started_at'] as String))
        .reduce((a, b) => a.isAfter(b) ? a : b);
    expect(now.difference(latest).inDays, inInclusiveRange(4, 10));
    expect(doc['settings'], {'home_location': kDemoHome.toJson()});
    expect(events.where((e) => e['geo_label'] == 'Chicago, IL'), hasLength(3));
    expect(events.every((e) => e['geo_label'] != 'Boulder, Colorado, United States'), isTrue);
    // Whole-week shift: every entry keeps its weekday.
    final original = (jsonDecode(demoExportJsonUnshiftedForTest()) as Map)['events'] as List;
    final byId = {for (final e in original.cast<Map>()) e['id']: e};
    for (final e in events) {
      final before = DateTime.parse(byId[e['id']]!['started_at'] as String);
      expect(DateTime.parse(e['started_at'] as String).weekday, before.weekday);
    }
  });

  testWidgets('every shot step reaches its screen', (tester) async {
    tester.view.physicalSize = const Size(1320, 2868);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final db = MegrimDatabase.forTesting(NativeDatabase.memory());
    final repo = MegrimRepository(db: db);
    await tester.runAsync(() => seedDemo(db, repo, DateTime.now()));

    await tester.pumpWidget(demoApp(repo));
    await settle(tester);
    final shots = <String>[];
    await runShots(
      tester,
      (name) async => shots.add(name),
      setBrightness: (b) {
        if (b == null) {
          tester.platformDispatcher.clearPlatformBrightnessTestValue();
        } else {
          tester.platformDispatcher.platformBrightnessTestValue = b;
        }
      },
    );
    expect(shots, kShotNames);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(() => db.close());
  });
}
