import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart' as ml;

import '../models/map_cycling_route.dart';
import '../models/map_navigation_target.dart';
import '../models/map_route_point.dart';
import '../models/map_travel_mode.dart';
import '../services/error_log_service.dart';
import '../services/performance_telemetry_service.dart';
import '../services/map_view_policy.dart';
import '../services/map_view_settings_service.dart';
import '../services/map_appearance_policy.dart';
import '../services/map_terrain_capability.dart';

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
    required this.appearancePreset,
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
  final MapAppearancePreset appearancePreset;
  final int recenterRequest;
  final VoidCallback onReady;
  final ValueChanged<String> onFallback;
  final ValueChanged<bool> onFollowStateChanged;

  @override
  State<MapNavigation3DView> createState() => _MapNavigation3DViewState();
}

class _MapNavigation3DViewState extends State<MapNavigation3DView> {
  static const _routeSourceId = 'vigia-route';
  static const _routeCasingLayerId = 'vigia-route-casing';
  static const _routeLineLayerId = 'vigia-route-line';
  static const _currentSourceId = 'vigia-current';
  static const _targetSourceId = 'vigia-target';
  static const _buildingsLayerId = 'vigia-3d-buildings';
  static const _mapCreateTimeout = Duration(seconds: 12);
  static const _styleLoadTimeout = Duration(seconds: 20);
  static const _routeDrawTimeout = Duration(seconds: 8);
  static const _cameraSyncTimeout = Duration(seconds: 8);
  static const _firstRenderTimeout = Duration(seconds: 12);
  static const _stylePreflightTimeout = Duration(seconds: 7);

  final ErrorLogService _logs = ErrorLogService.instance;
  final PerformanceTelemetryService _telemetry =
      PerformanceTelemetryService.instance;

