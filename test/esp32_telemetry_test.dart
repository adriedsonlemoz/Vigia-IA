import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/esp32_module.dart';
import 'package:vigiaia/models/esp32_telemetry.dart';

void main() {
  test('parser aceita protocolo v1 estruturado e extrai telemetria da bike', () {
    final packet = Esp32TelemetryPacket.fromJson(
      <String, dynamic>{
        'moduleId': 'rear-bike',
        'protocolVersion': 1,
        'firmwareVersion': '1.2.0',
        'sequence': 44,
        'uptimeMs': 123456,
        'capabilities': <String>[
          'hallSpeed',
          'tirePressure',
          'temperature',
        ],
        'wifi': <String, dynamic>{'rssiDbm': -61},
        'power': <String, dynamic>{
          'batteryPercent': 73,
          'voltageV': 4.08,
          'charging': true,
        },
        'sensors': <String, dynamic>{
          'hall': <String, dynamic>{
            'speedKmh': 28.4,
            'tripDistanceKm': 14.2,
          },
          'tirePressure': <String, dynamic>{
            'frontPsi': 41.0,
            'rearPsi': 44.0,
          },
          'temperatureC': 29.5,
        },
      },
      fallbackModuleId: 'fallback',
      receivedAt: DateTime(2026, 9, 24, 22, 30),
    );

    expect(packet.moduleId, 'rear-bike');
    expect(packet.protocolVersion, 1);
    expect(packet.firmwareVersion, '1.2.0');
    expect(packet.rssiDbm, -61);
    expect(packet.batteryPercent, 73);
    expect(packet.batteryVoltage, 4.08);
    expect(packet.charging, isTrue);
    expect(packet.hasBikeTelemetry, isTrue);
    expect(packet.bikePayload['speedKmh'], 28.4);
    expect(packet.bikePayload['frontTirePsi'], 41.0);
    expect(packet.bikePayload['rearTirePsi'], 44.0);
    expect(packet.bikePayload['temperatureC'], 29.5);
    expect(packet.reportedCapabilities, contains(Esp32Capability.hallSpeed));
  });

  test('parser aceita status legado com bikeSensors', () {
    final packet = Esp32TelemetryPacket.fromJson(
      <String, dynamic>{
        'bikeSensors': <String, dynamic>{
          'connected': true,
          'speedKmh': 19.7,
          'frontTirePsi': 39,
          'rearTirePsi': 42,
          'batteryPercent': 81,
          'temperatureC': 26.2,
        },
      },
      fallbackModuleId: 'legacy',
    );

    expect(packet.moduleId, 'legacy');
    expect(packet.hasBikeTelemetry, isTrue);
    expect(packet.bikePayload['speedKmh'], 19.7);
    expect(packet.bikePayload['batteryPercent'], 81);
  });

  test('qualidade do Wi-Fi usa faixas de RSSI', () {
    Esp32TelemetryPacket packet(int rssi) => Esp32TelemetryPacket.fromJson(
          <String, dynamic>{'rssiDbm': rssi},
          fallbackModuleId: 'wifi',
        );

    expect(packet(-50).wifiQualityLabel, contains('excelente'));
    expect(packet(-64).wifiQualityLabel, contains('bom'));
    expect(packet(-72).wifiQualityLabel, contains('regular'));
    expect(packet(-85).wifiQualityLabel, contains('fraco'));
  });

  test('parser aceita booleanos numericos e uptime legado em segundos', () {
    final packet = Esp32TelemetryPacket.fromJson(
      <String, dynamic>{
        'moduleId': 'front-bike',
        'connected': 1,
        'uptime': 42,
        'power': <String, dynamic>{'externalPower': 1},
      },
      fallbackModuleId: 'fallback',
    );

    expect(packet.connected, isTrue);
    expect(packet.charging, isTrue);
    expect(packet.uptime, const Duration(seconds: 42));
  });


test('parser extrai bateria principal corrente e entrada solar', () {
  final packet = Esp32TelemetryPacket.fromJson(
    <String, dynamic>{
      'moduleId': 'energy-pack',
      'capabilities': <String>['energy'],
      'power': <String, dynamic>{
        'source': 'usbPowerBank',
        'monitor': <String, dynamic>{'model': 'INA226'},
        'battery': <String, dynamic>{
          'present': true,
          'chemistry': 'leadAcid',
          'percent': 74,
          'voltageV': 12.62,
          'currentA': -1.35,
          'temperatureC': 28.4,
        },
        'solar': <String, dynamic>{
          'voltageV': 18.2,
          'currentA': 0.42,
          'powerW': 7.64,
        },
      },
    },
    fallbackModuleId: 'fallback',
  );

  expect(packet.reportedCapabilities, contains(Esp32Capability.energy));
  expect(packet.energy, isNotNull);
  expect(packet.energy!.sourceType, 'usbPowerBank');
  expect(packet.energy!.monitorType, 'INA226');
  expect(packet.energy!.batteryChemistry, 'leadAcid');
  expect(packet.energy!.voltageV, 12.62);
  expect(packet.energy!.currentA, -1.35);
  expect(packet.energy!.powerW, closeTo(-17.037, 0.001));
  expect(packet.energy!.solarPowerW, 7.64);
  expect(packet.energy!.batteryTemperatureC, 28.4);
});

  test('bateria principal nao sobrescreve bateria do modulo', () {
    final packet = Esp32TelemetryPacket.fromJson(
      <String, dynamic>{
        'batteryPercent': 88,
        'batteryVoltage': 4.07,
        'power': <String, dynamic>{
          'battery': <String, dynamic>{
            'percent': 31,
            'voltageV': 12.18,
            'currentA': -0.8,
          },
        },
      },
      fallbackModuleId: 'separate-power',
    );

    expect(packet.batteryPercent, 88);
    expect(packet.batteryVoltage, 4.07);
    expect(packet.energy!.batteryPercent, 31);
    expect(packet.energy!.voltageV, 12.18);
    expect(packet.bikePayload['batteryPercent'], 88);
  });

}
