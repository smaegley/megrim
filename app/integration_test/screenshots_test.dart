import 'dart:io' show Platform;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:megrim/database/database.dart';
import 'package:megrim/repositories/megrim_repository.dart';

import 'shots.dart';

/// Store screenshots on a real emulator/Simulator. Run through `tools/screenshots.sh <target>`,
/// which boots the device, runs this with `flutter drive`, and sorts the PNGs into the store
/// folders. Uses an in-memory database, so the device's own Megrim dev data is never touched.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('store screenshots', (tester) async {
    final db = MegrimDatabase.forTesting(NativeDatabase.memory());
    final repo = MegrimRepository(db: db);
    await seedDemo(db, repo, DateTime.now());

    await tester.pumpWidget(demoApp(repo));
    // Android draws through a platform view by default; capturing needs the Flutter surface
    // converted to an image first. iOS captures directly.
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
    await settle(tester);

    await runShots(
      tester,
      (name) async {
        await tester.pumpAndSettle();
        await binding.takeScreenshot(name);
      },
      setBrightness: (b) {
        if (b == null) {
          tester.platformDispatcher.clearPlatformBrightnessTestValue();
        } else {
          tester.platformDispatcher.platformBrightnessTestValue = b;
        }
      },
    );
  });
}
