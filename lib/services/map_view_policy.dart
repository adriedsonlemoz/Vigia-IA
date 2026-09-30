import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../models/map_route_point.dart';
import '../models/map_travel_mode.dart';

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


class MapNavigationCameraTuning {
  const MapNavigationCameraTuning({
    required this.zoom,
    required this.pitch,
    required this.centerAlpha,
    required this.bearingAlpha,
    required this.maxBearingStepDegrees,
    required this.animationDuration,
    required this.minimumCenterUpdateMeters,
    required this.topPaddingFraction,
    required this.topPaddingMin,
    required this.topPaddingMax,
  });

  final double zoom;
  final double pitch;
  final double centerAlpha;
  final double bearingAlpha;
  final double maxBearingStepDegrees;
  final Duration animationDuration;
  final double minimumCenterUpdateMeters;
  final double topPaddingFraction;
  final double topPaddingMin;
  final double topPaddingMax;
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

  static double smoothHeadingLimited(
    double? previous,
    double current, {
    required double alpha,
    required double maxStepDegrees,
  }) {
    final normalized = normalizeDegrees(current);
    if (previous == null || !previous.isFinite) return normalized;
    final safeAlpha = alpha.clamp(0.0, 1.0).toDouble();
    final maxStep = maxStepDegrees.abs().clamp(1.0, 180.0).toDouble();
    final delta = shortestAngularDelta(previous, normalized);
    final smoothed = delta * safeAlpha;
    final limited = smoothed.clamp(-maxStep, maxStep).toDouble();
    return normalizeDegrees(previous + limited);
  }

  static double distanceMeters(
    double latitudeA,
    double longitudeA,
    double latitudeB,
    double longitudeB,
  ) {
    const earthRadiusMeters = 6371000.0;
    final lat1 = latitudeA * math.pi / 180;
    final lat2 = latitudeB * math.pi / 180;
    final dLat = (latitudeB - latitudeA) * math.pi / 180;
    final dLon = (longitudeB - longitudeA) * math.pi / 180;
    final sinLat = math.sin(dLat / 2);
    final sinLon = math.sin(dLon / 2);
    final a = sinLat * sinLat +
        math.cos(lat1) * math.cos(lat2) * sinLon * sinLon;
    final safeA = a.clamp(0.0, 1.0).toDouble();
    final c = 2 * math.atan2(math.sqrt(safeA), math.sqrt(1 - safeA));
    return earthRadiusMeters * c;
  }

  static double smoothCoordinate(
    double? previous,
    double current, {
    required double alpha,
  }) {
    if (previous == null || !previous.isFinite) return current;
    final safeAlpha = alpha.clamp(0.0, 1.0).toDouble();
    return previous + (current - previous) * safeAlpha;
  }

