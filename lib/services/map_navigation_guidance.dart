import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../models/map_cycling_route.dart';
import '../models/map_route_point.dart';

class MapNavigationProgress {
  const MapNavigationProgress({
    required this.currentInstruction,
    required this.remainingDistanceMeters,
    required this.remainingDurationSeconds,
    required this.progressFraction,
    required this.distanceFromRouteMeters,
    required this.offRoute,
    required this.arrived,
    this.nextInstruction,
    this.distanceToNextManeuverMeters,
  });

  final String currentInstruction;
  final String? nextInstruction;
  final double? distanceToNextManeuverMeters;
  final double remainingDistanceMeters;
  final double remainingDurationSeconds;
  final double progressFraction;
  final double distanceFromRouteMeters;
  final bool offRoute;
  final bool arrived;
}

/// Calcula orientação local sobre a geometria já retornada pelo roteador.
/// Não faz chamadas de rede e pode ser testado isoladamente.
class MapNavigationGuidance {
  const MapNavigationGuidance();

  static const double offRouteThresholdMeters = 45;
  static const double arrivalThresholdMeters = 25;
  static const int offRouteSamplesBeforeRecalculation = 2;
  static const Duration recalculationCooldown = Duration(seconds: 45);

  MapNavigationProgress? evaluate({
    required MapCyclingRoute route,
    required MapRoutePoint position,
  }) {
    if (route.points.length < 2) return null;

    final cumulative = _cumulativeDistances(route.points);
    final totalGeometryMeters = cumulative.last;
    if (totalGeometryMeters <= 0) return null;

    final match = _nearestMatch(
      route.points,
      cumulative,
      latitude: position.latitude,
      longitude: position.longitude,
    );
    final travelledGeometryMeters = match.routeMeters
        .clamp(0.0, totalGeometryMeters)
        .toDouble();
    final progressFraction = (travelledGeometryMeters / totalGeometryMeters)
        .clamp(0.0, 1.0)
        .toDouble();
    final remainingGeometryMeters =
        math.max(0.0, totalGeometryMeters - travelledGeometryMeters);

    final routeScale = route.distanceMeters > 0
        ? route.distanceMeters / totalGeometryMeters
        : 1.0;
    final remainingDistanceMeters = remainingGeometryMeters * routeScale;
    final remainingDurationSeconds = route.durationSeconds > 0
        ? route.durationSeconds * (1 - progressFraction)
        : 0.0;

    final effectiveOffRouteThreshold = math.max(
      offRouteThresholdMeters,
      math.max(0.0, position.accuracyMeters) * 1.5,
    );
    final destination = route.points.last;
    final destinationDistance = _distanceMeters(
      position.latitude,
      position.longitude,
      destination.latitude,
      destination.longitude,
    );
    final effectiveArrivalThreshold = math.max(
      arrivalThresholdMeters,
      math.max(0.0, position.accuracyMeters),
    );

    final maneuverState = _maneuverState(
      route: route,
      cumulative: cumulative,
      travelledGeometryMeters: travelledGeometryMeters,
    );

    final distanceToNextManeuverMeters =
        maneuverState.distanceToNextManeuverMeters;
    return MapNavigationProgress(
      currentInstruction: maneuverState.currentInstruction,
      nextInstruction: maneuverState.nextInstruction,
      distanceToNextManeuverMeters: distanceToNextManeuverMeters == null
          ? null
          : distanceToNextManeuverMeters * routeScale,
      remainingDistanceMeters: remainingDistanceMeters,
      remainingDurationSeconds: remainingDurationSeconds,
      progressFraction: progressFraction,
      distanceFromRouteMeters: match.distanceMeters,
      offRoute: match.distanceMeters > effectiveOffRouteThreshold,
      arrived: destinationDistance <= effectiveArrivalThreshold ||
          remainingDistanceMeters <= arrivalThresholdMeters,
    );
  }

