import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart' as ml;

import '../models/map_cycling_route.dart';
import '../models/map_navigation_target.dart';
import '../models/map_route_point.dart';

/// Renderer dedicado ao modo de navegação em perspectiva.
///
/// O mapa exploratório continua em flutter_map. Quando existe uma rota viária
/// ativa, este renderer usa MapLibre apenas durante a navegação para permitir
/// pitch real, rotação e acompanhamento por direção sem migrar o mapa inteiro.
class MapNavigation3DView extends StatefulWidget {
  const MapNavigation3DView({
    super.key,
    required this.target,
    required this.route,
    required this.current,
    required this.headingUp,
  });

  final MapNavigationTarget target;
  final MapCyclingRoute route;
  final MapRoutePoint? current;
  final bool headingUp;

  @override
  State<MapNavigation3DView> createState() => _MapNavigation3DViewState();
}

class _MapNavigation3DViewState extends State<MapNavigation3DView> {
  static const _routeSourceId = 'vigia-route';
  static const _currentSourceId = 'vigia-current';
  static const _targetSourceId = 'vigia-target';

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
    {"id": "osm", "type": "raster", "source": "osm"}
  ]
}
''';

  ml.MapController? _controller;
  bool _styleReady = false;
  DateTime? _lastCameraPointAt;

  @override
  void didUpdateWidget(covariant MapNavigation3DView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_styleReady) return;
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

  Future<void> _configureStyle(ml.StyleController style) async {
    try {
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
        ml.GeoJsonSource(id: _targetSourceId, data: _pointGeoJson(
          widget.target.latitude,
          widget.target.longitude,
        )),
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
      _styleReady = true;
      await _syncCamera(animated: false);
    } catch (_) {
      _styleReady = false;
    }
  }

  Future<void> _syncGeometry() async {
    final style = _controller?.style;
    if (!_styleReady || style == null) return;
    try {
      await Future.wait<void>([
        style.updateGeoJsonSource(id: _routeSourceId, data: _routeGeoJson()),
        style.updateGeoJsonSource(
          id: _targetSourceId,
          data: _pointGeoJson(widget.target.latitude, widget.target.longitude),
        ),
        style.updateGeoJsonSource(id: _currentSourceId, data: _currentGeoJson()),
      ]);
    } catch (_) {}
  }

  Future<void> _syncCurrentPoint() async {
    final style = _controller?.style;
    if (!_styleReady || style == null) return;
    try {
      await style.updateGeoJsonSource(
        id: _currentSourceId,
        data: _currentGeoJson(),
      );
    } catch (_) {}
  }

  double _navigationZoom(MapRoutePoint? point) {
    final speed = point?.speedKilometersPerHour ?? 0;
    if (speed >= 80) return 15.7;
    if (speed >= 45) return 16.1;
    if (speed >= 20) return 16.5;
    if (speed >= 7) return 16.9;
    return 17.2;
  }

  Future<void> _syncCamera({required bool animated}) async {
    final controller = _controller;
    if (controller == null) return;
    final point = widget.current;
    final latitude = point?.latitude ?? widget.target.latitude;
    final longitude = point?.longitude ?? widget.target.longitude;
    final heading = widget.headingUp ? (point?.headingDegrees ?? 0) : 0.0;
    final recordedAt = point?.recordedAt;
    if (animated &&
        recordedAt != null &&
        recordedAt == _lastCameraPointAt) {
      return;
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
    } catch (_) {}
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
      ),
      onMapCreated: (controller) {
        _controller = controller;
        unawaited(_syncCamera(animated: false));
      },
      onStyleLoaded: (style) => unawaited(_configureStyle(style)),
    );
  }
}
