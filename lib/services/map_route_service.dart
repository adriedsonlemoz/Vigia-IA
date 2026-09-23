import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/map_route_point.dart';
import 'location_tracking_service.dart';

enum MonitorMapVisibilityMode { automatic, always, hidden }

class MapRouteService extends ChangeNotifier {
  MapRouteService._();

  static final MapRouteService instance = MapRouteService._();

  final LocationTrackingService _location = LocationTrackingService.instance;
  final List<MapRoutePoint> _route = <MapRoutePoint>[];

  StreamSubscription<MapRoutePoint>? _positionSubscription;
  Timer? _elapsedTimer;
  Timer? _persistDebounce;
  Future<void>? _initializing;
  File? _file;
  bool _initialized = false;
  bool _loading = false;
  LocationTrackingAvailability? _availability;
  MapRoutePoint? _current;
  MapRoutePoint? _start;
  MapRoutePoint? _end;
  DateTime? _routeStartedAt;
  DateTime? _routeEndedAt;
  bool _tracking = false;
  double _distanceMeters = 0;
  MonitorMapVisibilityMode _monitorVisibility =
      MonitorMapVisibilityMode.automatic;

  bool get initialized => _initialized;
  bool get loading => _loading;
  LocationTrackingAvailability? get availability => _availability;
  MapRoutePoint? get current => _current;
  MapRoutePoint? get start => _start;
  MapRoutePoint? get end => _end;
  bool get tracking => _tracking;
  double get distanceMeters => _distanceMeters;
  DateTime? get routeStartedAt => _routeStartedAt;
  Duration get elapsed {
    final startedAt = _routeStartedAt;
    if (startedAt == null) return Duration.zero;
    return (_tracking ? DateTime.now() : (_routeEndedAt ?? DateTime.now()))
        .difference(startedAt);
  }
  List<MapRoutePoint> get route => List<MapRoutePoint>.unmodifiable(_route);
  MonitorMapVisibilityMode get monitorVisibility => _monitorVisibility;

  bool get hasRecentMovement {
    final point = _current;
    if (point == null) return false;
    if (DateTime.now().difference(point.recordedAt) > const Duration(seconds: 20)) {
      return false;
    }
    return point.accuracyMeters <= 50 && point.speedKilometersPerHour >= 4;
  }

  Future<void> initialize({bool requestPermission = false}) {
    final pending = _initializing;
    if (pending != null) return pending;
    final operation = _initializeInternal(requestPermission: requestPermission);
    _initializing = operation;
    return operation.whenComplete(() => _initializing = null);
  }

  Future<void> _initializeInternal({required bool requestPermission}) async {
    if (!_initialized) {
      final root = await getApplicationSupportDirectory();
      _file = File('${root.path}${Platform.pathSeparator}map_route_state.json');
      await _restore();
      _initialized = true;
      if (_tracking) _startElapsedTicker();
    }
    await ensureLocation(requestPermission: requestPermission);
  }

  Future<LocationTrackingAvailability> ensureLocation({
    bool requestPermission = true,
  }) async {
    if (_loading) {
      return _availability ?? LocationTrackingAvailability.permissionDenied;
    }
    _loading = true;
    notifyListeners();
    final availability = await _location.ensureAvailable(
      requestPermission: requestPermission,
    );
    _availability = availability;
    _loading = false;
    notifyListeners();
    if (availability != LocationTrackingAvailability.ready) {
      await _positionSubscription?.cancel();
      _positionSubscription = null;
      return availability;
    }

    try {
      final point = await _location.currentPosition();
      _acceptPosition(point);
    } catch (_) {
      // O stream contínuo ainda pode se recuperar se a leitura pontual falhar.
    }

    if (_positionSubscription == null) {
      _positionSubscription = _location.positionStream().listen(
        _acceptPosition,
        onError: (_) {},
      );
    }
    return availability;
  }

  Future<void> setMonitorVisibility(MonitorMapVisibilityMode value) async {
    await initialize(requestPermission: false);
    if (_monitorVisibility == value) return;
    _monitorVisibility = value;
    notifyListeners();
    await _persistNow();
  }

  Future<void> startRoute() async {
    await initialize(requestPermission: true);
    final currentPoint = _current;
    if (currentPoint == null) return;
    _route
      ..clear()
      ..add(currentPoint);
    _start = currentPoint;
    _end = null;
    _distanceMeters = 0;
    _routeStartedAt = DateTime.now();
    _routeEndedAt = null;
    _tracking = true;
    _startElapsedTicker();
    notifyListeners();
    await _persistNow();
  }

