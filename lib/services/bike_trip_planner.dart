import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../models/bike_trip_plan.dart';
import '../models/map_destination_search.dart';

class BikeTripPlanner {
  const BikeTripPlanner();

  BikeTripEstimate estimate({
    required double distanceMeters,
    required BikeTravelPreferences preferences,
  }) {
    final safeDistance = math.max(0.0, distanceMeters).toDouble();
    final safeSpeed = preferences.averageSpeedKmh.clamp(5.0, 40.0).toDouble();
    final safeHours = preferences.ridingHoursPerDay.clamp(1.0, 12.0).toDouble();
    final ridingHours = safeDistance / 1000 / safeSpeed;
    final seconds = (ridingHours * 3600).round();
    final days = ridingHours <= 0
        ? 1
        : math.max(1, (ridingHours / safeHours).ceil()).toInt();
    return BikeTripEstimate(
      distanceMeters: safeDistance,
      ridingDuration: Duration(seconds: seconds),
      dayCount: days,
      preferences: preferences.copyWith(
        averageSpeedKmh: safeSpeed,
        ridingHoursPerDay: safeHours,
      ),
    );
  }

  Duration remainingDuration({
    required double remainingDistanceMeters,
    required BikeTravelPreferences preferences,
  }) {
    return estimate(
      distanceMeters: remainingDistanceMeters,
      preferences: preferences,
    ).ridingDuration;
  }

  BikeTripPlan buildPlan({
    required List<LatLng> routePoints,
    required double routeDistanceMeters,
    required BikeTravelPreferences preferences,
    required String destinationLabel,
    required List<MapDestinationSearchResult> candidates,
  }) {
    final tripEstimate = estimate(
      distanceMeters: routeDistanceMeters,
      preferences: preferences,
    );
    if (routePoints.length < 2) {
      return BikeTripPlan(estimate: tripEstimate, days: const <BikeTripDayPlan>[]);
    }

    final cumulative = <double>[0];
    var geometryMeters = 0.0;
    const distance = Distance();
    for (var index = 1; index < routePoints.length; index++) {
      geometryMeters += distance.as(
        LengthUnit.Meter,
        routePoints[index - 1],
        routePoints[index],
      );
      cumulative.add(geometryMeters);
    }
    final scale = geometryMeters <= 0 ? 1.0 : routeDistanceMeters / geometryMeters;
    final mappedCandidates = _mapCandidatesToRoute(
      routePoints: routePoints,
      cumulativeGeometryMeters: cumulative,
      geometryScale: scale,
      candidates: candidates,
    );

    final days = <BikeTripDayPlan>[];
    final usedIds = <String>{};
    var previousEnd = 0.0;
    for (var day = 1; day <= tripEstimate.dayCount; day++) {
      final finalDay = day == tripEstimate.dayCount;
      final idealEnd = finalDay
          ? routeDistanceMeters
          : _idealCumulativeDistance(
              day: day,
              totalDays: tripEstimate.dayCount,
              totalDistanceMeters: routeDistanceMeters,
              preferences: tripEstimate.preferences,
            );

      _MappedTripCandidate? selected;
      if (!finalDay) {
        final dailyTarget = routeDistanceMeters / tripEstimate.dayCount;
        final maxDelta = math.max(18000.0, dailyTarget * 0.35).toDouble();
        for (final candidate in mappedCandidates) {
          if (usedIds.contains(candidate.result.id)) continue;
          if (candidate.routeDistanceMeters <= previousEnd + 5000) continue;
          if (candidate.routeDistanceMeters >= routeDistanceMeters - 5000) continue;
          if (candidate.routeProximityMeters > 15000) continue;
          final delta = (candidate.routeDistanceMeters - idealEnd).abs();
          if (delta > maxDelta) continue;
          final score = delta +
              candidate.routeProximityMeters * 2.2 +
              _kindPenalty(candidate.result.kind);
          if (selected == null || score < selected.score) {
            selected = candidate.copyWith(score: score);
          }
        }
      }

      final endDistance = finalDay
          ? routeDistanceMeters
          : selected?.routeDistanceMeters ?? idealEnd;
      final routePoint = _pointAtDistance(
        routePoints: routePoints,
        cumulativeGeometryMeters: cumulative,
        geometryScale: scale,
        targetMeters: endDistance,
      );
      if (selected != null) usedIds.add(selected.result.id);
      final segmentMeters = math.max(0.0, endDistance - previousEnd).toDouble();
      final seconds = (segmentMeters /
              1000 /
              tripEstimate.preferences.averageSpeedKmh *
              3600)
          .round();
      days.add(
        BikeTripDayPlan(
          day: day,
          startDistanceMeters: previousEnd,
          endDistanceMeters: endDistance,
          ridingDuration: Duration(seconds: seconds),
          stopLabel: finalDay
              ? destinationLabel
              : selected?.result.title ?? 'Parada aproximada na rota',
          stopLatitude: selected?.result.latitude ?? routePoint.latitude,
          stopLongitude: selected?.result.longitude ?? routePoint.longitude,
          stopKind: finalDay
              ? 'Destino'
              : selected == null
                  ? 'Sem local confirmado'
                  : selected.result.kind.label,
          usesKnownPlace: finalDay || selected != null,
        ),
      );
      previousEnd = endDistance;
    }
    return BikeTripPlan(
      estimate: tripEstimate,
      days: List<BikeTripDayPlan>.unmodifiable(days),
    );
  }

