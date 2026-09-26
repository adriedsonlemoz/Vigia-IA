import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart' as ml;

import '../models/map_cycling_route.dart';
import '../models/map_navigation_target.dart';
import '../models/map_route_point.dart';
import '../models/map_travel_mode.dart';
import '../services/error_log_service.dart';
import '../services/performance_telemetry_service.dart';
import '../services/map_view_policy.dart';

/// Renderer dedicado ao modo de navegação em perspectiva.
///
/// O mapa exploratório continua em flutter_map e permanece montado por baixo
/// deste renderer. O MapLibre só deve ser revelado pelo pai após [onReady],
/// quando mapa, estilo, rota, câmera e o primeiro ciclo ocioso estiverem prontos.
class MapNavigation3DView extends StatefulWidget {
  const MapNavigation3DView({
    super.key,
    required this.target,
    required this.route,
    required this.current,
    required this.orientationMode,
    required this.sensorHeadingDegrees,
    required this.distanceToNextManeuverMeters,
    required this.vectorStyleUrl,
    required this.fallbackVectorStyleUrl,
    required this.vectorAttribution,
    required this.recenterRequest,
    required this.onReady,
    required this.onFallback,
    required this.onFollowStateChanged,
  });

  final MapNavigationTarget target;
  final MapCyclingRoute route;
  final MapRoutePoint? current;
  final MapOrientationMode orientationMode;
  final double? sensorHeadingDegrees;
  final double? distanceToNextManeuverMeters;
  final String vectorStyleUrl;
  final String? fallbackVectorStyleUrl;
  final String vectorAttribution;
  final int recenterRequest;
  final VoidCallback onReady;
  final ValueChanged<String> onFallback;
  final ValueChanged<bool> onFollowStateChanged;

  @override
  State<MapNavigation3DView> createState() => _MapNavigation3DViewState();
}

class _MapNavigation3DViewState extends State<MapNavigation3DView> {
  static const _routeSourceId = 'vigia-route';
  static const _currentSourceId = 'vigia-current';
  static const _targetSourceId = 'vigia-target';
  static const _buildingsLayerId = 'vigia-3d-buildings';
  static const _defaultVectorSourceId = 'openmaptiles';
  static const _defaultBuildingSourceLayerId = 'building';
  static const _mapCreateTimeout = Duration(seconds: 12);
  static const _styleLoadTimeout = Duration(seconds: 20);
  static const _routeDrawTimeout = Duration(seconds: 8);
  static const _cameraSyncTimeout = Duration(seconds: 8);
  static const _firstRenderTimeout = Duration(seconds: 12);
  static const _stylePreflightTimeout = Duration(seconds: 7);
  static const _navigationPadding = EdgeInsets.fromLTRB(20, 220, 20, 92);

  final ErrorLogService _logs = ErrorLogService.instance;
  final PerformanceTelemetryService _telemetry =
      PerformanceTelemetryService.instance;

  ml.MapController? _controller;
  Timer? _startupTimer;
  late String _activeVectorStyleUrl;
  DateTime _startupStartedAt = DateTime.now();
  DateTime _phaseStartedAt = DateTime.now();
  String _startupPhase = 'map_create';
  bool _mapCreated = false;
  bool _styleLoaded = false;
  bool _routeReady = false;
  bool _positionReady = false;
  bool _cameraReady = false;
  bool _cameraIdleSeen = false;
  bool _mapIdle = false;
  bool _firstRenderSeen = false;
  bool _readySignaled = false;
  bool _failed = false;
  bool _following = true;
  bool _buildings3dInstalled = false;
  bool _usedStyleFallback = false;
  int? _styleHttpStatus;
  String? _styleNetworkError;
  bool _stylePreflightCompleted = false;
  bool _styleJsonParsed = false;
  int? _vectorSourceCount;
  String? _buildingSourceId;
  String? _buildingSourceLayerId;
  String? _buildingLayerError;
  DateTime? _lastCameraPointAt;
  double? _lastAppliedBearing;

  @override
  void initState() {
    super.initState();
    _activeVectorStyleUrl = widget.vectorStyleUrl;
    _startupStartedAt = DateTime.now();
    _setStartupPhase('map_create', _mapCreateTimeout);
    _startStylePreflight();
  }

