import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Watches network connectivity and fires [onOnline] each time the device transitions from
/// offline to online, so the enrichment queue can be drained when the network returns
/// (SPEC §5.1 — connectivity-triggered retry).
///
/// The connectivity stream is injectable so this is unit-testable without platform channels.
/// `onConnectivityChanged` only emits on *changes* (not the current state), so the initial
/// online-ness is assumed offline: the first observed online state therefore counts as a
/// transition and triggers a (harmless, idempotent) drain.
class ConnectivityMonitor {
  final Stream<List<ConnectivityResult>> _stream;
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _wasOnline;

  ConnectivityMonitor({
    Stream<List<ConnectivityResult>>? stream,
    bool initiallyOnline = false,
  })  : _stream = stream ?? Connectivity().onConnectivityChanged,
        _wasOnline = initiallyOnline;

  static bool _isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  /// Begin listening. [onOnline] is invoked on each offline→online transition.
  void start(void Function() onOnline) {
    _sub = _stream.listen((results) {
      final online = _isOnline(results);
      if (online && !_wasOnline) onOnline();
      _wasOnline = online;
    });
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}
