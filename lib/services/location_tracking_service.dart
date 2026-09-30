import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../models/map_route_point.dart';
import 'map_performance_policy.dart';

enum LocationTrackingAvailability {
  ready,
  servicesDisabled,
  permissionDenied,
  permissionDeniedForever,
}

class LocationTrackingService {
  LocationTrackingService._();

  static final LocationTrackingService instance = LocationTrackingService._();

  Future<LocationTrackingAvailability> ensureAvailable({
    bool requestPermission = true,
  }) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationTrackingAvailability.servicesDisabled;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && requestPermission) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return LocationTrackingAvailability.permissionDeniedForever;
    }
    if (permission == LocationPermission.denied) {
      return LocationTrackingAvailability.permissionDenied;
    }
    return LocationTrackingAvailability.ready;
  }

  Stream<MapRoutePoint> positionStream() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: MapPerformancePolicy.gpsDistanceFilterMeters,
    );
    return Geolocator.getPositionStream(locationSettings: settings).map(_toPoint);
  }

  Future<MapRoutePoint> currentPosition() async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
    return _toPoint(position);
  }

  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  Future<void> openAppSettings() => Geolocator.openAppSettings();

  static double distanceMeters(MapRoutePoint a, MapRoutePoint b) {
    return Geolocator.distanceBetween(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
  }

  MapRoutePoint _toPoint(Position position) => MapRoutePoint(
        latitude: position.latitude,
        longitude: position.longitude,
        recordedAt: position.timestamp,
        accuracyMeters: position.hasAccuracy ? position.accuracy : 0,
        speedMetersPerSecond:
            position.hasSpeed && position.speed >= 0 ? position.speed : 0,
        speedAvailable: position.hasSpeed,
        speedAccuracyMetersPerSecond: position.hasSpeedAccuracy &&
                position.speedAccuracy.isFinite &&
                position.speedAccuracy > 0
            ? position.speedAccuracy
            : null,
        altitudeMeters: position.hasAltitude ? position.altitude : null,
        altitudeAccuracyMeters: position.hasAltitudeAccuracy &&
                position.altitudeAccuracy.isFinite &&
                position.altitudeAccuracy > 0
            ? position.altitudeAccuracy
            : null,
        headingDegrees: position.hasHeading && position.heading >= 0
            ? position.heading
            : null,
        headingAvailable: position.hasHeading,
        headingAccuracyDegrees: position.hasHeadingAccuracy &&
                position.headingAccuracy.isFinite &&
                position.headingAccuracy > 0
            ? position.headingAccuracy
            : null,
      );
}
