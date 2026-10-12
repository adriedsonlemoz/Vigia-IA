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
          // Proximidade linear não equivale a desvio por estrada: evitar
          // sugerir cidades remotas como paradas garantidas no trajeto.
          if (candidate.routeProximityMeters > 1500) continue;
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
          routeProximityMeters: selected?.routeProximityMeters,
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
    // A projeção por trecho evita confundir um ponto no meio de uma via
    // com outro a muitos quilômetros de um vértice. Amostragem limitada
    // mantém custo previsível em geometria extensa (até ~450 trechos).
    final step = math.max(1, (routePoints.length / 450).ceil()).toInt();
    final mapped = <_MappedTripCandidate>[];
    for (final result in candidates) {
      final candidatePoint = LatLng(result.latitude, result.longitude);
      var nearestMeters = double.infinity;
      var nearestGeometryMeters = 0.0;
      for (var index = 0; index < routePoints.length - 1; index += step) {
        final next = math.min(index + step, routePoints.length - 1).toInt();
        final a = routePoints[index];
        final b = routePoints[next];
        // Plano local equiretangular: somente para localizar o ponto mais
        // próximo no segmento. A distância exibida usa geodesia (Distance).
        final cosLat = math.cos(candidatePoint.latitude * math.pi / 180);
        final dx = (b.longitude - a.longitude) * cosLat;
        final dy = b.latitude - a.latitude;
        final px = (candidatePoint.longitude - a.longitude) * cosLat;
        final py = candidatePoint.latitude - a.latitude;
        final squared = dx * dx + dy * dy;
        final t = squared < 1e-20
            ? 0.0 : ((px * dx + py * dy) / squared).clamp(0.0, 1.0).toDouble();
        final point = LatLng(
          a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t,
        );
        final meters = distance.as(LengthUnit.Meter, candidatePoint, point);
        if (meters < nearestMeters) {
          nearestMeters = meters;
          nearestGeometryMeters = cumulativeGeometryMeters[index] +
              (cumulativeGeometryMeters[next] - cumulativeGeometryMeters[index]) * t;
        }
      }
      mapped.add(_MappedTripCandidate(
        result: result,
        routeDistanceMeters: nearestGeometryMeters * geometryScale,
        routeProximityMeters: nearestMeters,
        score: double.infinity,
      ));
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
      final endMeters = cumulativeGeometryMeters[index] * geometryScale;
      if (endMeters >= targetMeters) {
        final startMeters = cumulativeGeometryMeters[index - 1] * geometryScale;
        final interval = endMeters - startMeters;
        final fraction = interval <= 0 ? 0.0 :
            ((targetMeters - startMeters) / interval).clamp(0.0, 1.0).toDouble();
        final a = routePoints[index - 1];
        final b = routePoints[index];
        return LatLng(
          a.latitude + (b.latitude - a.latitude) * fraction,
          a.longitude + (b.longitude - a.longitude) * fraction,
        );
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