  static MapNavigationCameraTuning navigationCameraTuning({
    required MapTravelMode travelMode,
    required double speedKmh,
    double? distanceToManeuverMeters,
    double? distanceToDestinationMeters,
  }) {
    final safeSpeed = speedKmh.isFinite ? math.max(0, speedKmh) : 0.0;

    var zoom = switch (travelMode) {
      MapTravelMode.walking => 17.55,
      MapTravelMode.bicycle => 17.05,
      MapTravelMode.motorcycle => 16.55,
      MapTravelMode.car => 16.25,
    };
    var pitch = switch (travelMode) {
      MapTravelMode.walking => 34.0,
      MapTravelMode.bicycle => 47.0,
      MapTravelMode.motorcycle => 53.0,
      MapTravelMode.car => 55.0,
    };
    var centerAlpha = switch (travelMode) {
      MapTravelMode.walking => 0.46,
      MapTravelMode.bicycle => 0.54,
      MapTravelMode.motorcycle => 0.62,
      MapTravelMode.car => 0.66,
    };
    var bearingAlpha = switch (travelMode) {
      MapTravelMode.walking => 0.18,
      MapTravelMode.bicycle => 0.23,
      MapTravelMode.motorcycle => 0.28,
      MapTravelMode.car => 0.30,
    };
    var maxBearingStep = switch (travelMode) {
      MapTravelMode.walking => 18.0,
      MapTravelMode.bicycle => 23.0,
      MapTravelMode.motorcycle => 29.0,
      MapTravelMode.car => 31.0,
    };
    var durationMs = switch (travelMode) {
      MapTravelMode.walking => 650,
      MapTravelMode.bicycle => 560,
      MapTravelMode.motorcycle => 480,
      MapTravelMode.car => 440,
    };
    var minimumUpdateMeters = switch (travelMode) {
      MapTravelMode.walking => 1.2,
      MapTravelMode.bicycle => 1.8,
      MapTravelMode.motorcycle => 2.8,
      MapTravelMode.car => 3.5,
    };
    final topPaddingFraction = switch (travelMode) {
      MapTravelMode.walking => 0.31,
      MapTravelMode.bicycle => 0.36,
      MapTravelMode.motorcycle => 0.39,
      MapTravelMode.car => 0.41,
    };

    if (safeSpeed < 2) {
      pitch = math.min(pitch, 30).toDouble();
      centerAlpha = math.min(centerAlpha, 0.40).toDouble();
      bearingAlpha = math.min(bearingAlpha, 0.16).toDouble();
      maxBearingStep = math.min(maxBearingStep, 15).toDouble();
      minimumUpdateMeters = math.max(minimumUpdateMeters, 2.5).toDouble();
      durationMs = math.max(durationMs, 620);
    } else if (safeSpeed >= 80) {
      zoom -= 0.45;
      pitch += 2;
      centerAlpha = math.max(centerAlpha, 0.72).toDouble();
      durationMs = math.min(durationMs, 400);
    } else if (safeSpeed >= 45) {
      zoom -= 0.25;
      pitch += 1;
      centerAlpha = math.max(centerAlpha, 0.66).toDouble();
      durationMs = math.min(durationMs, 450);
    } else if (safeSpeed >= 20) {
      zoom -= 0.10;
      centerAlpha = math.max(centerAlpha, 0.60).toDouble();
    }

    if (distanceToManeuverMeters != null &&
        distanceToManeuverMeters.isFinite &&
        distanceToManeuverMeters >= 0) {
      if (distanceToManeuverMeters <= 55) {
        zoom = math.max(zoom, 17.75).toDouble();
        pitch = math.min(pitch, 41).toDouble();
        bearingAlpha = math.min(bearingAlpha + 0.04, 0.36).toDouble();
        maxBearingStep = math.min(maxBearingStep, 24).toDouble();
        durationMs = math.max(durationMs, 540);
      } else if (distanceToManeuverMeters <= 150) {
        zoom = math.max(zoom, 17.45).toDouble();
        pitch = math.min(pitch, 48).toDouble();
      }
    }

    if (distanceToDestinationMeters != null &&
        distanceToDestinationMeters.isFinite &&
        distanceToDestinationMeters >= 0) {
      if (distanceToDestinationMeters <= 25) {
        zoom = math.max(zoom, 18.25).toDouble();
        pitch = math.min(pitch, 24).toDouble();
        minimumUpdateMeters = math.min(minimumUpdateMeters, 0.8).toDouble();
      } else if (distanceToDestinationMeters <= 80) {
        zoom = math.max(zoom, 18.0).toDouble();
        pitch = math.min(pitch, 34).toDouble();
        minimumUpdateMeters = math.min(minimumUpdateMeters, 1.0).toDouble();
      } else if (distanceToDestinationMeters <= 250) {
        zoom = math.max(zoom, 17.55).toDouble();
        pitch = math.min(pitch, 44).toDouble();
      }
    }

    return MapNavigationCameraTuning(
      zoom: zoom.clamp(15.6, 18.4).toDouble(),
      pitch: pitch.clamp(20.0, 58.0).toDouble(),
      centerAlpha: centerAlpha.clamp(0.30, 0.80).toDouble(),
      bearingAlpha: bearingAlpha.clamp(0.12, 0.40).toDouble(),
      maxBearingStepDegrees: maxBearingStep.clamp(12.0, 36.0).toDouble(),
      animationDuration: Duration(milliseconds: durationMs),
      minimumCenterUpdateMeters:
          minimumUpdateMeters.clamp(0.6, 5.0).toDouble(),
      topPaddingFraction: topPaddingFraction,
      topPaddingMin: travelMode == MapTravelMode.walking ? 150.0 : 176.0,
      topPaddingMax: travelMode == MapTravelMode.car ? 330.0 : 300.0,
    );
  }

  static double navigationTopPadding({
    required double viewportHeight,
    required MapNavigationCameraTuning tuning,
  }) {
    if (!viewportHeight.isFinite || viewportHeight <= 0) {
      return tuning.topPaddingMin;
    }
    return (viewportHeight * tuning.topPaddingFraction)
        .clamp(tuning.topPaddingMin, tuning.topPaddingMax)
        .toDouble();
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
