import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:vigiaia/models/bike_trip_plan.dart';
import 'package:vigiaia/models/map_destination_search.dart';
import 'package:vigiaia/services/bike_trip_planner.dart';

void main() {
  const planner = BikeTripPlanner();

  BikeTripPlan build(double candidateLat, double candidateLon) =>
      planner.buildPlan(
        // Trecho longo sem vértice no meio. A projeção deve usar segmento.
        routePoints: const <LatLng>[LatLng(0, 0), LatLng(0, 1)],
        routeDistanceMeters: 111000,
        preferences: const BikeTravelPreferences(
          averageSpeedKmh: 15, ridingHoursPerDay: 4, balanceDays: true),
        destinationLabel: 'Destino final',
        candidates: <MapDestinationSearchResult>[
          MapDestinationSearchResult(
            id: 'apoio-1', title: 'Cidade de apoio', subtitle: 'Localidade',
            latitude: candidateLat, longitude: candidateLon,
            distanceMeters: 0, kind: MapDestinationKind.city, source: 'offline',
          ),
        ],
      );

  test('local no meio do segmento é candidato mesmo longe dos vértices', () {
    final plan = build(0.002, 0.5);
    expect(plan.days, hasLength(2));
    expect(plan.days.first.stopLabel, 'Cidade de apoio');
    expect(plan.days.first.usesKnownPlace, isTrue);
    expect(plan.days.first.routeProximityMeters, isNotNull);
    expect(plan.days.first.routeProximityMeters!, lessThan(300));
    expect(plan.days.first.routeProximityMeters!, greaterThan(100));
    expect(plan.days.first.endDistanceMeters, closeTo(55500, 250));
  });

  test('local longe da geometria não vira parada conhecida', () {
    final plan = build(0.1, 0.5);
    expect(plan.days.first.usesKnownPlace, isFalse);
    expect(plan.days.first.routeProximityMeters, isNull);
    expect(plan.days.first.stopLabel, 'Parada aproximada na rota');
    expect(plan.days.first.stopLongitude, closeTo(0.5, 0.05));
  });

  test('local quase no segmento não implica serviço ou acesso confirmado', () {
    final plan = build(0, 0.5);
    expect(plan.days.first.usesKnownPlace, isTrue);
    expect(plan.days.first.routeProximityMeters!, lessThan(10));
    // Proximidade é somente dado geométrico, não há campo de serviço aberto.
  });
}
