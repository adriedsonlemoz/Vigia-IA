import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:vigiaia/models/bike_trip_plan.dart';
import 'package:vigiaia/models/map_cycling_route.dart';
import 'package:vigiaia/models/map_travel_mode.dart';
import 'package:vigiaia/services/map_route_preview_metrics.dart';

void main() {
  MapCyclingRoute route(double meters, double seconds) => MapCyclingRoute(
    points: const <LatLng>[LatLng(-20, -45), LatLng(-20, -44.5)],
    distanceMeters: meters,
    durationSeconds: seconds,
  );

  test('prévia de bicicleta usa ritmo salvo e não velocidade fixa 15 km/h', () {
    final chosen = MapRoutePreviewMetrics.forRoute(
      route: route(30000, 900),
      mode: MapTravelMode.bicycle,
      bikePreferences: const BikeTravelPreferences(averageSpeedKmh: 10),
    );
    expect(chosen.durationMinutes, 180);
    expect(chosen.durationLabel, '3h00');
    expect(chosen.durationSource, contains('10.0 km/h'));
  });

  test('rota carro usa tempo fornecido e não o ritmo de bicicleta', () {
    final chosen = MapRoutePreviewMetrics.forRoute(
      route: route(30000, 1800),
      mode: MapTravelMode.car,
      bikePreferences: const BikeTravelPreferences(averageSpeedKmh: 10),
    );
    expect(chosen.durationMinutes, 30);
    expect(chosen.durationLabel, '0h30');
  });

  test('sem tempo de provedor não inventa previsão', () {
    final chosen = MapRoutePreviewMetrics.forRoute(
      route: route(30000, 0),
      mode: MapTravelMode.walking,
      bikePreferences: const BikeTravelPreferences(),
    );
    expect(chosen.durationMinutes, isNull);
    expect(chosen.durationLabel, 'tempo indisponível');
  });

  test('ritmo inválido não causa divisão por zero ou estimativa falsa', () {
    final chosen = MapRoutePreviewMetrics.forRoute(
      route: route(30000, 60),
      mode: MapTravelMode.bicycle,
      bikePreferences: const BikeTravelPreferences(averageSpeedKmh: 0),
    );
    expect(chosen.durationMinutes, isNull);
  });

  test('diferença de distância entre alternativas é relativa, não segurança', () {
    final shortest = MapRoutePreviewMetrics.forRoute(
      route: route(30000, 1800),
      mode: MapTravelMode.car,
      bikePreferences: const BikeTravelPreferences(),
    );
    final longer = MapRoutePreviewMetrics.forRoute(
      route: route(35000, 1700),
      mode: MapTravelMode.car,
      bikePreferences: const BikeTravelPreferences(),
    );
    expect(longer.distanceDifference(shortest), '+5.0 km em relação à rota 1');
    expect(shortest.distanceDifference(shortest), 'distância semelhante');
  });
}