  @override
  void didUpdateWidget(covariant MapNavigation3DView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_failed) return;

    if (oldWidget.recenterRequest != widget.recenterRequest) {
      _setFollowing(true, telemetryEvent: 'follow_resumed');
      unawaited(_syncCamera(animated: true, force: true));
      return;
    }

    if (!_styleLoaded || !_routeReady) return;
    if (oldWidget.route != widget.route || oldWidget.target != widget.target) {
      unawaited(_syncGeometry());
    } else if (oldWidget.current != widget.current) {
      unawaited(_syncCurrentPoint());
    }

    if (_following &&
        (oldWidget.route != widget.route ||
            oldWidget.current != widget.current ||
            oldWidget.orientationMode != widget.orientationMode ||
            oldWidget.sensorHeadingDegrees != widget.sensorHeadingDegrees ||
            oldWidget.distanceToNextManeuverMeters !=
                widget.distanceToNextManeuverMeters)) {
      unawaited(
        _syncCamera(
          animated: true,
          force: oldWidget.orientationMode != widget.orientationMode ||
              oldWidget.sensorHeadingDegrees != widget.sensorHeadingDegrees,
        ),
      );
    }
  }

  @override
  void dispose() {
    _startupTimer?.cancel();
    _startupTimer = null;
    super.dispose();
  }

  String _routeGeoJson() => jsonEncode(<String, Object>{
        'type': 'FeatureCollection',
        'features': <Object>[
          <String, Object>{
            'type': 'Feature',
            'properties': const <String, Object>{},
            'geometry': <String, Object>{
              'type': 'LineString',
              'coordinates': widget.route.points
                  .map((point) => <double>[point.longitude, point.latitude])
                  .toList(growable: false),
            },
          },
        ],
      });

  String _pointGeoJson(double latitude, double longitude) =>
      jsonEncode(<String, Object>{
        'type': 'FeatureCollection',
        'features': <Object>[
          <String, Object>{
            'type': 'Feature',
            'properties': const <String, Object>{},
            'geometry': <String, Object>{
              'type': 'Point',
              'coordinates': <double>[longitude, latitude],
            },
          },
        ],
      });

  String _currentGeoJson() {
    final point = widget.current;
    if (point == null) {
      return _pointGeoJson(widget.target.latitude, widget.target.longitude);
    }
    return _pointGeoJson(point.latitude, point.longitude);
  }

  Future<void> _handleMapCreated(ml.MapController controller) async {
    if (_failed) return;
    try {
      _controller = controller;
      _mapCreated = true;
      _recordTelemetry('map_created');
      _setStartupPhase('style_load', _styleLoadTimeout);
    } catch (error, stackTrace) {
      await _fail(
        phase: 'map_create',
        message: 'Falha ao criar o mapa MapLibre 3D.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _configureStyle(ml.StyleController style) async {
    if (_failed) return;
    _styleLoaded = true;
    _recordTelemetry(
      'style_loaded',
      extra: <String, Object?>{
        'styleMode': 'vector',
        'phaseDurationMs': _phaseElapsedMs,
      },
    );

    _setStartupPhase('route_draw', _routeDrawTimeout);
    try {
      await _installRouteGeometry(style);
      _routeReady = true;
      _positionReady = true;
      _recordTelemetry(
        'route_and_position_ready',
        extra: <String, Object?>{'phaseDurationMs': _phaseElapsedMs},
      );
      // Predios sao opcionais e nunca bloqueiam rota/camera/primeiro frame.
      unawaited(_install3dBuildingsBestEffort(style));
    } catch (error, stackTrace) {
      await _fail(
        phase: 'route_draw',
        message: 'Falha ao desenhar a rota/posição no MapLibre 3D.',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }

    _cameraIdleSeen = false;
    _mapIdle = false;
    _firstRenderSeen = false;
    _setStartupPhase('camera_sync', _cameraSyncTimeout);
    final cameraOk = await _syncCamera(
      animated: false,
      startup: true,
      force: true,
    );
    if (!cameraOk || _failed) return;
    _cameraReady = true;
    _recordTelemetry(
      'initial_camera_ready',
      extra: <String, Object?>{'phaseDurationMs': _phaseElapsedMs},
    );
    _setStartupPhase('first_render', _firstRenderTimeout);
    _markReadyIfPossible();
  }

  Future<void> _install3dBuildingsBestEffort(ml.StyleController style) async {
    try {
      if (_buildings3dInstalled) return;
      final sourceId = _buildingSourceId ?? _defaultVectorSourceId;
      final sourceLayerId =
          _buildingSourceLayerId ?? _defaultBuildingSourceLayerId;
      await style.addLayer(
        ml.FillExtrusionStyleLayer(
          id: _buildingsLayerId,
          sourceId: sourceId,
          sourceLayerId: sourceLayerId,
          minZoom: 14.5,
          paint: <String, Object>{
            'fill-extrusion-color': '#C7CDD3',
            'fill-extrusion-opacity': 0.72,
            'fill-extrusion-height': <Object>[
              'coalesce',
              <Object>['get', 'render_height'],
              <Object>['get', 'height'],
              6.0,
            ],
            'fill-extrusion-base': <Object>[
              'coalesce',
              <Object>['get', 'render_min_height'],
              <Object>['get', 'min_height'],
              0.0,
            ],
          },
        ),
      );
      _buildings3dInstalled = true;
      _buildingLayerError = null;
      _recordTelemetry(
        'buildings_3d_ready',
        extra: <String, Object?>{
          'buildingSourceId': sourceId,
          'buildingSourceLayerId': sourceLayerId,
        },
      );
    } catch (error, stackTrace) {
      _buildings3dInstalled = false;
      _buildingLayerError = _sanitizeDiagnosticText(error.toString());
      _recordTelemetry(
        'buildings_3d_unavailable',
        extra: <String, Object?>{
          'errorType': error.runtimeType.toString(),
          'originalError': _buildingLayerError,
        },
      );
      await _logs.recordException(
        source: 'Mapa 3D / MapLibre',
        error: StateError(_sanitizeDiagnosticText(error.toString())),
        stackTrace: stackTrace,
        level: ErrorLogLevel.warning,
        message:
            'Prédios 3D indisponíveis neste estilo/região; navegação vetorial mantida.',
        context: _diagnosticContext(),
      );
    }
  }

  Future<void> _installRouteGeometry(ml.StyleController style) async {
    await style.addSource(
      ml.GeoJsonSource(id: _routeSourceId, data: _routeGeoJson()),
    );
    await style.addLayer(
      const ml.LineStyleLayer(
        id: 'vigia-route-casing',
        sourceId: _routeSourceId,
        layout: <String, Object>{
          'line-cap': 'round',
          'line-join': 'round',
        },
        paint: <String, Object>{
          'line-color': '#10212B',
          'line-width': 11.0,
          'line-opacity': 0.90,
        },
      ),
    );
    await style.addLayer(
      const ml.LineStyleLayer(
        id: 'vigia-route-line',
        sourceId: _routeSourceId,
        layout: <String, Object>{
          'line-cap': 'round',
          'line-join': 'round',
        },
        paint: <String, Object>{
          'line-color': '#00AEEF',
          'line-width': 7.0,
          'line-opacity': 0.99,
        },
      ),
    );

    await style.addSource(
      ml.GeoJsonSource(
        id: _targetSourceId,
        data: _pointGeoJson(
          widget.target.latitude,
          widget.target.longitude,
        ),
      ),
    );
    await style.addLayer(
      const ml.CircleStyleLayer(
        id: 'vigia-target-point',
        sourceId: _targetSourceId,
        paint: <String, Object>{
          'circle-radius': 8.0,
          'circle-color': '#FF4D67',
          'circle-stroke-color': '#FFFFFF',
          'circle-stroke-width': 3.0,
        },
      ),
    );

    await style.addSource(
      ml.GeoJsonSource(id: _currentSourceId, data: _currentGeoJson()),
    );
    await style.addLayer(
      const ml.CircleStyleLayer(
        id: 'vigia-current-halo',
        sourceId: _currentSourceId,
        paint: <String, Object>{
          'circle-radius': 14.0,
          'circle-color': '#00AEEF',
          'circle-opacity': 0.20,
        },
      ),
    );
    await style.addLayer(
      const ml.CircleStyleLayer(
        id: 'vigia-current-point',
        sourceId: _currentSourceId,
        paint: <String, Object>{
          'circle-radius': 8.5,
          'circle-color': '#00AEEF',
          'circle-stroke-color': '#FFFFFF',
          'circle-stroke-width': 3.0,
        },
      ),
    );
  }

  Future<void> _syncGeometry() async {
    if (_failed || !_styleLoaded || !_routeReady) return;
    final style = _controller?.style;
    if (style == null) {
      await _fail(
        phase: 'style_load',
        message:
            'O estilo do MapLibre 3D ficou indisponível durante a navegação.',
      );
      return;
    }
    try {
      await Future.wait<void>([
        style.updateGeoJsonSource(id: _routeSourceId, data: _routeGeoJson()),
        style.updateGeoJsonSource(
          id: _targetSourceId,
          data: _pointGeoJson(widget.target.latitude, widget.target.longitude),
        ),
        style.updateGeoJsonSource(
          id: _currentSourceId,
          data: _currentGeoJson(),
        ),
      ]);
    } catch (error, stackTrace) {
      await _fail(
        phase: 'route_draw',
        message: 'Falha ao atualizar a rota no MapLibre 3D.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _syncCurrentPoint() async {
    if (_failed || !_styleLoaded || !_routeReady) return;
    final style = _controller?.style;
    if (style == null) {
      await _fail(
        phase: 'style_load',
        message:
            'O estilo do MapLibre 3D ficou indisponível ao atualizar a posição.',
      );
      return;
    }
    try {
      await style.updateGeoJsonSource(
        id: _currentSourceId,
        data: _currentGeoJson(),
      );
    } catch (error, stackTrace) {
      await _fail(
        phase: 'route_draw',
        message: 'Falha ao atualizar a posição no MapLibre 3D.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  double _navigationZoom(MapRoutePoint? point) {
    final speed = point?.speedKilometersPerHour ?? 0;
    var zoom = speed >= 80
        ? 15.7
        : speed >= 45
            ? 16.1
            : speed >= 20
                ? 16.5
                : speed >= 7
                    ? 16.9
                    : 17.2;

    final maneuverMeters = widget.distanceToNextManeuverMeters;
    if (maneuverMeters != null && maneuverMeters.isFinite) {
      if (maneuverMeters <= 55) {
        zoom = math.max(zoom, 17.8).toDouble();
      } else if (maneuverMeters <= 150) {
        zoom = math.max(zoom, 17.5).toDouble();
      } else if (maneuverMeters <= 350) {
        zoom = math.max(zoom, 17.1).toDouble();
      }
    }
    return zoom;
  }

  double _navigationPitch(MapRoutePoint? point) {
    final speed = point?.speedKilometersPerHour ?? 0;
    var pitch = speed < 2
        ? 28.0
        : speed < 7
            ? 38.0
            : speed < 20
                ? 49.0
                : speed < 45
                    ? 55.0
                    : 58.0;
    final maneuverMeters = widget.distanceToNextManeuverMeters;
    if (maneuverMeters != null && maneuverMeters.isFinite) {
      if (maneuverMeters <= 55) {
        pitch = math.min(pitch, 42.0).toDouble();
      } else if (maneuverMeters <= 150) {
        pitch = math.min(pitch, 50.0).toDouble();
      }
    }
    return pitch;
  }

  MapHeadingDecision _cameraHeadingDecision(MapRoutePoint? point) {
    final routeHeading = MapViewPolicy.routeBearingNear(
      current: point,
      routePoints: widget.route.points,
    );
    return MapViewPolicy.orientationHeading(
      mode: widget.orientationMode,
      speedKmh: point?.speedKilometersPerHour ?? 0,
      sensorHeadingDegrees: widget.sensorHeadingDegrees,
      gpsHeadingDegrees: point?.headingDegrees,
      routeHeadingDegrees: routeHeading,
    );
  }

  double _cameraBearing(MapRoutePoint? point, {bool force = false}) {
    if (widget.orientationMode == MapOrientationMode.northUp) {
      _lastAppliedBearing = 0;
      return 0;
    }
    final decision = _cameraHeadingDecision(point);
    final desired = decision.headingDegrees;
    if (desired == null) return _lastAppliedBearing ?? 0;
    final previous = _lastAppliedBearing;
    if (!force &&
        previous != null &&
        MapViewPolicy.shortestAngularDelta(previous, desired).abs() <
            MapViewPolicy.headingRotationDeadZoneDegrees) {
      return previous;
    }
    final next = force
        ? MapViewPolicy.normalizeDegrees(desired)
        : MapViewPolicy.smoothHeading(previous, desired, alpha: 0.30);
    _lastAppliedBearing = next;
    return next;
  }

  Future<bool> _syncCamera({
    required bool animated,
    bool startup = false,
    bool force = false,
  }) async {
    final controller = _controller;
    if (_failed) return false;
    if (controller == null) {
      await _fail(
        phase: startup ? 'map_create' : 'camera_sync',
        message: startup
            ? 'Falha ao criar o mapa MapLibre 3D: controlador indisponível.'
            : 'Falha ao sincronizar a câmera: controlador MapLibre indisponível.',
      );
      return false;
    }
    if (!startup && !_following && !force) return true;

    final point = widget.current;
    final latitude = point?.latitude ?? widget.target.latitude;
    final longitude = point?.longitude ?? widget.target.longitude;
    final heading = _cameraBearing(point, force: force || startup);
    final recordedAt = point?.recordedAt;
    if (!force &&
        animated &&
        recordedAt != null &&
        recordedAt == _lastCameraPointAt) {
      return true;
    }
    _lastCameraPointAt = recordedAt;
    final center = ml.Geographic(lon: longitude, lat: latitude);
    final zoom = _navigationZoom(point);
    final pitch = _navigationPitch(point);
    try {
      if (animated) {
        await controller.animateCamera(
          center: center,
          zoom: zoom,
          bearing: heading,
          pitch: pitch,
          padding: _navigationPadding,
          nativeDuration: const Duration(milliseconds: 520),
        );
      } else {
        await controller.moveCamera(
          center: center,
          zoom: zoom,
          bearing: heading,
          pitch: pitch,
          padding: _navigationPadding,
        );
      }
      return true;
    } catch (error, stackTrace) {
      await _fail(
        phase: 'camera_sync',
        message: 'Falha ao sincronizar a câmera do MapLibre 3D.',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  void _handleMapEvent(ml.MapEvent event) {
    if (_failed) return;
    if (event is ml.MapEventStartMoveCamera &&
        event.reason == ml.CameraChangeReason.apiGesture &&
        _readySignaled) {
      _setFollowing(false, telemetryEvent: 'follow_paused_by_gesture');
    }
    if (event is ml.MapEventCameraIdle) {
      _cameraIdleSeen = true;
      if (_cameraReady) {
        _firstRenderSeen = true;
        _recordTelemetry('first_render_camera_idle');
      }
      _markReadyIfPossible();
    }
    if (event is ml.MapEventIdle) {
      _mapIdle = true;
      if (_cameraReady) {
        _firstRenderSeen = true;
        _recordTelemetry('map_idle');
      }
      _markReadyIfPossible();
    }
  }

  void _setFollowing(bool value, {required String telemetryEvent}) {
    if (_following == value) return;
    _following = value;
    _recordTelemetry(telemetryEvent);
    widget.onFollowStateChanged(value);
  }

  void _markReadyIfPossible() {
    if (_failed || _readySignaled) return;
    if (_cameraReady && (_cameraIdleSeen || _mapIdle)) {
      _firstRenderSeen = true;
    }
    if (!_mapCreated ||
        !_styleLoaded ||
        !_routeReady ||
        !_positionReady ||
        !_cameraReady ||
        !_firstRenderSeen) {
      return;
    }
    _readySignaled = true;
    _startupTimer?.cancel();
    _startupTimer = null;
    _recordTelemetry(
      'ready',
      extra: <String, Object?>{
        'startupDurationMs': _startupElapsedMs,
        'renderSignal': _mapIdle ? 'map_idle' : 'camera_idle',
      },
    );
    widget.onReady();
  }

  int get _startupElapsedMs =>
      DateTime.now().difference(_startupStartedAt).inMilliseconds;

  int get _phaseElapsedMs =>
      DateTime.now().difference(_phaseStartedAt).inMilliseconds;

  void _setStartupPhase(String phase, Duration timeout) {
    if (_failed || _readySignaled) return;
    _startupTimer?.cancel();
    _startupPhase = phase;
    _phaseStartedAt = DateTime.now();
    _recordTelemetry(
      'phase_started',
      extra: <String, Object?>{
        'phase': phase,
        'timeoutSeconds': timeout.inSeconds,
      },
    );
    _startupTimer = Timer(timeout, _handleStartupTimeout);
  }

  void _handleStartupTimeout() {
    if (_failed || _readySignaled) return;
    final blockedAt = _startupPhase;
    if (blockedAt == 'style_load' && _canTryStyleFallback) {
      _recordTelemetry(
        'style_timeout_trying_fallback',
        extra: <String, Object?>{
          'phaseDurationMs': _phaseElapsedMs,
          'styleNetworkError': _styleNetworkError,
          'styleHttpStatus': _styleHttpStatus,
        },
      );
      _attemptStyleFallback();
      return;
    }
    final message = switch (blockedAt) {
      'map_create' =>
        'Falha ao criar a PlatformView do MapLibre 3D: timeout de inicialização.',
      'style_load' =>
        'Falha ao carregar o style vetorial do MapLibre 3D dentro do timeout.',
      'route_draw' =>
        'Falha ao desenhar a rota/posição no MapLibre 3D dentro do timeout.',
      'camera_sync' =>
        'Falha ao sincronizar a câmera inicial do MapLibre 3D dentro do timeout.',
      _ =>
        'Falha no primeiro frame/idle do MapLibre 3D dentro do timeout.',
    };
    _recordTelemetry(
      'timeout',
      extra: <String, Object?>{
        'blockedAt': blockedAt,
        'phaseDurationMs': _phaseElapsedMs,
        'startupDurationMs': _startupElapsedMs,
      },
    );
    unawaited(
      _fail(
        phase: blockedAt,
        message: message,
        context: <String, Object?>{
          'blockedAt': blockedAt,
          'phaseDurationMs': _phaseElapsedMs,
          'startupDurationMs': _startupElapsedMs,
        },
      ),
    );
  }

  bool get _canTryStyleFallback {
    final fallback = widget.fallbackVectorStyleUrl;
    return !_usedStyleFallback &&
        fallback != null &&
        fallback.isNotEmpty &&
        fallback != _activeVectorStyleUrl &&
        _controller != null;
  }

  void _attemptStyleFallback() {
    final fallback = widget.fallbackVectorStyleUrl;
    final controller = _controller;
    if (fallback == null || controller == null || !_canTryStyleFallback) return;
    _usedStyleFallback = true;
    _activeVectorStyleUrl = fallback;
    _styleLoaded = false;
    _routeReady = false;
    _positionReady = false;
    _cameraReady = false;
    _cameraIdleSeen = false;
    _mapIdle = false;
    _firstRenderSeen = false;
    _buildings3dInstalled = false;
    _styleHttpStatus = null;
    _styleNetworkError = null;
    _stylePreflightCompleted = false;
    _styleJsonParsed = false;
    _vectorSourceCount = null;
    _buildingSourceId = null;
    _buildingSourceLayerId = null;
    _buildingLayerError = null;
    _recordTelemetry(
      'style_fallback',
      extra: <String, Object?>{
        'fallbackTo': _styleProviderFor(fallback),
      },
    );
    _setStartupPhase('style_load', _styleLoadTimeout);
    _startStylePreflight();
    controller.setStyle(fallback);
  }

  Future<void> _fail({
    required String phase,
    required String message,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const <String, Object?>{},
  }) async {
    if (_failed) return;
    _failed = true;
    _startupTimer?.cancel();
    _startupTimer = null;
    final diagnosticContext = <String, Object?>{
      ..._diagnosticContext(),
      ...context,
    };

    _recordTelemetry(
      'failure',
      extra: <String, Object?>{
        'phase': phase,
        'message': message,
        'errorType': error?.runtimeType.toString(),
        'originalError': error == null ? null : _sanitizeDiagnosticText(error.toString()),
        'failureDurationMs': _startupElapsedMs,
      },
    );
    _recordTelemetry(
      'fallback_3d_to_2d',
      extra: <String, Object?>{'phase': phase},
    );

    // A recuperação visual não espera I/O de diagnóstico: o FlutterMap já
    // está montado por baixo e deve reassumir a tela imediatamente.
    if (mounted) widget.onFallback(message);

    if (error == null) {
      await _logs.record(
        level: ErrorLogLevel.error,
        source: 'Mapa 3D / MapLibre',
        message: message,
        context: <String, Object?>{
          'phase': phase,
          ...diagnosticContext,
        },
      );
    } else {
      await _logs.recordException(
        source: 'Mapa 3D / MapLibre',
        error: StateError(_sanitizeDiagnosticText(error.toString())),
        stackTrace: stackTrace,
        message: message,
        context: <String, Object?>{
          'phase': phase,
          ...diagnosticContext,
        },
      );
    }

    await _logs.record(
      level: ErrorLogLevel.warning,
      source: 'Mapa 3D / MapLibre',
      message: 'Fallback automático do mapa 3D para o mapa 2D acionado.',
      context: <String, Object?>{
        'phase': phase,
        ...diagnosticContext,
      },
    );
  }

  void _startStylePreflight() {
    unawaited(_preflightStyle(_activeVectorStyleUrl));
  }

  Future<void> _preflightStyle(String styleUrl) async {
    final startedAt = DateTime.now();
    if (styleUrl == _activeVectorStyleUrl) {
      _stylePreflightCompleted = false;
      _styleJsonParsed = false;
      _vectorSourceCount = null;
    }
    final client = HttpClient()..connectionTimeout = _stylePreflightTimeout;
    try {
      final uri = Uri.parse(styleUrl);
      final request = await client.getUrl(uri).timeout(_stylePreflightTimeout);
      request.headers.set(HttpHeaders.userAgentHeader, 'VigiaIA/1.0.165 map-3d-style');
      final response = await request.close().timeout(_stylePreflightTimeout);
      if (styleUrl != _activeVectorStyleUrl) return;
      _styleHttpStatus = response.statusCode;
      final body = await utf8.decoder.bind(response).join().timeout(_stylePreflightTimeout);
      if (styleUrl != _activeVectorStyleUrl) return;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _styleNetworkError = 'HTTP ${response.statusCode}';
        _recordTelemetry(
          'style_preflight_http_error',
          extra: <String, Object?>{
            'httpStatus': response.statusCode,
            'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
          },
        );
        return;
      }

      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        _styleNetworkError = 'Style JSON inválido.';
        _styleJsonParsed = false;
        _recordTelemetry('style_preflight_invalid_json');
        return;
      }
      final style = decoded.cast<String, dynamic>();
      _styleJsonParsed = true;
      final sources = style['sources'];
      final sourceIds = sources is Map
          ? sources.keys.whereType<String>().toList(growable: false)
          : const <String>[];
      _vectorSourceCount = sourceIds.length;
      final layers = style['layers'];
      if (layers is List) {
        for (final rawLayer in layers) {
          if (rawLayer is! Map) continue;
          final layer = rawLayer.cast<dynamic, dynamic>();
          final sourceLayer = layer['source-layer'];
          final source = layer['source'];
          if (sourceLayer is String &&
              source is String &&
              sourceLayer.toLowerCase().contains('building')) {
            _buildingSourceId = source;
            _buildingSourceLayerId = sourceLayer;
            break;
          }
        }
      }
      _styleNetworkError = null;
      _recordTelemetry(
        'style_preflight_ok',
        extra: <String, Object?>{
          'httpStatus': response.statusCode,
          'sourceCount': sourceIds.length,
          'buildingSourceId': _buildingSourceId,
          'buildingSourceLayerId': _buildingSourceLayerId,
        'buildingLayerError': _buildingLayerError,
          'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        },
      );
    } catch (error) {
      if (styleUrl != _activeVectorStyleUrl) return;
      _styleNetworkError = _sanitizeDiagnosticText(error.toString());
      _recordTelemetry(
        'style_preflight_network_error',
        extra: <String, Object?>{
          'originalError': _styleNetworkError,
          'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        },
      );
    } finally {
      if (styleUrl == _activeVectorStyleUrl) {
        _stylePreflightCompleted = true;
      }
      client.close(force: true);
    }
  }

  String _styleProviderFor(String styleUrl) {
    final host = Uri.tryParse(styleUrl)?.host.toLowerCase() ?? '';
    if (host.contains('stadiamaps')) return 'stadia';
    if (host.contains('openfreemap')) return 'openfreemap';
    return 'custom';
  }

  String _sanitizeDiagnosticText(String raw) {
    var sanitized = raw.replaceAllMapped(
      RegExp(r'https?://[^\s)\]}>]+', caseSensitive: false),
      (match) {
        final value = match.group(0)!;
        final uri = Uri.tryParse(value);
        if (uri == null) return '<url-redacted>';
        return uri.replace(query: null, fragment: null).toString();
      },
    );
    sanitized = sanitized.replaceAll(
      RegExp(
        r'(api[_-]?key|apikey|token|secret|key)\s*[:=]\s*[^\s,;]+',
        caseSensitive: false,
      ),
      r'$1=<redacted>',
    );
    return sanitized;
  }

  String _safeVectorStyleDescriptor() {
    final parsed = Uri.tryParse(_activeVectorStyleUrl);
    if (parsed == null) return 'vector-style';
    return parsed.replace(query: null, fragment: null).toString();
  }

  Map<String, Object?> _diagnosticContext() => <String, Object?>{
        'travelMode': widget.target.travelMode.storageValue,
        'routePoints': widget.route.points.length,
        'hasCurrentPosition': widget.current != null,
        'vectorStyle': _safeVectorStyleDescriptor(),
        'styleProvider': _styleProviderFor(_activeVectorStyleUrl),
        'styleHttpStatus': _styleHttpStatus,
        'styleNetworkError': _styleNetworkError,
        'stylePreflightCompleted': _stylePreflightCompleted,
        'styleJsonParsed': _styleJsonParsed,
        'vectorSourceCount': _vectorSourceCount,
        'styleFallbackUsed': _usedStyleFallback,
        'primaryStyleProvider': _styleProviderFor(widget.vectorStyleUrl),
        'androidPlatformViewMode': 'hc',
        'vectorAttribution': widget.vectorAttribution,
        'following': _following,
        'orientationMode': widget.orientationMode.name,
        'headingSource': _cameraHeadingDecision(widget.current).source.name,
        'buildings3dInstalled': _buildings3dInstalled,
        'buildingSourceId': _buildingSourceId,
        'buildingSourceLayerId': _buildingSourceLayerId,
        'buildingLayerError': _buildingLayerError,
        'distanceToNextManeuverMeters': widget.distanceToNextManeuverMeters,
        'mapCreated': _mapCreated,
        'styleLoaded': _styleLoaded,
        'routeReady': _routeReady,
        'positionReady': _positionReady,
        'cameraReady': _cameraReady,
        'cameraIdleSeen': _cameraIdleSeen,
        'mapIdle': _mapIdle,
        'firstRenderSeen': _firstRenderSeen,
        'startupPhase': _startupPhase,
        'phaseDurationMs': _phaseElapsedMs,
        'startupDurationMs': _startupElapsedMs,
      };

  void _recordTelemetry(
    String event, {
    Map<String, Object?> extra = const <String, Object?>{},
  }) {
    _telemetry.recordAlertEvent(<String, Object?>{
      'type': 'map_navigation_3d',
      'event': event,
      'timestamp': DateTime.now().toIso8601String(),
      ..._diagnosticContext(),
      ...extra,
    });
  }

  @override
  Widget build(BuildContext context) {
    final point = widget.current;
    final center = ml.Geographic(
      lon: point?.longitude ?? widget.target.longitude,
      lat: point?.latitude ?? widget.target.latitude,
    );
    return ml.MapLibreMap(
      options: ml.MapOptions(
        initStyle: _activeVectorStyleUrl,
        initCenter: center,
        initZoom: _navigationZoom(point),
        initPitch: _navigationPitch(point),
        initBearing: _cameraBearing(point, force: true),
        minZoom: 3,
        maxZoom: 20,
        minPitch: 0,
        maxPitch: 60,
        gestures: ml.MapGestures.all(),
        // Hybrid Composition evita depender do caminho Texture/ImageReader no
        // renderer 3D e torna a falha de PlatformView distinguivel no diagnostico.
        androidTextureMode: false,
        androidMode: ml.AndroidPlatformViewMode.hc,
        androidTranslucentTextureSurface: false,
        androidForegroundLoadColor: Colors.transparent,
      ),
      onMapCreated: (controller) => unawaited(_handleMapCreated(controller)),
      onStyleLoaded: (style) => unawaited(_configureStyle(style)),
      onEvent: _handleMapEvent,
    );
  }
}
