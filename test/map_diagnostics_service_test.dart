import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/map_diagnostics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('diagnóstico MBTiles registra só contagens e nenhum caminho ou GPS', () async {
    final service = MapDiagnosticsService.instance;
    final before = await service.capture();
    service.recordOfflineOpenFailure();
    final after = await service.capture();
    expect(after['offlineOpenErrors'], (before['offlineOpenErrors'] as int) + 1);
    expect(after['lastOfflineOpenErrorAt'], isNotNull);
    expect(after.containsKey('latitude'), isFalse);
    expect(after.containsKey('longitude'), isFalse);
    expect(after.containsKey('path'), isFalse);
    expect(after['gpsUpdatesPerMinute'], isA<int>());
  });
}
