import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/map_connectivity_status.dart';

typedef MapConnectivityProbe = Future<bool> Function();

class MapConnectivityService extends ChangeNotifier {
  MapConnectivityService({
    MapConnectivityProbe? probe,
    this.probeInterval = const Duration(seconds: 15),
    this.failuresBeforeOffline = 2,
  }) : _probe = probe ?? _defaultProbe;

  static final MapConnectivityService instance = MapConnectivityService();

  final MapConnectivityProbe _probe;
  final Duration probeInterval;
  final int failuresBeforeOffline;
  final Set<Object> _consumers = <Object>{};

  Timer? _timer;
  bool _checking = false;
  int _consecutiveFailures = 0;
  MapConnectivityState _state = MapConnectivityState.unknown;
  DateTime? _lastCheckedAt;

  MapConnectivityState get state => _state;
  DateTime? get lastCheckedAt => _lastCheckedAt;
  bool get isOnline => _state.isOnline;
  bool get isOffline => _state.isOffline;
  bool get checking => _checking;

  Future<void> acquire(Object consumer) async {
    final first = _consumers.isEmpty;
    _consumers.add(consumer);
    if (first) {
      _timer?.cancel();
      _timer = Timer.periodic(
        probeInterval,
        (_) => unawaited(checkNow()),
      );
    }
    await checkNow(force: true);
  }

  void release(Object consumer) {
    _consumers.remove(consumer);
    if (_consumers.isNotEmpty) return;
    _timer?.cancel();
    _timer = null;
  }

  Future<MapConnectivityState> checkNow({bool force = false}) async {
    if (_checking) return _state;
    if (!force && _consumers.isEmpty) return _state;
    _checking = true;
    final previous = _state;
    try {
      final online = await _probe();
      _lastCheckedAt = DateTime.now();
      if (online) {
        _consecutiveFailures = 0;
        _state = MapConnectivityState.online;
      } else {
        _registerFailure();
      }
    } catch (_) {
      _lastCheckedAt = DateTime.now();
      _registerFailure();
    } finally {
      _checking = false;
    }
    if (_state != previous) notifyListeners();
    return _state;
  }

  void _registerFailure() {
    _consecutiveFailures += 1;
    final threshold = failuresBeforeOffline < 1 ? 1 : failuresBeforeOffline;
    if (_state == MapConnectivityState.unknown ||
        _consecutiveFailures >= threshold) {
      _state = MapConnectivityState.offline;
    }
  }

  static Future<bool> _defaultProbe() async {
    final hosts = <String>[
      'valhalla1.openstreetmap.de',
      'overpass-api.de',
    ];
    for (final host in hosts) {
      try {
        final addresses = await InternetAddress.lookup(host)
            .timeout(const Duration(seconds: 4));
        if (addresses.isNotEmpty &&
            addresses.any((item) => item.rawAddress.isNotEmpty)) {
          return true;
        }
      } catch (_) {
        // Tenta a segunda origem usada pelo mapa antes de concluir offline.
      }
    }
    return false;
  }
}