  ml.MapController? _controller;
  Timer? _startupTimer;
  Future<void>? _stylePreflightTask;
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
  double? _lastAppliedBearing;
  double? _lastAppliedLatitude;
  double? _lastAppliedLongitude;
  double? _lastAppliedZoom;
  double? _lastAppliedPitch;
  MapHeadingSource _lastHeadingSource = MapHeadingSource.unavailable;
  int? _lastCameraAnimationDurationMs;
  String? _fallbackReason;
  final Map<String, int> _stageDurationsMs = <String, int>{};

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
            oldWidget.target != widget.target ||
            oldWidget.distanceToNextManeuverMeters !=
                widget.distanceToNextManeuverMeters)) {
      unawaited(
        _syncCamera(
          animated: true,
          force: oldWidget.route != widget.route ||
              oldWidget.target != widget.target ||
              oldWidget.orientationMode != widget.orientationMode ||
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
      try {
        await _stylePreflightTask?.timeout(const Duration(seconds: 3));
      } catch (_) {
        // O preflight e apenas diagnostico/descoberta e nunca bloqueia o mapa.
      }

      final sourceId = _buildingSourceId;
      final sourceLayerId = _buildingSourceLayerId;
      if (sourceId == null ||
          sourceId.isEmpty ||
          sourceLayerId == null ||
          sourceLayerId.isEmpty) {
        _buildings3dInstalled = false;
        _buildingLayerError =
            'Style nao declarou source/source-layer de edificios compativel.';
        _recordTelemetry(
          'buildings_3d_unavailable',
          extra: <String, Object?>{
            'reason': 'style_building_source_not_declared',
          },
        );
        return;
      }

      final palette = MapAppearancePolicy.palette(widget.appearancePreset);
      await style.addLayer(
        ml.FillExtrusionStyleLayer(
          id: _buildingsLayerId,
          sourceId: sourceId,
          sourceLayerId: sourceLayerId,
          minZoom: 14.5,
          paint: <String, Object>{
            'fill-extrusion-color': palette.buildingColorHex,
            'fill-extrusion-opacity': palette.buildingOpacity,
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
        // A rota fica sempre acima das extrusoes para nao ser escondida.
        belowLayerId: _routeCasingLayerId,
      );
      _buildings3dInstalled = true;
      _buildingLayerError = null;
      _recordTelemetry(
        'buildings_3d_ready',
        extra: <String, Object?>{
          'buildingSourceId': sourceId,
          'buildingSourceLayerId': sourceLayerId,
          'buildingOpacity': palette.buildingOpacity,
          'routeAboveBuildings': true,
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
            'Predios 3D indisponiveis neste estilo/regiao; navegacao vetorial mantida.',
        context: _diagnosticContext(),
      );
    }
  }

  Future<void> _installRouteGeometry(ml.StyleController style) async {
    final palette = MapAppearancePolicy.palette(widget.appearancePreset);
    await style.addSource(
      ml.GeoJsonSource(id: _routeSourceId, data: _routeGeoJson()),
    );
    await style.addLayer(
      ml.LineStyleLayer(
        id: _routeCasingLayerId,
        sourceId: _routeSourceId,
        layout: const <String, Object>{
          'line-cap': 'round',
          'line-join': 'round',
        },
        paint: <String, Object>{
          'line-color': palette.routeCasingColorHex,
          'line-width': palette.routeCasingWidth,
          'line-opacity': 0.94,
        },
      ),
    );
    await style.addLayer(
      ml.LineStyleLayer(
        id: _routeLineLayerId,
        sourceId: _routeSourceId,
        layout: const <String, Object>{
          'line-cap': 'round',
          'line-join': 'round',
        },
        paint: <String, Object>{
          'line-color': palette.routeColorHex,
          'line-width': palette.routeWidth,
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
      ml.CircleStyleLayer(
        id: 'vigia-target-point',
        sourceId: _targetSourceId,
        paint: <String, Object>{
          'circle-radius': 9.5,
          'circle-color': palette.destinationColorHex,
          'circle-stroke-color': '#FFFFFF',
          'circle-stroke-width': 3.5,
        },
      ),
    );

    await style.addSource(
      ml.GeoJsonSource(id: _currentSourceId, data: _currentGeoJson()),
    );
    await style.addLayer(
      ml.CircleStyleLayer(
        id: 'vigia-current-halo',
        sourceId: _currentSourceId,
        paint: <String, Object>{
          'circle-radius': 15.5,
          'circle-color': palette.currentPositionColorHex,
          'circle-opacity': 0.20,
        },
      ),
    );
    await style.addLayer(
      ml.CircleStyleLayer(
        id: 'vigia-current-point',
        sourceId: _currentSourceId,
        paint: <String, Object>{
          'circle-radius': 9.5,
          'circle-color': palette.currentPositionColorHex,
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

  double? _distanceToDestinationMeters(MapRoutePoint? point) {
    if (point == null) return null;
    return MapViewPolicy.distanceMeters(
      point.latitude,
      point.longitude,
      widget.target.latitude,
      widget.target.longitude,
    );
  }

  MapNavigationCameraTuning _cameraTuning(MapRoutePoint? point) =>
      MapViewPolicy.navigationCameraTuning(
        travelMode: widget.target.travelMode,
        speedKmh: point?.speedKilometersPerHour ?? 0,
        distanceToManeuverMeters: widget.distanceToNextManeuverMeters,
        distanceToDestinationMeters: _distanceToDestinationMeters(point),
      );

  EdgeInsets _navigationPadding(MapNavigationCameraTuning tuning) {
    final size = MediaQuery.sizeOf(context);
    final top = MapViewPolicy.navigationTopPadding(
      viewportHeight: size.height,
      tuning: tuning,
    );
    final compactLandscape = size.width > size.height;
    final bottom = compactLandscape ? 70.0 : 92.0;
    final horizontal = compactLandscape ? 18.0 : 20.0;
    return EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom);
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

  double _cameraBearing(
    MapRoutePoint? point,
    MapNavigationCameraTuning tuning, {
    bool force = false,
    bool snap = false,
  }) {
    if (widget.orientationMode == MapOrientationMode.northUp) {
      _lastHeadingSource = MapHeadingSource.unavailable;
      _lastAppliedBearing = 0;
      return 0;
    }
    final decision = _cameraHeadingDecision(point);
    _lastHeadingSource = decision.source;
    final desired = decision.headingDegrees;
    if (desired == null) {
      // Sem fonte real nova, preserva o ultimo bearing aplicado sem fabricar rumo.
      return _lastAppliedBearing ?? 0;
    }
    final previous = _lastAppliedBearing;
    if (!force &&
        previous != null &&
        MapViewPolicy.shortestAngularDelta(previous, desired).abs() <
            MapViewPolicy.headingRotationDeadZoneDegrees) {
      return previous;
    }
    final next = previous == null || snap
        ? MapViewPolicy.normalizeDegrees(desired)
        : MapViewPolicy.smoothHeadingLimited(
            previous,
            desired,
            alpha: tuning.bearingAlpha,
            maxStepDegrees: tuning.maxBearingStepDegrees,
          );
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
            ? 'Falha ao criar o mapa MapLibre 3D: controlador indisponivel.'
            : 'Falha ao sincronizar a camera: controlador MapLibre indisponivel.',
      );
      return false;
    }
    if (!startup && !_following && !force) return true;

    final point = widget.current;
    final rawLatitude = point?.latitude ?? widget.target.latitude;
    final rawLongitude = point?.longitude ?? widget.target.longitude;
    final tuning = _cameraTuning(point);
    final previousBearing = _lastAppliedBearing;
    final previousZoom = _lastAppliedZoom;
    final previousPitch = _lastAppliedPitch;
    final heading = _cameraBearing(
      point,
      tuning,
      force: force || startup,
      snap: startup,
    );
    final previousLatitude = _lastAppliedLatitude;
    final previousLongitude = _lastAppliedLongitude;
    if (!force &&
        animated &&
        previousLatitude != null &&
        previousLongitude != null) {
      final movedMeters = MapViewPolicy.distanceMeters(
        previousLatitude,
        previousLongitude,
        rawLatitude,
        rawLongitude,
      );
      final bearingChanged = previousBearing != null &&
          MapViewPolicy.shortestAngularDelta(previousBearing, heading).abs() >=
              MapViewPolicy.headingRotationDeadZoneDegrees;
      final zoomChanged = previousZoom == null ||
          (tuning.zoom - previousZoom).abs() >= 0.05;
      final pitchChanged = previousPitch == null ||
          (tuning.pitch - previousPitch).abs() >= 1.0;
      if (movedMeters < tuning.minimumCenterUpdateMeters &&
          !bearingChanged &&
          !zoomChanged &&
          !pitchChanged) {
        return true;
      }
    }

    final latitude = startup
        ? rawLatitude
        : MapViewPolicy.smoothCoordinate(
            previousLatitude,
            rawLatitude,
            alpha: tuning.centerAlpha,
          );
    final longitude = startup
        ? rawLongitude
        : MapViewPolicy.smoothCoordinate(
            previousLongitude,
            rawLongitude,
            alpha: tuning.centerAlpha,
          );
    _lastAppliedLatitude = latitude;
    _lastAppliedLongitude = longitude;
    _lastAppliedZoom = tuning.zoom;
    _lastAppliedPitch = tuning.pitch;
    _lastCameraAnimationDurationMs = tuning.animationDuration.inMilliseconds;

    final center = ml.Geographic(lon: longitude, lat: latitude);
    final padding = _navigationPadding(tuning);
    try {
      if (animated) {
        await controller.animateCamera(
          center: center,
          zoom: tuning.zoom,
          bearing: heading,
          pitch: tuning.pitch,
          padding: padding,
          nativeDuration: tuning.animationDuration,
        );
      } else {
        await controller.moveCamera(
          center: center,
          zoom: tuning.zoom,
          bearing: heading,
          pitch: tuning.pitch,
          padding: padding,
        );
      }
      _recordTelemetry(
        'camera_synced',
        extra: <String, Object?>{
          'cameraAnimated': animated,
          'cameraPaddingTop': padding.top,
          'distanceToDestinationMeters': _distanceToDestinationMeters(point),
        },
      );
      return true;
    } catch (error, stackTrace) {
      await _fail(
        phase: 'camera_sync',
        message: 'Falha ao sincronizar a camera do MapLibre 3D.',
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
    _recordCurrentStageDuration();
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

  void _recordCurrentStageDuration() {
    final elapsed = _phaseElapsedMs;
    final existing = _stageDurationsMs[_startupPhase] ?? 0;
    _stageDurationsMs[_startupPhase] = existing + elapsed;
  }

  void _setStartupPhase(String phase, Duration timeout) {
    if (_failed || _readySignaled) return;
    _startupTimer?.cancel();
    if (_startupPhase != phase || _stageDurationsMs.isNotEmpty) {
      _recordCurrentStageDuration();
    }
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
    _recordCurrentStageDuration();
    _fallbackReason = _sanitizeDiagnosticText(
      error == null ? message : error.toString(),
    );
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
        'originalError':
            error == null ? null : _sanitizeDiagnosticText(error.toString()),
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
    final task = _preflightStyle(_activeVectorStyleUrl);
    _stylePreflightTask = task;
    unawaited(task);
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
      request.headers.set(HttpHeaders.userAgentHeader, 'VigiaIA/1.0.183 map-3d-style');
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
        'appearancePreset': widget.appearancePreset.name,
        'headingSource': _lastHeadingSource.name,
        'cameraPitch': _lastAppliedPitch,
        'cameraZoom': _lastAppliedZoom,
        'cameraBearing': _lastAppliedBearing,
        'cameraAnimationDurationMs': _lastCameraAnimationDurationMs,
        'stageDurationsMs': Map<String, int>.from(_stageDurationsMs),
        'fallbackReason': _fallbackReason,
        'buildings3dInstalled': _buildings3dInstalled,
        'buildingSourceId': _buildingSourceId,
        'buildingSourceLayerId': _buildingSourceLayerId,
        'buildingLayerError': _buildingLayerError,
        'terrainElevationSupported': MapTerrainCapability.canEnableRealTerrain,
        'terrainElevationState': MapTerrainCapability.state,
        'terrainElevationReason': MapTerrainCapability.reason,
        'mapLibreFlutterVersion': MapTerrainCapability.mapLibreFlutterVersion,
        'distanceToNextManeuverMeters': widget.distanceToNextManeuverMeters,
        'distanceToDestinationMeters': _distanceToDestinationMeters(widget.current),
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
    final tuning = _cameraTuning(point);
    return ml.MapLibreMap(
      options: ml.MapOptions(
        initStyle: _activeVectorStyleUrl,
        initCenter: center,
        initZoom: tuning.zoom,
        initPitch: tuning.pitch,
        initBearing: _cameraBearing(point, tuning, force: true, snap: true),
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
