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
  final List<int> _segmentStarts = <int>[];

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
  DateTime? _pauseStartedAt;
  bool _tracking = false;
  bool _paused = false;
  bool _startNewSegmentOnNextPoint = false;
  Duration _pausedDuration = Duration.zero;
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
  bool get paused => _paused;
  double get distanceMeters => _distanceMeters;
  DateTime? get routeStartedAt => _routeStartedAt;
  DateTime? get routeEndedAt => _routeEndedAt;
  Duration get pausedDuration {
    final livePause = _paused && _pauseStartedAt != null
        ? DateTime.now().difference(_pauseStartedAt!)
        : Duration.zero;
    return _pausedDuration + livePause;
  }

  Duration get elapsed {
    final startedAt = _routeStartedAt;
    if (startedAt == null) return Duration.zero;
    final endedAt = _tracking ? DateTime.now() : (_routeEndedAt ?? DateTime.now());
    final duration = endedAt.difference(startedAt) - pausedDuration;
    return duration.isNegative ? Duration.zero : duration;
  }

  List<MapRoutePoint> get route => List<MapRoutePoint>.unmodifiable(_route);
  List<List<MapRoutePoint>> get routeSegments {
    if (_route.isEmpty) return const <List<MapRoutePoint>>[];
    final starts = _normalizedSegmentStarts();
    final segments = <List<MapRoutePoint>>[];
    for (var index = 0; index < starts.length; index++) {
      final startIndex = starts[index];
      final endIndex = index + 1 < starts.length ? starts[index + 1] : _route.length;
      if (endIndex > startIndex) {
        segments.add(
          List<MapRoutePoint>.unmodifiable(_route.sublist(startIndex, endIndex)),
        );
      }
    }
    return List<List<MapRoutePoint>>.unmodifiable(segments);
  }

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

    _positionSubscription ??= _location.positionStream().listen(
      _acceptPosition,
      onError: (_) {},
    );
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
    _segmentStarts
      ..clear()
      ..add(0);
    _start = currentPoint;
    _end = null;
    _distanceMeters = 0;
    _routeStartedAt = DateTime.now();
    _routeEndedAt = null;
    _pauseStartedAt = null;
    _pausedDuration = Duration.zero;
    _paused = false;
    _startNewSegmentOnNextPoint = false;
    _tracking = true;
    _startElapsedTicker();
    notifyListeners();
    await _persistNow();
  }

  Future<void> pauseRoute() async {
    if (!_tracking || _paused) return;
    _paused = true;
    _pauseStartedAt = DateTime.now();
    notifyListeners();
    await _persistNow();
  }

  Future<void> resumeRoute() async {
    if (!_tracking || !_paused) return;
    final pausedAt = _pauseStartedAt;
    if (pausedAt != null) {
      _pausedDuration += DateTime.now().difference(pausedAt);
    }
    _pauseStartedAt = null;
    _paused = false;
    _startNewSegmentOnNextPoint = true;
    notifyListeners();
    await _persistNow();
  }

  Future<void> finishRoute() async {
    if (!_tracking) return;
    if (_paused && _pauseStartedAt != null) {
      _pausedDuration += DateTime.now().difference(_pauseStartedAt!);
    }
    _pauseStartedAt = null;
    _paused = false;
    _startNewSegmentOnNextPoint = false;
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
    _paused = false;
    _route.clear();
    _segmentStarts.clear();
    _start = null;
    _end = null;
    _distanceMeters = 0;
    _routeStartedAt = null;
    _routeEndedAt = null;
    _pauseStartedAt = null;
    _pausedDuration = Duration.zero;
    _startNewSegmentOnNextPoint = false;
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    notifyListeners();
    await _persistNow();
  }

  String buildGpx({String name = 'Rota Vigia IA'}) {
    if (_route.isEmpty) {
      throw StateError('Não há trajeto para exportar.');
    }
    final escape = const HtmlEscape(HtmlEscapeMode.element);
    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln(
        '<gpx version="1.1" creator="Vigia IA" '
        'xmlns="http://www.topografix.com/GPX/1/1" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:schemaLocation="http://www.topografix.com/GPX/1/1 '
        'http://www.topografix.com/GPX/1/1/gpx.xsd">',
      )
      ..writeln('  <metadata>')
      ..writeln('    <name>${escape.convert(name)}</name>');
    final metadataTime = _routeStartedAt ?? _route.first.recordedAt;
    buffer
      ..writeln('    <time>${metadataTime.toUtc().toIso8601String()}</time>')
      ..writeln('  </metadata>')
      ..writeln('  <trk>')
      ..writeln('    <name>${escape.convert(name)}</name>');
    for (final segment in routeSegments) {
      buffer.writeln('    <trkseg>');
      for (final point in segment) {
        buffer
          ..writeln(
            '      <trkpt lat="${point.latitude.toStringAsFixed(7)}" '
            'lon="${point.longitude.toStringAsFixed(7)}">',
          )
          ..writeln(
            point.altitudeMeters == null
                ? ''
                : '        <ele>${point.altitudeMeters!.toStringAsFixed(2)}</ele>',
          )
          ..writeln('        <time>${point.recordedAt.toUtc().toIso8601String()}</time>')
          ..writeln('      </trkpt>');
      }
      buffer.writeln('    </trkseg>');
    }
    buffer
      ..writeln('  </trk>')
      ..writeln('</gpx>');
    return buffer.toString();
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
    if (_tracking && !_paused) {
      if (_startNewSegmentOnNextPoint) {
        if (_route.isNotEmpty) _segmentStarts.add(_route.length);
        _route.add(point);
        _startNewSegmentOnNextPoint = false;
        _schedulePersist();
      } else {
        final step = _route.isEmpty
            ? double.infinity
            : LocationTrackingService.distanceMeters(_route.last, point);
        if (_route.isNotEmpty && step >= 2 && step <= 250) {
          _distanceMeters += step;
        }
        if (_route.isEmpty || step >= 2) {
          if (_route.isEmpty && _segmentStarts.isEmpty) _segmentStarts.add(0);
          _route.add(point);
          _schedulePersist();
        }
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

  List<int> _normalizedSegmentStarts() {
    if (_route.isEmpty) return const <int>[];
    final starts = <int>{0};
    for (final value in _segmentStarts) {
      if (value >= 0 && value < _route.length) starts.add(value);
    }
    final sorted = starts.toList()..sort();
    return sorted;
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
      _paused = _tracking && (json['paused'] as bool? ?? false);
      _distanceMeters = (json['distanceMeters'] as num?)?.toDouble() ?? 0;
      _routeStartedAt = _date(json['routeStartedAt']);
      _routeEndedAt = _date(json['routeEndedAt']);
      _pauseStartedAt = _paused ? _date(json['pauseStartedAt']) : null;
      _pausedDuration = Duration(
        milliseconds: (json['pausedDurationMs'] as num?)?.toInt() ?? 0,
      );
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
      final rawStarts = json['segmentStarts'];
      _segmentStarts.clear();
      if (rawStarts is List) {
        _segmentStarts.addAll(
          rawStarts.whereType<num>().map((value) => value.toInt()),
        );
      }
      if (_route.isNotEmpty && _segmentStarts.isEmpty) _segmentStarts.add(0);
      if (_tracking && _routeStartedAt == null) {
        _tracking = false;
        _paused = false;
        _pauseStartedAt = null;
      }
    } catch (_) {
      _route.clear();
      _segmentStarts.clear();
      _tracking = false;
      _paused = false;
      _distanceMeters = 0;
      _routeStartedAt = null;
      _routeEndedAt = null;
      _pauseStartedAt = null;
      _pausedDuration = Duration.zero;
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
      'schema': 2,
      'monitorVisibility': _monitorVisibility.name,
      'tracking': _tracking,
      'paused': _paused,
      'pausedDurationMs': _pausedDuration.inMilliseconds,
      'pauseStartedAt': _pauseStartedAt?.toIso8601String(),
      'distanceMeters': _distanceMeters,
      'routeStartedAt': _routeStartedAt?.toIso8601String(),
      'routeEndedAt': _routeEndedAt?.toIso8601String(),
      'current': _current?.toJson(),
      'start': _start?.toJson(),
      'end': _end?.toJson(),
      'segmentStarts': _normalizedSegmentStarts(),
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
