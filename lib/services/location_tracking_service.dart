import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../models/map_route_point.dart';

enum LocationTrackingAvailability {
  ready,
  servicesDisabled,
  permissionDenied,
  permissionDeniedForever,
}

class LocationTrackingService {
  LocationTrackingService._();

  static final LocationTrackingService instance = LocationTrackingService._();

  Future<LocationTrackingAvailability> ensureAvailable() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationTrackingAvailability.servicesDisabled;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
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
      distanceFilter: 5,
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
        accuracyMeters: position.accuracy,
        speedMetersPerSecond: position.speed < 0 ? 0 : position.speed,
        altitudeMeters: position.altitude,
        headingDegrees: position.heading < 0 ? null : position.heading,
      );
}
