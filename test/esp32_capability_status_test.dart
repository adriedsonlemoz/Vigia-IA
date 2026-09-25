import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/esp32_capability_status.dart';
import 'package:vigiaia/models/esp32_module.dart';
import 'package:vigiaia/models/esp32_telemetry.dart';

void main() {
  Esp32RuntimeState runtimeFor(
    Esp32TelemetryPacket packet, {
    Esp32ConnectionState state = Esp32ConnectionState.online,
  }) => Esp32RuntimeState(
        moduleId: packet.moduleId,
        connectionState: state,
        packet: packet,
      );

  test('sensor configurado com valor aparece como lendo agora', () {
    const module = Esp32Module(
      id: 'rear',
      name: 'ESP32 traseiro',
      capabilities: <Esp32Capability>{Esp32Capability.temperature},
    );
    final packet = Esp32TelemetryPacket.fromJson(
      <String, dynamic>{
        'moduleId': 'rear',
        'temperatureC': 27.4,
      },
      fallbackModuleId: 'rear',
    );

    final items = buildEsp32CapabilityObservations(
      module,
      runtimeFor(packet),
    );
    final temperature = items.single;

    expect(temperature.capability, Esp32Capability.temperature);
    expect(temperature.activity, Esp32CapabilityActivity.live);
    expect(temperature.valueLabel, '27.4 °C');
  });

  test('capacidade anunciada sem valor fica detectada', () {
    const module = Esp32Module(
      id: 'front',
      name: 'ESP32 dianteiro',
      capabilities: <Esp32Capability>{Esp32Capability.mmWave},
    );
    final packet = Esp32TelemetryPacket.fromJson(
      <String, dynamic>{
        'moduleId': 'front',
        'capabilities': <String>['mmWave'],
      },
      fallbackModuleId: 'front',
    );

    final item = buildEsp32CapabilityObservations(
      module,
      runtimeFor(packet),
    ).single;

    expect(item.activity, Esp32CapabilityActivity.detected);
    expect(item.advertised, isTrue);
    expect(item.hasLiveReading, isFalse);
  });

  test('sensor configurado sem anuncio nem valor fica aguardando', () {
    const module = Esp32Module(
      id: 'bike',
      name: 'ESP32 Bike',
      capabilities: <Esp32Capability>{Esp32Capability.tirePressure},
    );
    final packet = Esp32TelemetryPacket.fromJson(
      <String, dynamic>{'moduleId': 'bike'},
      fallbackModuleId: 'bike',
    );

    final item = buildEsp32CapabilityObservations(
      module,
      runtimeFor(packet),
    ).single;

    expect(item.activity, Esp32CapabilityActivity.waiting);
  });

  test('sensor novo informado pelo firmware aparece como nao configurado', () {
    const module = Esp32Module(
      id: 'upgrade',
      name: 'ESP32 upgrade',
      capabilities: <Esp32Capability>{Esp32Capability.temperature},
    );
    final packet = Esp32TelemetryPacket.fromJson(
      <String, dynamic>{
        'moduleId': 'upgrade',
        'temperatureC': 26,
        'capabilities': <String>['temperature', 'tof'],
      },
      fallbackModuleId: 'upgrade',
    );

    final items = buildEsp32CapabilityObservations(
      module,
      runtimeFor(packet),
    );
    final tof = items.firstWhere(
      (item) => item.capability == Esp32Capability.tof,
    );

    expect(tof.configured, isFalse);
    expect(tof.activity, Esp32CapabilityActivity.discovered);
    expect(tof.needsAttention, isTrue);
  });

  test('firmware legado e inferido por leituras mesmo sem capabilities', () {
    const module = Esp32Module(
      id: 'legacy',
      name: 'ESP32 legado',
      capabilities: <Esp32Capability>{},
    );
    final packet = Esp32TelemetryPacket.fromJson(
      <String, dynamic>{
        'moduleId': 'legacy',
        'speedKmh': 18.5,
        'frontTirePsi': 31,
        'batteryPercent': 82,
      },
      fallbackModuleId: 'legacy',
    );

    final items = buildEsp32CapabilityObservations(
      module,
      runtimeFor(packet),
    );
    final capabilities = items.map((item) => item.capability).toSet();

    expect(capabilities, contains(Esp32Capability.hallSpeed));
    expect(capabilities, contains(Esp32Capability.tirePressure));
    expect(capabilities, contains(Esp32Capability.battery));
    expect(items.every((item) => item.activity == Esp32CapabilityActivity.discovered), isTrue);
  });

  test('sensor configurado fica offline quando telemetria cai', () {
    const module = Esp32Module(
      id: 'offline',
      name: 'ESP32 offline',
      capabilities: <Esp32Capability>{Esp32Capability.hallSpeed},
    );
    final packet = Esp32TelemetryPacket.fromJson(
      <String, dynamic>{'moduleId': 'offline', 'speedKmh': 12},
      fallbackModuleId: 'offline',
    );

    final item = buildEsp32CapabilityObservations(
      module,
      runtimeFor(packet, state: Esp32ConnectionState.offline),
    ).single;

    expect(item.activity, Esp32CapabilityActivity.offline);
  });
}
