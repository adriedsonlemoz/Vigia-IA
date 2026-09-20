import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/bike_mode_config.dart';

void main() {
  test('Modo Bike usa Economia como perfil padrão', () {
    const config = BikeModeConfig();
    expect(config.enabled, isFalse);
    expect(config.powerProfile, BikePowerProfile.economy);
    expect(config.keepRemoteTelemetry, isTrue);
    expect(config.sensorSimulationEnabled, isFalse);
    expect(config.simulationScenario, BikeSimulationScenario.normal);
  });

  test('configuração do Modo Bike serializa e restaura', () {
    const original = BikeModeConfig(
      enabled: true,
      powerProfile: BikePowerProfile.extremeEconomy,
      lowBatteryPercent: 15,
      sensorSimulationEnabled: true,
      simulationScenario: BikeSimulationScenario.rearTireLow,
    );
    final restored = BikeModeConfig.fromJson(original.toJson());
    expect(restored.enabled, isTrue);
    expect(restored.powerProfile, BikePowerProfile.extremeEconomy);
    expect(restored.lowBatteryPercent, 15);
    expect(restored.sensorSimulationEnabled, isTrue);
    expect(restored.simulationScenario, BikeSimulationScenario.rearTireLow);
  });

  test('limite de bateria fica em faixa segura', () {
    expect(const BikeModeConfig().copyWith(lowBatteryPercent: 1).lowBatteryPercent, 5);
    expect(const BikeModeConfig().copyWith(lowBatteryPercent: 99).lowBatteryPercent, 50);
  });

  test('perfil econômico limita análise, stream, JPEG e brilho', () {
    const config = BikeModeConfig(
      enabled: true,
      powerProfile: BikePowerProfile.economy,
    );
    expect(
      config.effectiveAnalysisInterval(const Duration(milliseconds: 250)),
      const Duration(milliseconds: 650),
    );
    expect(
      config.effectiveAnalysisInterval(const Duration(milliseconds: 900)),
      const Duration(milliseconds: 900),
    );
    expect(config.streamFpsCap, 6);
    expect(config.powerProfile.targetJpegWidth, 720);
    expect(config.powerProfile.targetJpegQuality, 68);
    expect(config.rearScreenBrightness, 0.035);
  });

  test('modo desativado não altera intervalo, FPS nem brilho', () {
    const config = BikeModeConfig(enabled: false);
    expect(
      config.effectiveAnalysisInterval(const Duration(milliseconds: 250)),
      const Duration(milliseconds: 250),
    );
    expect(config.streamFpsCap, isNull);
    expect(config.rearScreenBrightness, isNull);
  });

}
