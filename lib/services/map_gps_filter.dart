import 'dart:math' as math;

import '../models/map_route_point.dart';

enum MapGpsRejectionReason {
  invalidCoordinates,
  invalidAccuracy,
  staleReading,
  implausibleSpeed,
  implausibleDisplacement,
}

class MapGpsFilterResult {
  const MapGpsFilterResult.accepted(this.point) : rejectionReason = null;

  const MapGpsFilterResult.rejected(this.rejectionReason) : point = null;

  final MapRoutePoint? point;
  final MapGpsRejectionReason? rejectionReason;

  bool get accepted => point != null;
}

/// Filtra e suaviza o GPS antes que a posição chegue ao mapa e ao gravador de
/// percurso. Mantém limites conservadores para bike/viagem sem presumir que o
/// usuário esteja sempre pedalando: deslocamentos de automóvel continuam
/// possíveis, mas leituras incompatíveis com movimento terrestre são rejeitadas.
class MapGpsFilter {
  MapGpsFilter();

  static const double maximumAcceptedAccuracyMeters = 60;
  static const double maximumRecordingAccuracyMeters = 35;
  static const double maximumPlausibleSpeedMetersPerSecond = 70;
  static const double minimumHeadingSpeedMetersPerSecond = 1.2;
  static const Duration smoothingResetGap = Duration(seconds: 30);

  MapRoutePoint? _lastRawAccepted;
  MapRoutePoint? _lastSmoothed;
  double? _smoothedHeading;

  MapRoutePoint? get lastAccepted => _lastSmoothed;

  void reset({MapRoutePoint? seed}) {
    _lastRawAccepted = seed;
    _lastSmoothed = seed;
    _smoothedHeading = _validHeading(seed?.headingDegrees);
  }

  MapGpsFilterResult evaluate(MapRoutePoint raw) {
    if (!_coordinatesAreValid(raw)) {
      return const MapGpsFilterResult.rejected(
        MapGpsRejectionReason.invalidCoordinates,
      );
    }
    if (!raw.accuracyMeters.isFinite ||
        raw.accuracyMeters <= 0 ||
        raw.accuracyMeters > maximumAcceptedAccuracyMeters) {
      return const MapGpsFilterResult.rejected(
        MapGpsRejectionReason.invalidAccuracy,
      );
    }
    if (!raw.speedMetersPerSecond.isFinite ||
        raw.speedMetersPerSecond < 0 ||
        raw.speedMetersPerSecond > maximumPlausibleSpeedMetersPerSecond) {
      return const MapGpsFilterResult.rejected(
        MapGpsRejectionReason.implausibleSpeed,
      );
    }

    final previousRaw = _lastRawAccepted;
    var resetSmoothing = previousRaw == null;
    if (previousRaw != null) {
      final elapsed = raw.recordedAt.difference(previousRaw.recordedAt);
      if (elapsed <= Duration.zero) {
        return const MapGpsFilterResult.rejected(
          MapGpsRejectionReason.staleReading,
        );
      }
      if (elapsed > smoothingResetGap) {
        resetSmoothing = true;
      }
      final meters = distanceMeters(previousRaw, raw);
      final uncertainty = previousRaw.accuracyMeters + raw.accuracyMeters;
      final effectiveMeters = math.max(0.0, meters - uncertainty);
      final effectiveSpeed =
          effectiveMeters / (elapsed.inMilliseconds / 1000.0);
      if (effectiveSpeed > maximumPlausibleSpeedMetersPerSecond) {
        return const MapGpsFilterResult.rejected(
          MapGpsRejectionReason.implausibleDisplacement,
        );
      }
    }

    final smoothed = resetSmoothing
        ? _normalizeFreshPoint(raw)
        : _smoothPoint(raw, _lastSmoothed ?? previousRaw!);
    _lastRawAccepted = raw;
    _lastSmoothed = smoothed;
    _smoothedHeading = smoothed.headingDegrees;
    return MapGpsFilterResult.accepted(smoothed);
  }

  static bool isSuitableForRecording(MapRoutePoint point) {
    return point.accuracyMeters.isFinite &&
        point.accuracyMeters > 0 &&
        point.accuracyMeters <= maximumRecordingAccuracyMeters &&
        point.speedMetersPerSecond.isFinite &&
        point.speedMetersPerSecond >= 0 &&
        point.speedMetersPerSecond <= maximumPlausibleSpeedMetersPerSecond;
  }

