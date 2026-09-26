import 'dart:math' as math;

import '../models/map_route_point.dart';

/// Limites conservadores para reduzir trabalho repetido do bloco mapa/Bike
/// sem atrasar navegação, alertas ou detecção de saída da rota.
class MapPerformancePolicy {
  const MapPerformancePolicy._();

  static const int gpsDistanceFilterMeters = 8;
  static const Duration poiUiMinimumInterval = Duration(seconds: 4);
  static const double poiUiMinimumDistanceMeters = 20;
  static const Duration automaticPoiRequestMinimumInterval =
      Duration(seconds: 90);

  static bool shouldRefreshPoiUi({
    required MapRoutePoint current,
    MapRoutePoint? lastPresented,
    DateTime? lastPresentedAt,
    DateTime? now,
  }) {
    if (lastPresented == null || lastPresentedAt == null) return true;
    final clock = now ?? DateTime.now();
    if (clock.difference(lastPresentedAt) >= poiUiMinimumInterval) return true;
    return _distanceMeters(lastPresented, current) >= poiUiMinimumDistanceMeters;
  }

  static bool canAttemptAutomaticPoiRequest({
    DateTime? lastAttemptAt,
    DateTime? now,
  }) {
    if (lastAttemptAt == null) return true;
    final clock = now ?? DateTime.now();
    return clock.difference(lastAttemptAt) >= automaticPoiRequestMinimumInterval;
  }

  static double _distanceMeters(MapRoutePoint a, MapRoutePoint b) {
    const earthRadiusMeters = 6371008.8;
    final lat1 = _radians(a.latitude);
    final lat2 = _radians(b.latitude);
    final deltaLat = _radians(b.latitude - a.latitude);
    final deltaLon = _radians(b.longitude - a.longitude);
    final sinLat = math.sin(deltaLat / 2);
    final sinLon = math.sin(deltaLon / 2);
    final h = sinLat * sinLat +
        math.cos(lat1) * math.cos(lat2) * sinLon * sinLon;
    final clamped = h.clamp(0.0, 1.0).toDouble();
    return earthRadiusMeters *
        2 *
        math.atan2(math.sqrt(clamped), math.sqrt(1 - clamped));
  }

  static double _radians(double degrees) => degrees * math.pi / 180;
}