  Future<void> finishRoute() async {
    if (!_tracking) return;
    _tracking = false;
    _end = _current;
    _routeEndedAt = DateTime.now();
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    notifyListeners();
    await _persistNow();
  }

  Future<void> clearRoute() async {
    _tracking = false;
    _route.clear();
    _start = null;
    _end = null;
    _distanceMeters = 0;
    _routeStartedAt = null;
    _routeEndedAt = null;
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    notifyListeners();
    await _persistNow();
  }

  bool shouldShowInMonitor({required bool bikeConnected}) {
    return switch (_monitorVisibility) {
      MonitorMapVisibilityMode.always => true,
      MonitorMapVisibilityMode.hidden => false,
      MonitorMapVisibilityMode.automatic =>
        bikeConnected || _tracking || hasRecentMovement,
    };
  }

  void _acceptPosition(MapRoutePoint point) {
    _current = point;
    if (_tracking) {
      if (_route.isNotEmpty) {
        final step = LocationTrackingService.distanceMeters(_route.last, point);
        if (step >= 2 && step <= 250) _distanceMeters += step;
      }
      if (_route.isEmpty ||
          LocationTrackingService.distanceMeters(_route.last, point) >= 2) {
        _route.add(point);
        _schedulePersist();
      }
    }
    notifyListeners();
  }

  void _startElapsedTicker() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_tracking) notifyListeners();
    });
  }

  void _schedulePersist() {
    if (_persistDebounce?.isActive ?? false) return;
    _persistDebounce = Timer(const Duration(seconds: 10), () {
      _persistDebounce = null;
      unawaited(_persistNow());
    });
  }

  Future<void> _restore() async {
    final file = _file;
    if (file == null || !await file.exists()) return;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return;
      final json = Map<String, dynamic>.from(decoded);
      final modeName = json['monitorVisibility'] as String?;
      _monitorVisibility = MonitorMapVisibilityMode.values.firstWhere(
        (value) => value.name == modeName,
        orElse: () => MonitorMapVisibilityMode.automatic,
      );
      _tracking = json['tracking'] as bool? ?? false;
      _distanceMeters = (json['distanceMeters'] as num?)?.toDouble() ?? 0;
      _routeStartedAt = _date(json['routeStartedAt']);
      _routeEndedAt = _date(json['routeEndedAt']);
      _current = _point(json['current']);
      _start = _point(json['start']);
      _end = _point(json['end']);
      final rawRoute = json['route'];
      if (rawRoute is List) {
        _route
          ..clear()
          ..addAll(
            rawRoute.whereType<Map>().map(
                  (raw) => MapRoutePoint.fromJson(
                    Map<String, dynamic>.from(raw),
                  ),
                ),
          );
      }
      if (_tracking && _routeStartedAt == null) {
        _tracking = false;
      }
    } catch (_) {
      _route.clear();
      _tracking = false;
      _distanceMeters = 0;
      _routeStartedAt = null;
      _routeEndedAt = null;
      _start = null;
      _end = null;
    }
  }

  MapRoutePoint? _point(Object? raw) {
    if (raw is! Map) return null;
    try {
      return MapRoutePoint.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }

  DateTime? _date(Object? raw) {
    if (raw is! String) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> _persistNow() async {
    final file = _file;
    if (file == null) return;
    _persistDebounce?.cancel();
    _persistDebounce = null;
    final temporary = File('${file.path}.tmp');
    final payload = <String, Object?>{
      'schema': 1,
      'monitorVisibility': _monitorVisibility.name,
      'tracking': _tracking,
      'distanceMeters': _distanceMeters,
      'routeStartedAt': _routeStartedAt?.toIso8601String(),
      'routeEndedAt': _routeEndedAt?.toIso8601String(),
      'current': _current?.toJson(),
      'start': _start?.toJson(),
      'end': _end?.toJson(),
      'route': _route.map((point) => point.toJson()).toList(growable: false),
    };
    try {
      await temporary.writeAsString(jsonEncode(payload), flush: true);
      if (await file.exists()) await file.delete();
      await temporary.rename(file.path);
    } catch (_) {
      if (await temporary.exists()) await temporary.delete();
    }
  }
}
