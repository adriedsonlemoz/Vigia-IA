import 'package:vigiaia/models/camera_endpoint.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CameraEndpoint preserva nome, tipo e estado habilitado', () {
    const original = CameraEndpoint(
      id: 'garagem',
      name: 'Garagem',
      type: CameraEndpointType.remotePhone,
      address: 'http://192.168.0.20:8765',
      accessKey: 'ABC123',
      enabled: false,
    );

    final restored = CameraEndpoint.fromJson(
      original.toJson().cast<String, dynamic>(),
    );

    expect(restored.id, 'garagem');
    expect(restored.name, 'Garagem');
    expect(restored.type, CameraEndpointType.remotePhone);
    expect(restored.address, 'http://192.168.0.20:8765');
    expect(restored.accessKey, 'ABC123');
    expect(restored.enabled, isFalse);
    expect(restored.countingEnabled, isFalse);
  });

  test('contagem futura é independente e desativada por padrão', () {
    const original = CameraEndpoint(
      id: 'camera-sem-contador',
      name: 'Entrada',
      type: CameraEndpointType.local,
    );

    expect(original.countingEnabled, isFalse);
    expect(original.copyWith(name: 'Entrada 2').countingEnabled, isFalse);
    expect(original.copyWith(countingEnabled: true).countingEnabled, isTrue);
  });

  test('renomear CameraEndpoint preserva o ID estável', () {
    const original = CameraEndpoint(
      id: 'portao-principal',
      name: 'Portão',
      type: CameraEndpointType.rtsp,
      address: 'rtsp://192.168.0.10/stream',
    );

    final renamed = original.copyWith(name: 'Entrada principal');
    expect(renamed.id, 'portao-principal');
    expect(renamed.name, 'Entrada principal');
    expect(renamed.address, original.address);
  });

  test('ESP32 preserva sensores, calibração e câmera futura', () {
    const original = CameraEndpoint(
      id: 'esp32-bike',
      name: 'ESP32 dianteiro',
      type: CameraEndpointType.esp32,
      address: 'http://192.168.4.1',
      accessKey: 'CHAVE',
      esp32CameraEnabled: true,
      wheelCircumferenceMm: 2140,
      hallMagnets: 2,
      minimumTirePressurePsi: 32,
      maximumTemperatureC: 60,
      telemetryIntervalMs: 500,
    );

    final restored = CameraEndpoint.fromJson(
      original.toJson().cast<String, dynamic>(),
    );
    expect(restored.type, CameraEndpointType.esp32);
    expect(restored.esp32CameraEnabled, isTrue);
    expect(restored.wheelCircumferenceMm, 2140);
    expect(restored.hallMagnets, 2);
    expect(restored.telemetryIntervalMs, 500);
    expect(restored.toEsp32ConfigurationJson(), isNot(contains('accessKey')));
  });
}
