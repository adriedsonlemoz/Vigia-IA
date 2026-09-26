import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre/maplibre.dart' as ml;

import '../models/map_cycling_route.dart';
import '../models/map_navigation_target.dart';
import '../models/map_route_point.dart';
import '../models/map_travel_mode.dart';
import '../services/error_log_service.dart';
import '../services/performance_telemetry_service.dart';

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
    required this.headingUp,
    required this.distanceToNextManeuverMeters,
    required this.vectorStyleUrl,
    required this.vectorAttribution,
    required this.recenterRequest,
    required this.onReady,
    required this.onFallback,
    required this.onFollowStateChanged,
  });

  final MapNavigationTarget target;
  final MapCyclingRoute route;
  final MapRoutePoint? current;
  final bool headingUp;
  final double? distanceToNextManeuverMeters;
  final String vectorStyleUrl;
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
  static const _vectorSourceId = 'openmaptiles';
  static const _startupTimeout = Duration(seconds: 9);
  static const _navigationPadding = EdgeInsets.fromLTRB(20, 220, 20, 92);

  final ErrorLogService _logs = ErrorLogService.instance;
  final PerformanceTelemetryService _telemetry =
      PerformanceTelemetryService.instance;

  ml.MapController? _controller;
  Timer? _startupTimer;
  bool _mapCreated = false;
  bool _styleLoaded = false;
  bool _routeReady = false;
  bool _cameraReady = false;
  bool _mapIdle = false;
  bool _readySignaled = false;
  bool _failed = false;
  bool _following = true;
  bool _buildings3dInstalled = false;
  DateTime? _lastCameraPointAt;

  @override
  void initState() {
    super.initState();
    _startupTimer = Timer(_startupTimeout, _handleStartupTimeout);
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
            oldWidget.headingUp != widget.headingUp ||
            oldWidget.distanceToNextManeuverMeters !=
                widget.distanceToNextManeuverMeters)) {
      unawaited(
        _syncCamera(
          animated: true,
          force: oldWidget.headingUp != widget.headingUp,
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
      extra: <String, Object?>{'styleMode': 'vector'},
    );

    await _install3dBuildingsBestEffort(style);

    try {
      await _installRouteGeometry(style);
      _routeReady = true;
    } catch (error, stackTrace) {
      await _fail(
        phase: 'route_draw',
        message: 'Falha ao desenhar a rota no MapLibre 3D.',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }

    final cameraOk = await _syncCamera(
      animated: false,
      startup: true,
      force: true,
    );
    if (!cameraOk || _failed) return;
    _cameraReady = true;
    _markReadyIfPossible();
  }

  Future<void> _install3dBuildingsBestEffort(ml.StyleController style) async {
    try {
      if (style.getLayerIds().contains(_buildingsLayerId)) {
        _buildings3dInstalled = true;
        return;
      }
      await style.addLayer(
        const ml.FillExtrusionStyleLayer(
          id: _buildingsLayerId,
          sourceId: _vectorSourceId,
          sourceLayerId: 'building',
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
      _recordTelemetry('buildings_3d_ready');
    } catch (error, stackTrace) {
      _buildings3dInstalled = false;
      _recordTelemetry(
        'buildings_3d_unavailable',
        extra: <String, Object?>{'errorType': error.runtimeType.toString()},
      );
      await _logs.recordException(
        source: 'Mapa 3D / MapLibre',
        error: error,
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

  double _cameraBearing(MapRoutePoint? point) {
    if (!widget.headingUp) return 0;
    final sensorHeading = point?.headingDegrees;
    if (sensorHeading != null && sensorHeading.isFinite) {
      return _normalizeDegrees(sensorHeading);
    }
    return _routeBearingNear(point) ?? 0;
  }

  double? _routeBearingNear(MapRoutePoint? point) {
    if (point == null || widget.route.points.length < 2) return null;
    final routePoints = widget.route.points;
    var nearestIndex = 0;
    var nearestSquared = double.infinity;
    final latitudeScale = math.cos(point.latitude * math.pi / 180).abs();
    for (var index = 0; index < routePoints.length; index++) {
      final candidate = routePoints[index];
      final dx = (candidate.longitude - point.longitude) * latitudeScale;
      final dy = candidate.latitude - point.latitude;
      final squared = dx * dx + dy * dy;
      if (squared < nearestSquared) {
        nearestSquared = squared;
        nearestIndex = index;
      }
    }
    final nextIndex = nearestIndex + 2 < routePoints.length
        ? nearestIndex + 2
        : routePoints.length - 1;
    if (nextIndex == nearestIndex && nearestIndex > 0) {
      return _bearingBetween(
        routePoints[nearestIndex - 1],
        routePoints[nearestIndex],
      );
    }
    return _bearingBetween(routePoints[nearestIndex], routePoints[nextIndex]);
  }

  double _bearingBetween(LatLng start, LatLng end) {
    final lat1 = start.latitude * math.pi / 180;
    final lat2 = end.latitude * math.pi / 180;
    final deltaLon = (end.longitude - start.longitude) * math.pi / 180;
    final y = math.sin(deltaLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(deltaLon);
    return _normalizeDegrees(math.atan2(y, x) * 180 / math.pi);
  }

  double _normalizeDegrees(double value) => ((value % 360) + 360) % 360;

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
    final heading = _cameraBearing(point);
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
    if (event is ml.MapEventIdle && _styleLoaded && _routeReady) {
      _mapIdle = true;
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
    if (!_mapCreated ||
        !_styleLoaded ||
        !_routeReady ||
        !_cameraReady ||
        !_mapIdle) {
      return;
    }
    _readySignaled = true;
    _startupTimer?.cancel();
    _startupTimer = null;
    _recordTelemetry('ready');
    widget.onReady();
  }

  void _handleStartupTimeout() {
    if (_failed || _readySignaled) return;
    final blockedAt = !_mapCreated
        ? 'map_create'
        : !_styleLoaded
            ? 'style_load'
            : !_routeReady
                ? 'route_draw'
                : !_cameraReady
                    ? 'camera_sync'
                    : 'first_render';
    final message = switch (blockedAt) {
      'map_create' =>
        'Falha ao criar o mapa MapLibre 3D: timeout de inicialização.',
      'style_load' =>
        'Falha de estilo vetorial no MapLibre 3D: carregamento excedeu o timeout.',
      'route_draw' =>
        'Falha ao desenhar a rota no MapLibre 3D: operação excedeu o timeout.',
      'camera_sync' =>
        'Falha ao sincronizar a câmera do MapLibre 3D: operação excedeu o timeout.',
      _ =>
        'Falha no primeiro render do MapLibre 3D: operação excedeu o timeout.',
    };
    _recordTelemetry(
      'timeout',
      extra: <String, Object?>{'blockedAt': blockedAt},
    );
    unawaited(
      _fail(
        phase: blockedAt,
        message: message,
        context: <String, Object?>{
          'blockedAt': blockedAt,
          'timeoutSeconds': _startupTimeout.inSeconds,
        },
      ),
    );
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
        error: error,
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

  String _safeVectorStyleDescriptor() {
    final parsed = Uri.tryParse(widget.vectorStyleUrl);
    if (parsed == null) return 'vector-style';
    return parsed.replace(query: null, fragment: null).toString();
  }

  Map<String, Object?> _diagnosticContext() => <String, Object?>{
        'travelMode': widget.target.travelMode.storageValue,
        'routePoints': widget.route.points.length,
        'hasCurrentPosition': widget.current != null,
        'vectorStyle': _safeVectorStyleDescriptor(),
        'vectorAttribution': widget.vectorAttribution,
        'following': _following,
        'buildings3dInstalled': _buildings3dInstalled,
        'distanceToNextManeuverMeters': widget.distanceToNextManeuverMeters,
        'mapCreated': _mapCreated,
        'styleLoaded': _styleLoaded,
        'routeReady': _routeReady,
        'cameraReady': _cameraReady,
        'mapIdle': _mapIdle,
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
        initStyle: widget.vectorStyleUrl,
        initCenter: center,
        initZoom: _navigationZoom(point),
        initPitch: _navigationPitch(point),
        initBearing: _cameraBearing(point),
        minZoom: 3,
        maxZoom: 20,
        minPitch: 0,
        maxPitch: 60,
        gestures: ml.MapGestures.all(),
        // A 0.3.6 usa Texture Layer Hybrid Composition por padrão no Android.
        // Mantemos o caminho de textura explicitamente para permitir a transição
        // sobre o FlutterMap sem trocar para Virtual Display durante o startup.
        androidTextureMode: true,
        androidMode: ml.AndroidPlatformViewMode.tlhc_hc,
        androidTranslucentTextureSurface: false,
        androidForegroundLoadColor: Colors.transparent,
      ),
      onMapCreated: (controller) => unawaited(_handleMapCreated(controller)),
      onStyleLoaded: (style) => unawaited(_configureStyle(style)),
      onEvent: _handleMapEvent,
    );
  }
}