  double _idealCumulativeDistance({
    required int day,
    required int totalDays,
    required double totalDistanceMeters,
    required BikeTravelPreferences preferences,
  }) {
    if (preferences.balanceDays) {
      return totalDistanceMeters * day / totalDays;
    }
    final dailyMeters = preferences.averageSpeedKmh *
        preferences.ridingHoursPerDay *
        1000;
    return math.min(totalDistanceMeters, dailyMeters * day).toDouble();
  }

  List<_MappedTripCandidate> _mapCandidatesToRoute({
    required List<LatLng> routePoints,
    required List<double> cumulativeGeometryMeters,
    required double geometryScale,
    required List<MapDestinationSearchResult> candidates,
  }) {
    const distance = Distance();
    final step = math.max(1, routePoints.length ~/ 450).toInt();
    final mapped = <_MappedTripCandidate>[];
    for (final result in candidates) {
      final candidatePoint = LatLng(result.latitude, result.longitude);
      var nearestIndex = 0;
      var nearestMeters = double.infinity;
      for (var index = 0; index < routePoints.length; index += step) {
        final meters = distance.as(
          LengthUnit.Meter,
          candidatePoint,
          routePoints[index],
        );
        if (meters < nearestMeters) {
          nearestMeters = meters;
          nearestIndex = index;
        }
      }
      if (nearestIndex != routePoints.length - 1) {
        final meters = distance.as(
          LengthUnit.Meter,
          candidatePoint,
          routePoints.last,
        );
        if (meters < nearestMeters) {
          nearestMeters = meters;
          nearestIndex = routePoints.length - 1;
        }
      }
      mapped.add(
        _MappedTripCandidate(
          result: result,
          routeDistanceMeters:
              cumulativeGeometryMeters[nearestIndex] * geometryScale,
          routeProximityMeters: nearestMeters,
          score: double.infinity,
        ),
      );
    }
    return mapped;
  }

  LatLng _pointAtDistance({
    required List<LatLng> routePoints,
    required List<double> cumulativeGeometryMeters,
    required double geometryScale,
    required double targetMeters,
  }) {
    for (var index = 1; index < cumulativeGeometryMeters.length; index++) {
      if (cumulativeGeometryMeters[index] * geometryScale >= targetMeters) {
        return routePoints[index];
      }
    }
    return routePoints.last;
  }

  double _kindPenalty(MapDestinationKind kind) => switch (kind) {
        MapDestinationKind.city => 0.0,
        MapDestinationKind.town => 1000.0,
        MapDestinationKind.village => 2500.0,
        MapDestinationKind.community => 4500.0,
        MapDestinationKind.pointOfInterest => 3500.0,
        MapDestinationKind.place => 7000.0,
      };
}

class _MappedTripCandidate {
  const _MappedTripCandidate({
    required this.result,
    required this.routeDistanceMeters,
    required this.routeProximityMeters,
    required this.score,
  });

  final MapDestinationSearchResult result;
  final double routeDistanceMeters;
  final double routeProximityMeters;
  final double score;

  _MappedTripCandidate copyWith({double? score}) => _MappedTripCandidate(
        result: result,
        routeDistanceMeters: routeDistanceMeters,
        routeProximityMeters: routeProximityMeters,
        score: score ?? this.score,
      );
}
