import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/map_connectivity_service.dart';

void main() {
  test('offline economiza consultas e volta ao intervalo rapido ao reconectar', () async {
    var online = true;
    final service = MapConnectivityService(
      probe: () async => online,
      probeInterval: const Duration(seconds: 15),
      offlineProbeInterval: const Duration(seconds: 60),
    );
    await service.checkNow(force: true);
    expect(service.currentPollingInterval, const Duration(seconds: 15));
    online = false;
    await service.checkNow(force: true);
    await service.checkNow(force: true);
    expect(service.currentPollingInterval, const Duration(seconds: 60));
    online = true;
    await service.checkNow(force: true);
    expect(service.currentPollingInterval, const Duration(seconds: 15));
    service.dispose();
  });
}