  _ManeuverState _maneuverState({
    required MapCyclingRoute route,
    required List<double> cumulative,
    required double travelledGeometryMeters,
  }) {
    final maneuvers = route.maneuvers;
    if (maneuvers.isEmpty) {
      return const _ManeuverState(
        currentInstruction: 'Siga pela rota destacada',
      );
    }

    var currentIndex = 0;
    for (var index = 0; index < maneuvers.length; index++) {
      final beginIndex = maneuvers[index]
          .beginShapeIndex
          .clamp(0, cumulative.length - 1)
          .toInt();
      if (cumulative[beginIndex] <= travelledGeometryMeters + 2) {
        currentIndex = index;
      } else {
        break;
      }
    }

    final current = maneuvers[currentIndex];
    MapCyclingManeuver? next;
    double? distanceToNext;
    if (currentIndex + 1 < maneuvers.length) {
      next = maneuvers[currentIndex + 1];
      final nextIndex = next.beginShapeIndex
          .clamp(0, cumulative.length - 1)
          .toInt();
      distanceToNext = math.max(
        0.0,
        cumulative[nextIndex] - travelledGeometryMeters,
      );
    }

    return _ManeuverState(
      currentInstruction: current.instruction,
      nextInstruction: next?.instruction,
      distanceToNextManeuverMeters: distanceToNext,
    );
  }

  List<double> _cumulativeDistances(List<LatLng> points) {
    final result = List<double>.filled(points.length, 0);
    for (var index = 1; index < points.length; index++) {
      final previous = points[index - 1];
      final current = points[index];
      result[index] = result[index - 1] +
          _distanceMeters(
            previous.latitude,
            previous.longitude,
            current.latitude,
            current.longitude,
          );
    }
    return result;
  }

  _RouteMatch _nearestMatch(
    List<LatLng> points,
    List<double> cumulative, {
    required double latitude,
    required double longitude,
  }) {
    final latScale = 111320.0;
    final lonScale = 111320.0 * math.cos(latitude * math.pi / 180);
    var bestDistance = double.infinity;
    var bestRouteMeters = 0.0;

    for (var index = 0; index < points.length - 1; index++) {
      final a = points[index];
      final b = points[index + 1];
      final ax = (a.longitude - longitude) * lonScale;
      final ay = (a.latitude - latitude) * latScale;
      final bx = (b.longitude - longitude) * lonScale;
      final by = (b.latitude - latitude) * latScale;
      final dx = bx - ax;
      final dy = by - ay;
      final lengthSquared = dx * dx + dy * dy;
      final t = lengthSquared <= 0
          ? 0.0
          : ((-ax * dx - ay * dy) / lengthSquared)
              .clamp(0.0, 1.0)
              .toDouble();
      final closestX = ax + dx * t;
      final closestY = ay + dy * t;
      final distance = math.sqrt(
        closestX * closestX + closestY * closestY,
      );
      if (distance < bestDistance) {
        bestDistance = distance;
        final segmentMeters = cumulative[index + 1] - cumulative[index];
        bestRouteMeters = cumulative[index] + segmentMeters * t;
      }
    }

    return _RouteMatch(
      distanceMeters: bestDistance,
      routeMeters: bestRouteMeters,
    );
  }

  double _distanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusMeters = 6371000.0;
    final lat1Rad = lat1 * math.pi / 180;
    final lat2Rad = lat2 * math.pi / 180;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final sinLat = math.sin(dLat / 2);
    final sinLon = math.sin(dLon / 2);
    final a = sinLat * sinLat +
        math.cos(lat1Rad) * math.cos(lat2Rad) * sinLon * sinLon;
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }
}

class _RouteMatch {
  const _RouteMatch({
    required this.distanceMeters,
    required this.routeMeters,
  });

  final double distanceMeters;
  final double routeMeters;
}

class _ManeuverState {
  const _ManeuverState({
    required this.currentInstruction,
    this.nextInstruction,
    this.distanceToNextManeuverMeters,
  });

  final String currentInstruction;
  final String? nextInstruction;
  final double? distanceToNextManeuverMeters;
}
