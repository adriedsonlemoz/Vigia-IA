import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/minha_camera_telemetry.dart';

void main() {
  test('interpreta porcentagem e décimos de graus do MCRP', () {
    final status = MinhaCameraTelemetry.fromHeaders({
      'x-battery-level': '64',
      'x-battery-temp-tenths': '410',
      'x-device-model': 'Redmi A3',
      'x-resolution': '1280x720',
      'x-fps-target': '15',
    });
    expect(status.device!.batteryPercent, 64);
    expect(status.device!.batteryTemperatureC, 41.0);
    expect(status.device!.deviceModel, 'Redmi A3');
    expect(status.videoWidth, 1280);
    expect(status.videoHeight, 720);
    expect(status.cameraFps, 15);
  });

  test('não inventa telemetria em cabeçalhos ausentes ou inválidos', () {
    for (final headers in <Map<String, String>>[
      {},
      {'x-battery-level': '500', 'x-battery-temp-tenths': 'abc'},
    ]) {
      final status = MinhaCameraTelemetry.fromHeaders(headers);
      expect(status.device?.batteryPercent, isNull);
      expect(status.device?.batteryTemperatureC, isNull);
    }
  });

  test('aceita bateria vazia e temperatura abaixo de zero', () {
    final status = MinhaCameraTelemetry.fromHeaders({
      'x-battery-level': '0',
      'x-battery-temp-tenths': '-45',
    });
    expect(status.device!.batteryPercent, 0);
    expect(status.device!.batteryTemperatureC, -4.5);
  });
}
