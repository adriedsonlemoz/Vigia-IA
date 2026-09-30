import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/map_connectivity_status.dart';
import 'package:vigiaia/services/map_connectivity_service.dart';

void main() {
  test('primeira falha parte do estado desconhecido para offline', () async {
    final service = MapConnectivityService(probe: () async => false);
    final state = await service.checkNow(force: true);
    expect(state, MapConnectivityState.offline);
  });

  test('uma falha isolada nao derruba uma conexao previamente online', () async {
    var online = true;
    final service = MapConnectivityService(
      probe: () async => online,
      failuresBeforeOffline: 2,
    );
    await service.checkNow(force: true);
    expect(service.state, MapConnectivityState.online);

    online = false;
    await service.checkNow(force: true);
    expect(service.state, MapConnectivityState.online);
    await service.checkNow(force: true);
    expect(service.state, MapConnectivityState.offline);
  });

  test('uma resposta positiva recupera o estado offline', () async {
    var online = false;
    final service = MapConnectivityService(probe: () async => online);
    await service.checkNow(force: true);
    expect(service.state, MapConnectivityState.offline);

    online = true;
    await service.checkNow(force: true);
    expect(service.state, MapConnectivityState.online);
  });
}
