import 'package:vigiaia/services/background_monitor_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BackgroundMonitorStatus converte payload nativo com segurança', () {
    final status = BackgroundMonitorStatus.fromMap(<Object?, Object?>{
      'running': true,
      'usesCamera': true,
      'screenInteractive': false,
      'statusText': 'Monitoramento ativo',
      'startedAtElapsedRealtime': 12345,
    });

    expect(status.running, isTrue);
    expect(status.usesCamera, isTrue);
    expect(status.screenInteractive, isFalse);
    expect(status.statusText, 'Monitoramento ativo');
    expect(status.startedAtElapsedRealtime, 12345);
  });

  test('BackgroundMonitorStatus usa defaults seguros para payload incompleto', () {
    final status = BackgroundMonitorStatus.fromMap(const <Object?, Object?>{});
    expect(status.running, isFalse);
    expect(status.usesCamera, isFalse);
    expect(status.screenInteractive, isTrue);
    expect(status.statusText, isEmpty);
    expect(status.startedAtElapsedRealtime, 0);
  });
}
