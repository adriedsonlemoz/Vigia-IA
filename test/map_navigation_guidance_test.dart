import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:vigiaia/models/map_cycling_route.dart';
import 'package:vigiaia/models/map_route_point.dart';
import 'package:vigiaia/services/map_navigation_guidance.dart';

void main() {
  const guidance = MapNavigationGuidance();
  final route = MapCyclingRoute(
    points: const <LatLng>[
      LatLng(-19.9200, -43.9400),
      LatLng(-19.9200, -43.9350),
      LatLng(-19.9150, -43.9350),
    ],
    distanceMeters: 1100,
    durationSeconds: 330,
    maneuvers: const <MapCyclingManeuver>[
      MapCyclingManeuver(
        instruction: 'Siga em frente',
        beginShapeIndex: 0,
        endShapeIndex: 1,
        distanceMeters: 550,
        durationSeconds: 165,
      ),
      MapCyclingManeuver(
        instruction: 'Vire à esquerda',
        beginShapeIndex: 1,
        endShapeIndex: 2,
        distanceMeters: 550,
        durationSeconds: 165,
      ),
    ],
  );

  MapRoutePoint point(double lat, double lon, {double accuracy = 5}) =>
      MapRoutePoint(
        latitude: lat,
        longitude: lon,
        recordedAt: DateTime.utc(2026, 9, 25, 16),
        accuracyMeters: accuracy,
        speedMetersPerSecond: 4,
      );

  test('orientação informa manobra atual, próxima e progresso', () {
    final progress = guidance.evaluate(
      route: route,
      position: point(-19.9200, -43.9380),
    );

    expect(progress, isNotNull);
    expect(progress!.currentInstruction, 'Siga em frente');
    expect(progress.nextInstruction, 'Vire à esquerda');
    expect(progress.distanceToNextManeuverMeters, isNotNull);
    expect(progress.progressFraction, greaterThan(0));
    expect(progress.progressFraction, lessThan(1));
    expect(progress.offRoute, isFalse);
  });

  test('desvio real da geometria marca rota como fora do caminho', () {
    final progress = guidance.evaluate(
      route: route,
      position: point(-19.9185, -43.9380),
    );

    expect(progress, isNotNull);
    expect(progress!.distanceFromRouteMeters, greaterThan(45));
    expect(progress.offRoute, isTrue);
  });

  test('limites de recálculo evitam disparo por uma leitura isolada', () {
    expect(MapNavigationGuidance.offRouteSamplesBeforeRecalculation, 2);
    expect(
      MapNavigationGuidance.recalculationCooldown,
      const Duration(seconds: 45),
    );
  });
}
