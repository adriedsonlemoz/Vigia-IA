import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:vigiaia/models/bike_trip_plan.dart';
import 'package:vigiaia/models/map_destination_search.dart';
import 'package:vigiaia/services/bike_trip_planner.dart';

void main() {
  const planner = BikeTripPlanner();

  test('150 km a 15 km/h com 4 h por dia vira 3 dias', () {
    final estimate = planner.estimate(
      distanceMeters: 150000,
      preferences: const BikeTravelPreferences(
        averageSpeedKmh: 15,
        ridingHoursPerDay: 4,
      ),
    );

    expect(estimate.ridingDuration, const Duration(hours: 10));
    expect(estimate.dayCount, 3);
  });

  test('plano prefere local real e não inventa serviço quando não há candidato', () {
    final plan = planner.buildPlan(
      routePoints: const <LatLng>[
        LatLng(0, 0),
        LatLng(0, 0.45),
        LatLng(0, 0.90),
        LatLng(0, 1.35),
      ],
      routeDistanceMeters: 150000,
      preferences: const BikeTravelPreferences(
        averageSpeedKmh: 15,
        ridingHoursPerDay: 4,
        balanceDays: true,
      ),
      destinationLabel: 'Destino final',
      candidates: const <MapDestinationSearchResult>[
        MapDestinationSearchResult(
          id: 'city-1',
          title: 'Cidade de apoio',
          subtitle: 'Cidade',
          latitude: 0,
          longitude: 0.45,
          distanceMeters: 50000,
          kind: MapDestinationKind.city,
          source: 'offline',
        ),
      ],
    );

    expect(plan.days, hasLength(3));
    expect(plan.days.first.stopLabel, 'Cidade de apoio');
    expect(plan.days.first.usesKnownPlace, isTrue);
    expect(plan.days[1].usesKnownPlace, isFalse);
    expect(plan.days[1].stopLabel, 'Parada aproximada na rota');
    expect(plan.days.last.stopLabel, 'Destino final');
  });
}
