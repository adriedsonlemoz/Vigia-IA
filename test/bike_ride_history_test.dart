import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/bike_ride_history.dart';
import 'package:vigiaia/models/map_route_point.dart';
import 'package:vigiaia/services/bike_ride_history_service.dart';

MapRoutePoint _point({
  required double longitude,
  required DateTime at,
}) =>
    MapRoutePoint(
      latitude: 0,
      longitude: longitude,
      recordedAt: at,
      accuracyMeters: 5,
      speedMetersPerSecond: 4.2,
    );

void main() {
  const analyzer = BikeRideHistoryAnalyzer();

  test('aceita percurso de bicicleta consistente e calcula média real', () {
    final startedAt = DateTime.utc(2026, 9, 26, 10);
    final points = <MapRoutePoint>[];
    for (var index = 0; index <= 240; index++) {
      points.add(
        _point(
          longitude: index * 0.0005,
          at: startedAt.add(Duration(seconds: index * 15)),
        ),
      );
    }

    final entry = analyzer.analyze(
      segments: <List<MapRoutePoint>>[points],
      distanceMeters: 13300,
      elapsedDuration: const Duration(hours: 1),
      startedAt: startedAt,
      endedAt: startedAt.add(const Duration(hours: 1)),
    );

    expect(entry, isNotNull);
    expect(entry!.movingAverageSpeedKmh, inInclusiveRange(12, 15));
  });

  test('rejeita amostra com velocidade incompatível com bicicleta', () {
    final startedAt = DateTime.utc(2026, 9, 26, 10);
    final points = <MapRoutePoint>[
      _point(longitude: 0, at: startedAt),
      _point(
        longitude: 0.02,
        at: startedAt.add(const Duration(seconds: 20)),
      ),
      _point(
        longitude: 0.04,
        at: startedAt.add(const Duration(seconds: 40)),
      ),
    ];

    final entry = analyzer.analyze(
      segments: <List<MapRoutePoint>>[points],
      distanceMeters: 5000,
      elapsedDuration: const Duration(minutes: 15),
      startedAt: startedAt,
      endedAt: startedAt.add(const Duration(minutes: 15)),
    );

    expect(entry, isNull);
  });

  test('histórico só fica confiável após volume mínimo de pedal', () {
    final entries = <BikeRideHistoryEntry>[
      for (var index = 0; index < 3; index++)
        BikeRideHistoryEntry(
          startedAt: DateTime.utc(2026, 9, 20 + index, 8),
          endedAt: DateTime.utc(2026, 9, 20 + index, 9),
          distanceMeters: 12000,
          movingDuration: const Duration(minutes: 55),
          elapsedDuration: const Duration(hours: 1),
          movingAverageSpeedKmh: 13.1 + index * 0.4,
          overallAverageSpeedKmh: 12,
        ),
    ];

    final summary = analyzer.summarize(entries);

    expect(summary.reliable, isTrue);
    expect(summary.rideCount, 3);
    expect(summary.totalDistanceKm, 36);
    expect(summary.learnedMovingSpeedKmh, inInclusiveRange(13, 14));
  });
}
