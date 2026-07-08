import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:megrim/services/connectivity_monitor.dart';

/// The enrichment-retry trigger must fire only on an offline→online transition — not on every
/// connectivity tick — so we don't hammer Open-Meteo while already online.
void main() {
  test('fires onOnline only on offline→online transitions', () async {
    final controller = StreamController<List<ConnectivityResult>>();
    final monitor = ConnectivityMonitor(stream: controller.stream);
    var fires = 0;
    monitor.start(() => fires++);

    // Starts assumed-offline. First online event = a transition → fire.
    controller.add([ConnectivityResult.wifi]);
    await Future<void>.delayed(Duration.zero);
    expect(fires, 1);

    // Still online (wifi→mobile) → no new fire.
    controller.add([ConnectivityResult.mobile]);
    await Future<void>.delayed(Duration.zero);
    expect(fires, 1);

    // Drops offline → no fire.
    controller.add([ConnectivityResult.none]);
    await Future<void>.delayed(Duration.zero);
    expect(fires, 1);

    // Comes back online → fire again.
    controller.add([ConnectivityResult.wifi]);
    await Future<void>.delayed(Duration.zero);
    expect(fires, 2);

    await monitor.dispose();
    await controller.close();
  });
}
