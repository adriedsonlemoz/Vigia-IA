import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/background_monitor_service.dart';

void main() {
  test('BackgroundMonitorStatus converte payload nativo com heartbeat e leases', () {
    final status = BackgroundMonitorStatus.fromMap(<Object?, Object?>{
      'running': true,
      'usesCamera': true,
      'screenInteractive': false,
      'statusText': 'Monitoramento ativo',
      'startedAtElapsedRealtime': 12345,
      'flutterHeartbeatFresh': true,
      'lastFlutterHeartbeatElapsedRealtime': 12999,
      'leaseCount': 2,
    });

    expect(status.running, isTrue);
    expect(status.usesCamera, isTrue);
    expect(status.screenInteractive, isFalse);
    expect(status.statusText, 'Monitoramento ativo');
    expect(status.startedAtElapsedRealtime, 12345);
    expect(status.flutterHeartbeatFresh, isTrue);
    expect(status.lastFlutterHeartbeatElapsedRealtime, 12999);
    expect(status.leaseCount, 2);
  });

  test('BackgroundMonitorStatus usa defaults seguros para payload incompleto', () {
    final status = BackgroundMonitorStatus.fromMap(const <Object?, Object?>{});
    expect(status.running, isFalse);
    expect(status.usesCamera, isFalse);
    expect(status.screenInteractive, isTrue);
    expect(status.statusText, isEmpty);
    expect(status.startedAtElapsedRealtime, 0);
    expect(status.flutterHeartbeatFresh, isFalse);
    expect(status.lastFlutterHeartbeatElapsedRealtime, 0);
    expect(status.leaseCount, 0);
  });
}