  static double meaningfulMovementThresholdMeters(
    MapRoutePoint previous,
    MapRoutePoint current,
  ) {
    final accuracyNoise =
        (previous.accuracyMeters + current.accuracyMeters) * 0.25;
    return math.max(3.0, math.min(12.0, accuracyNoise));
  }

  MapRoutePoint _normalizeFreshPoint(MapRoutePoint raw) {
    final heading = raw.speedMetersPerSecond >= minimumHeadingSpeedMetersPerSecond
        ? _validHeading(raw.headingDegrees)
        : null;
    return MapRoutePoint(
      latitude: raw.latitude,
      longitude: raw.longitude,
      recordedAt: raw.recordedAt,
      accuracyMeters: raw.accuracyMeters,
      speedMetersPerSecond: _normalizedSpeed(raw.speedMetersPerSecond),
      speedAvailable: raw.speedAvailable,
      speedAccuracyMetersPerSecond: raw.speedAccuracyMetersPerSecond,
      altitudeMeters: raw.altitudeMeters,
      altitudeAccuracyMeters: raw.altitudeAccuracyMeters,
      headingDegrees: heading,
      headingAvailable: raw.headingAvailable && heading != null,
      headingAccuracyDegrees: raw.headingAccuracyDegrees,
    );
  }

  MapRoutePoint _smoothPoint(MapRoutePoint raw, MapRoutePoint previous) {
    final alpha = _positionAlpha(raw);
    final latitude = _lerp(previous.latitude, raw.latitude, alpha);
    final longitude = _lerp(previous.longitude, raw.longitude, alpha);
    final speed = raw.speedMetersPerSecond < 0.5
        ? 0.0
        : _lerp(previous.speedMetersPerSecond, raw.speedMetersPerSecond, 0.65);

    double? candidateHeading;
    if (raw.speedMetersPerSecond >= minimumHeadingSpeedMetersPerSecond) {
      candidateHeading = _validHeading(raw.headingDegrees);
      if (candidateHeading == null) {
        final movement = distanceMeters(previous, raw);
        if (movement >= math.max(8.0, raw.accuracyMeters * 0.6)) {
          candidateHeading = bearingDegrees(previous, raw);
        }
      }
    }
    final heading = candidateHeading == null
        ? _smoothedHeading
        : _smoothAngle(_smoothedHeading, candidateHeading, 0.35);

    return MapRoutePoint(
      latitude: latitude,
      longitude: longitude,
      recordedAt: raw.recordedAt,
      accuracyMeters: raw.accuracyMeters,
      speedMetersPerSecond: speed,
      speedAvailable: raw.speedAvailable,
      speedAccuracyMetersPerSecond: raw.speedAccuracyMetersPerSecond,
      altitudeMeters: raw.altitudeMeters,
      altitudeAccuracyMeters: raw.altitudeAccuracyMeters,
      headingDegrees: heading,
      headingAvailable: raw.headingAvailable && candidateHeading != null,
      headingAccuracyDegrees: raw.headingAccuracyDegrees,
    );
  }

  static double _positionAlpha(MapRoutePoint point) {
    var alpha = switch (point.accuracyMeters) {
      <= 8 => 0.78,
      <= 15 => 0.65,
      <= 30 => 0.50,
      _ => 0.35,
    };
    if (point.speedMetersPerSecond >= 10) {
      alpha = math.min(0.85, alpha + 0.10);
    }
    return alpha;
  }

  static bool _coordinatesAreValid(MapRoutePoint point) {
    return point.latitude.isFinite &&
        point.longitude.isFinite &&
        point.latitude >= -90 &&
        point.latitude <= 90 &&
        point.longitude >= -180 &&
        point.longitude <= 180;
  }

  static double _normalizedSpeed(double value) => value < 0.5 ? 0 : value;

  static double? _validHeading(double? value) {
    if (value == null || !value.isFinite || value < 0) return null;
    return ((value % 360) + 360) % 360;
  }

  static double _smoothAngle(double? previous, double current, double alpha) {
    if (previous == null) return current;
    final delta = ((current - previous + 540) % 360) - 180;
    return ((previous + delta * alpha) % 360 + 360) % 360;
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  static double distanceMeters(MapRoutePoint a, MapRoutePoint b) {
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

  static double bearingDegrees(MapRoutePoint a, MapRoutePoint b) {
    final lat1 = _radians(a.latitude);
    final lat2 = _radians(b.latitude);
    final deltaLon = _radians(b.longitude - a.longitude);
    final y = math.sin(deltaLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(deltaLon);
    return ((math.atan2(y, x) * 180 / math.pi) + 360) % 360;
  }

  static double _radians(double degrees) => degrees * math.pi / 180;
}
