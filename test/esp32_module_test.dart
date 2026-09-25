import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/camera_endpoint.dart';
import 'package:vigiaia/models/esp32_module.dart';

void main() {
  test('modulo ESP32 separa capacidades da camera', () {
    const module = Esp32Module(
      id: 'rear',
      name: 'ESP32 traseiro',
      address: 'http://192.168.4.1',
      position: Esp32ModulePosition.rear,
      capabilities: <Esp32Capability>{
        Esp32Capability.hallSpeed,
        Esp32Capability.temperature,
        Esp32Capability.mmWave,
      },
    );

    expect(module.positionLabel, 'Traseiro');
    expect(module.cameraEnabled, isFalse);
    expect(module.supports(Esp32Capability.mmWave), isTrue);
    expect(module.toConfigurationJson()['protocolVersion'], 1);
  });

  test('camera vira apenas uma capacidade do modulo', () {
    const module = Esp32Module(
      id: 'front',
      name: 'ESP32 dianteiro',
      capabilities: <Esp32Capability>{
        Esp32Capability.camera,
        Esp32Capability.battery,
      },
    );

    final camera = module.toCameraEndpoint();
    expect(camera.type, CameraEndpointType.esp32);
    expect(camera.esp32CameraEnabled, isTrue);
    expect(camera.id, module.id);
  });

  test('cadastro legado de ESP32 migra sem perder sensores', () {
    const legacy = CameraEndpoint(
      id: 'legacy',
      name: 'ESP32 antigo',
      type: CameraEndpointType.esp32,
      esp32CameraEnabled: true,
      temperatureSensorEnabled: true,
      hallSensorEnabled: false,
      tirePressureEnabled: true,
      telemetryIntervalMs: 5000,
    );

    final module = Esp32Module.fromLegacyCameraEndpoint(legacy);
    expect(module.cameraEnabled, isTrue);
    expect(module.temperatureSensorEnabled, isTrue);
    expect(module.hallSensorEnabled, isFalse);
    expect(module.tirePressureEnabled, isTrue);
    expect(module.staleAfter, const Duration(seconds: 15));
  });

  test('serializacao preserva posicao e capacidades futuras', () {
    const original = Esp32Module(
      id: 'sensor-pack',
      name: 'Sensor pack',
      position: Esp32ModulePosition.helmet,
      capabilities: <Esp32Capability>{
        Esp32Capability.mmWave,
        Esp32Capability.thermal,
        Esp32Capability.tof,
      },
    );

    final restored = Esp32Module.fromJson(
      Map<String, dynamic>.from(original.toJson()),
    );
    expect(restored.position, Esp32ModulePosition.helmet);
    expect(restored.supports(Esp32Capability.mmWave), isTrue);
    expect(restored.supports(Esp32Capability.thermal), isTrue);
    expect(restored.supports(Esp32Capability.tof), isTrue);
  });

  test('lista vazia de capacidades permanece vazia apos recarregar', () {
    const original = Esp32Module(
      id: 'empty-pack',
      name: 'ESP32 sem sensores',
      capabilities: <Esp32Capability>{},
    );

    final restored = Esp32Module.fromJson(
      Map<String, dynamic>.from(original.toJson()),
    );
    expect(restored.capabilities, isEmpty);
  });

// Energia externa fica separada da alimentação do próprio ESP32.
test('perfil de energia suporta chumbo com ESP32 em power bank', () {
  const module = Esp32Module(
    id: 'energy-pack',
    name: 'ESP32 energia',
    capabilities: <Esp32Capability>{Esp32Capability.energy},
    powerSupplyType: Esp32PowerSupplyType.usbPowerBank,
    batteryChemistry: Esp32BatteryChemistry.leadAcid,
    powerMonitorType: Esp32PowerMonitorType.ina226,
    batteryNominalVoltageV: 12,
    batteryCapacityAh: 7,
    monitorSolarInput: true,
  );

  final config = module.toConfigurationJson();
  final energy = Map<String, Object?>.from(config['energy']! as Map);
  final battery = Map<String, Object?>.from(energy['battery']! as Map);
  expect(module.energyMonitoringEnabled, isTrue);
  expect(module.powerSupplyType, Esp32PowerSupplyType.usbPowerBank);
  expect(battery['chemistry'], 'leadAcid');
  expect(energy['monitor'], 'ina226');
  expect((energy['solar']! as Map)['enabled'], isTrue);
});

test('perfil de energia funciona sem bateria para teste em tomada', () {
  const module = Esp32Module(
    id: 'bench',
    name: 'ESP32 bancada',
    capabilities: <Esp32Capability>{Esp32Capability.energy},
    powerSupplyType: Esp32PowerSupplyType.usbAdapter,
    batteryChemistry: Esp32BatteryChemistry.none,
  );

  expect(module.externalBatteryConfigured, isFalse);
  expect(module.energyProfileLabel, contains('Tomada'));
  final restored = Esp32Module.fromJson(
    Map<String, dynamic>.from(module.toJson()),
  );
  expect(restored.powerSupplyType, Esp32PowerSupplyType.usbAdapter);
  expect(restored.batteryChemistry, Esp32BatteryChemistry.none);
});

  test('config antigo nao recebe bloco energy quando capacidade nao existe', () {
    const module = Esp32Module(
      id: 'legacy-compatible',
      name: 'ESP32 legado',
      capabilities: <Esp32Capability>{Esp32Capability.hallSpeed},
    );

    expect(module.toConfigurationJson().containsKey('energy'), isFalse);
  });

}
