import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../models/map_route_point.dart';

enum MapOrientationMode { northUp, directionUp, routeUp }

enum MapHeadingSource { sensor, gps, route, unavailable }

extension MapOrientationModeX on MapOrientationMode {
  String get label => switch (this) {
        MapOrientationMode.northUp => 'Norte',
        MapOrientationMode.directionUp => 'Direção',
        MapOrientationMode.routeUp => 'Rota',
      };
}

extension MapHeadingSourceX on MapHeadingSource {
  String get label => switch (this) {
        MapHeadingSource.sensor => 'Sensor',
        MapHeadingSource.gps => 'GPS',
        MapHeadingSource.route => 'Rota',
        MapHeadingSource.unavailable => 'Indisponível',
      };
}

class MapHeadingDecision {
  const MapHeadingDecision({required this.headingDegrees, required this.source});

  const MapHeadingDecision.unavailable()
      : headingDegrees = null,
        source = MapHeadingSource.unavailable;

  final double? headingDegrees;
  final MapHeadingSource source;

  bool get available => headingDegrees != null;
}

enum MapFollowViewPreset { near, region }

/// Regras puras de camera/orientacao do mapa.
///
/// Mantem zoom, selecao de heading, suavizacao e dead-zones testaveis sem
/// depender do widget/MapController. Nenhum heading e fabricado: a decisao
/// sempre aponta a fonte real usada (sensor, GPS ou geometria da rota).
class MapViewPolicy {
  const MapViewPolicy._();

  static const double nearZoom = 14.7;
  static const double regionZoom = 12.2;
  static const double minimumHeadingSpeedKmh = 3.0;
  static const double preferredGpsHeadingSpeedKmh = 4.0;
  static const double headingRotationDeadZoneDegrees = 2.5;
  static const double sensorUpdateDeadZoneDegrees = 1.8;

  static double zoomFor(MapFollowViewPreset preset) => switch (preset) {
        MapFollowViewPreset.near => nearZoom,
        MapFollowViewPreset.region => regionZoom,
      };

  static double normalizeDegrees(double value) {
    final normalized = value % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }

  static bool validHeading(double? value) =>
      value != null && value.isFinite && value >= 0;

  /// flutter_map gira o mapa; para manter o rumo apontando para o topo, a
  /// camera precisa girar no sentido oposto ao heading geografico.
  static double mapRotationForHeading(double headingDegrees) =>
      normalizeDegrees(360 - normalizeDegrees(headingDegrees));

  static double shortestAngularDelta(double from, double to) {
    final delta = normalizeDegrees(to) - normalizeDegrees(from);
    if (delta > 180) return delta - 360;
    if (delta < -180) return delta + 360;
    return delta;
  }

  static double smoothHeading(
    double? previous,
    double current, {
    double alpha = 0.24,
  }) {
    final normalized = normalizeDegrees(current);
    if (previous == null || !previous.isFinite) return normalized;
    final safeAlpha = alpha.clamp(0.0, 1.0).toDouble();
    final delta = shortestAngularDelta(previous, normalized);
    return normalizeDegrees(previous + delta * safeAlpha);
  }

  static bool shouldApplyMapRotation({
    required double headingDegrees,
    required double currentMapRotationDegrees,
    bool force = false,
  }) {
    if (!headingDegrees.isFinite) return false;
    if (force) return true;
    final desired = mapRotationForHeading(headingDegrees);
    return shortestAngularDelta(currentMapRotationDegrees, desired).abs() >=
        headingRotationDeadZoneDegrees;
  }

  /// Compatibilidade com a politica antiga de heading GPS em movimento.
  static bool shouldApplyHeadingRotation({
    required double headingDegrees,
    required double speedKmh,
    required double currentMapRotationDegrees,
    bool force = false,
  }) {
    if (!headingDegrees.isFinite) return false;
    if (!force && speedKmh < minimumHeadingSpeedKmh) return false;
    return shouldApplyMapRotation(
      headingDegrees: headingDegrees,
      currentMapRotationDegrees: currentMapRotationDegrees,
      force: force,
    );
  }

