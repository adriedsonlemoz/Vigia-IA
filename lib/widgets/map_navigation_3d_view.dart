import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart' as ml;

import '../models/map_cycling_route.dart';
import '../models/map_navigation_target.dart';
import '../models/map_route_point.dart';
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
    required this.onReady,
    required this.onFallback,
  });

  final MapNavigationTarget target;
  final MapCyclingRoute route;
  final MapRoutePoint? current;
  final bool headingUp;
  final VoidCallback onReady;
  final ValueChanged<String> onFallback;

  @override
  State<MapNavigation3DView> createState() => _MapNavigation3DViewState();
}

class _MapNavigation3DViewState extends State<MapNavigation3DView> {
  static const _routeSourceId = 'vigia-route';
  static const _currentSourceId = 'vigia-current';
  static const _targetSourceId = 'vigia-target';
  static const _startupTimeout = Duration(seconds: 9);

  // O background claro impede que a superfície nativa apresente um quadro
  // preto caso os tiles raster ainda estejam chegando após o estilo carregar.
  static const _style = '''
{
  "version": 8,
  "sources": {
    "osm": {
      "type": "raster",
      "tiles": ["https://tile.openstreetmap.org/{z}/{x}/{y}.png"],
      "tileSize": 256,
      "attribution": "© OpenStreetMap contributors"
    }
  },
  "layers": [
    {
      "id": "vigia-background",
      "type": "background",
      "paint": {"background-color": "#E8ECEF"}
    },
    {"id": "osm", "type": "raster", "source": "osm"}
  ]
}
''';

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
  DateTime? _lastCameraPointAt;

  @override
  void initState() {
    super.initState();
    _startupTimer = Timer(_startupTimeout, _handleStartupTimeout);
  }

  @override
  void didUpdateWidget(covariant MapNavigation3DView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_failed || !_styleLoaded || !_routeReady) return;
    if (oldWidget.route != widget.route || oldWidget.target != widget.target) {
      unawaited(_syncGeometry());
    } else if (oldWidget.current != widget.current) {
      unawaited(_syncCurrentPoint());
    }
    if (oldWidget.current != widget.current ||
        oldWidget.headingUp != widget.headingUp) {
      unawaited(_syncCamera(animated: true));
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
    _recordTelemetry('style_loaded');

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

    final cameraOk = await _syncCamera(animated: false, startup: true);
    if (!cameraOk || _failed) return;
    _cameraReady = true;
    _markReadyIfPossible();
  }

  Future<void> _installRouteGeometry(ml.StyleController style) async {
    await style.addSource(
      ml.GeoJsonSource(id: _routeSourceId, data: _routeGeoJson()),
    );
    await style.addLayer(
      const ml.LineStyleLayer(
        id: 'vigia-route-casing',
        sourceId: _routeSourceId,
        paint: <String, Object>{
          'line-color': '#10212B',
          'line-width': 10.0,
          'line-opacity': 0.88,
        },
      ),
    );
    await style.addLayer(
      const ml.LineStyleLayer(
        id: 'vigia-route-line',
        sourceId: _routeSourceId,
        paint: <String, Object>{
          'line-color': '#00AEEF',
          'line-width': 6.0,
          'line-opacity': 0.98,
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
        id: 'vigia-current-point',
        sourceId: _currentSourceId,
        paint: <String, Object>{
          'circle-radius': 9.0,
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
        message: 'O estilo do MapLibre 3D ficou indisponível durante a navegação.',
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
        message: 'O estilo do MapLibre 3D ficou indisponível ao atualizar a posição.',
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
    if (speed >= 80) return 15.7;
    if (speed >= 45) return 16.1;
    if (speed >= 20) return 16.5;
    if (speed >= 7) return 16.9;
    return 17.2;
  }

  Future<bool> _syncCamera({
    required bool animated,
    bool startup = false,
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
    final point = widget.current;
    final latitude = point?.latitude ?? widget.target.latitude;
    final longitude = point?.longitude ?? widget.target.longitude;
    final heading = widget.headingUp ? (point?.headingDegrees ?? 0) : 0.0;
    final recordedAt = point?.recordedAt;
    if (animated && recordedAt != null && recordedAt == _lastCameraPointAt) {
      return true;
    }
    _lastCameraPointAt = recordedAt;
    final center = ml.Geographic(lon: longitude, lat: latitude);
    try {
      if (animated) {
        await controller.animateCamera(
          center: center,
          zoom: _navigationZoom(point),
          bearing: heading,
          pitch: 54,
          padding: const EdgeInsets.fromLTRB(18, 120, 18, 210),
          nativeDuration: const Duration(milliseconds: 520),
        );
      } else {
        await controller.moveCamera(
          center: center,
          zoom: _navigationZoom(point),
          bearing: heading,
          pitch: 54,
          padding: const EdgeInsets.fromLTRB(18, 120, 18, 210),
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
    if (event is ml.MapEventIdle && _styleLoaded && _routeReady) {
      _mapIdle = true;
      _markReadyIfPossible();
    }
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
      'map_create' => 'Falha ao criar o mapa MapLibre 3D: timeout de inicialização.',
      'style_load' => 'Falha de estilo no MapLibre 3D: carregamento excedeu o timeout.',
      'route_draw' => 'Falha ao desenhar a rota no MapLibre 3D: operação excedeu o timeout.',
      'camera_sync' => 'Falha ao sincronizar a câmera do MapLibre 3D: operação excedeu o timeout.',
      _ => 'Falha no primeiro render do MapLibre 3D: operação excedeu o timeout.',
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

  Map<String, Object?> _diagnosticContext() => <String, Object?>{
        'travelMode': widget.target.travelMode.storageValue,
        'routePoints': widget.route.points.length,
        'hasCurrentPosition': widget.current != null,
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
        initStyle: _style,
        initCenter: center,
        initZoom: _navigationZoom(point),
        initPitch: 54,
        initBearing: widget.headingUp ? (point?.headingDegrees ?? 0) : 0,
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
