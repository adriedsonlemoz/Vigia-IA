import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:vigiaia/models/map_cycling_route.dart';
import 'package:vigiaia/models/map_navigation_target.dart';
import 'package:vigiaia/services/saved_bike_route_service.dart';

void main() {
  test('salvar prévia e reabrir sem rede preserva geometria', () {
    final saved = SavedBikeRoute(
      target: MapNavigationTarget(latitude: -20.4, longitude: -45.4,
        label: 'Destino', startedAt: DateTime(2026, 10, 11)),
      routes: const [MapCyclingRoute(
        points: [LatLng(-20.5, -45.5), LatLng(-20.4, -45.4)],
        distanceMeters: 20000, durationSeconds: 4000,
      )],
      selectedIndex: 0,
    );
    final restored = SavedBikeRouteService.decode(
        SavedBikeRouteService.encode(saved));
    expect(restored.routes.single.points, hasLength(2));
    expect(restored.routes.single.distanceMeters, 20000);
    expect(restored.target.label, 'Destino');
  });
  test('rota corrompida e rejeitada', () {
    expect(() => SavedBikeRouteService.decode({'schema': 1, 'routes': []}),
      throwsFormatException);
  });
}