  static MapHeadingDecision orientationHeading({
    required MapOrientationMode mode,
    required double speedKmh,
    double? sensorHeadingDegrees,
    double? gpsHeadingDegrees,
    double? routeHeadingDegrees,
  }) {
    if (mode == MapOrientationMode.northUp) {
      return const MapHeadingDecision.unavailable();
    }
    final moving = speedKmh.isFinite && speedKmh >= preferredGpsHeadingSpeedKmh;
    final sensor = _decision(sensorHeadingDegrees, MapHeadingSource.sensor);
    final gps = _decision(gpsHeadingDegrees, MapHeadingSource.gps);
    final route = _decision(routeHeadingDegrees, MapHeadingSource.route);

    if (!moving) {
      return sensor ??
          (mode == MapOrientationMode.routeUp ? route : gps) ??
          (mode == MapOrientationMode.routeUp ? gps : route) ??
          const MapHeadingDecision.unavailable();
    }
    if (mode == MapOrientationMode.routeUp) {
      return gps ?? route ?? sensor ?? const MapHeadingDecision.unavailable();
    }
    return gps ?? sensor ?? route ?? const MapHeadingDecision.unavailable();
  }

  /// Heading mostrado na Bussola, inclusive quando o mapa esta em Norte.
  static MapHeadingDecision displayHeading({
    required double speedKmh,
    double? sensorHeadingDegrees,
    double? gpsHeadingDegrees,
    double? routeHeadingDegrees,
  }) {
    final moving = speedKmh.isFinite && speedKmh >= preferredGpsHeadingSpeedKmh;
    final sensor = _decision(sensorHeadingDegrees, MapHeadingSource.sensor);
    final gps = _decision(gpsHeadingDegrees, MapHeadingSource.gps);
    final route = _decision(routeHeadingDegrees, MapHeadingSource.route);
    return moving
        ? gps ?? route ?? sensor ?? const MapHeadingDecision.unavailable()
        : sensor ?? gps ?? route ?? const MapHeadingDecision.unavailable();
  }

  static MapHeadingDecision? _decision(double? value, MapHeadingSource source) {
    if (!validHeading(value)) return null;
    return MapHeadingDecision(
      headingDegrees: normalizeDegrees(value!),
      source: source,
    );
  }

  static double? routeBearingNear({
    required MapRoutePoint? current,
    required List<LatLng> routePoints,
  }) {
    if (current == null || routePoints.length < 2) return null;
    var nearestIndex = 0;
    var nearestSquared = double.infinity;
    final latitudeScale = math.cos(current.latitude * math.pi / 180).abs();
    for (var index = 0; index < routePoints.length; index++) {
      final candidate = routePoints[index];
      final dx = (candidate.longitude - current.longitude) * latitudeScale;
      final dy = candidate.latitude - current.latitude;
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
      return bearingBetween(routePoints[nearestIndex - 1], routePoints[nearestIndex]);
    }
    return bearingBetween(routePoints[nearestIndex], routePoints[nextIndex]);
  }

  static double bearingBetween(LatLng start, LatLng end) {
    final lat1 = start.latitude * math.pi / 180;
    final lat2 = end.latitude * math.pi / 180;
    final deltaLon = (end.longitude - start.longitude) * math.pi / 180;
    final y = math.sin(deltaLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(deltaLon);
    return normalizeDegrees(math.atan2(y, x) * 180 / math.pi);
  }

  /// Distancia vertical em pixels usada pelo MapController.move(offset: ...)
  /// para deixar o usuario abaixo do centro e aumentar a estrada visivel a
  /// frente. Em paisagem o deslocamento e menor para preservar area util.
  static double followOffsetPixels({
    required double viewportHeight,
    required bool compactLandscape,
  }) {
    if (!viewportHeight.isFinite || viewportHeight <= 0) return 0;
    final fraction = compactLandscape ? 0.12 : 0.18;
    final raw = viewportHeight * fraction;
    final minimum = compactLandscape ? 34.0 : 58.0;
    final maximum = compactLandscape ? 78.0 : 150.0;
    return raw.clamp(minimum, maximum).toDouble();
  }
}
