import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Host side of the store-screenshot run: writes each PNG the app sends to
/// `$MEGRIM_SHOTS_DIR/NAME.png` (default `build/screenshots/raw`). tools/screenshots.sh sets it.
Future<void> main() => integrationDriver(
  onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
    final dir = Platform.environment['MEGRIM_SHOTS_DIR'] ?? 'build/screenshots/raw';
    final file = File('$dir/$name.png');
    await file.create(recursive: true);
    await file.writeAsBytes(bytes);
    stdout.writeln('SHOT $name → ${file.path}');
    return true;
  },
);
