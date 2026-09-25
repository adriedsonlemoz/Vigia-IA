import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/route_explorer_models.dart';
import 'package:vigiaia/services/map_gps_filter.dart';
import 'package:vigiaia/services/map_route_service.dart';
import 'package:vigiaia/services/route_explorer_service.dart';

void main() {
  test('percurso separa saltos grandes e filtra GPS antes de gravar', () {
    expect(MapRouteService.maximumContinuousStepMeters, 250);
    expect(MapRouteService.persistenceSchema, 3);
    expect(MapGpsFilter.maximumAcceptedAccuracyMeters, 60);
    expect(MapGpsFilter.maximumRecordingAccuracyMeters, 35);
    expect(MapGpsFilter.maximumPlausibleSpeedMetersPerSecond, 70);
  });

  test('explorador mantém contexto ampliado e atualização com parcimônia', () {
    expect(RouteExplorerService.maximumResults, 36);
    expect(
      RouteExplorerService.automaticRefreshInterval,
      const Duration(minutes: 5),
    );
    expect(RouteExplorerService.automaticRefreshDistanceMeters, 1500);
  });

  test('configuração padrão do mapa prioriza viagem e pontos essenciais', () {
    const settings = RouteExplorerSettings();

    expect(settings.radiusKm, 20);
    expect(settings.searchAheadWhenMoving, isTrue);
    expect(settings.alertsEnabled, isTrue);
    expect(
      settings.categories,
      containsAll(<RouteExplorerCategory>[
        RouteExplorerCategory.fuel,
        RouteExplorerCategory.restaurant,
        RouteExplorerCategory.stop,
        RouteExplorerCategory.water,
      ]),
    );
  });
}
