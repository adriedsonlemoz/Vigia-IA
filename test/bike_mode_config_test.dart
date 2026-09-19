import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/bike_mode_config.dart';

void main() {
  test('Modo Bike usa Economia como perfil padrão', () {
    const config = BikeModeConfig();
    expect(config.enabled, isFalse);
    expect(config.powerProfile, BikePowerProfile.economy);
    expect(config.keepRemoteTelemetry, isTrue);
  });

  test('configuração do Modo Bike serializa e restaura', () {
    const original = BikeModeConfig(
      enabled: true,
      powerProfile: BikePowerProfile.extremeEconomy,
      lowBatteryPercent: 15,
    );
    final restored = BikeModeConfig.fromJson(original.toJson());
    expect(restored.enabled, isTrue);
    expect(restored.powerProfile, BikePowerProfile.extremeEconomy);
    expect(restored.lowBatteryPercent, 15);
  });

  test('limite de bateria fica em faixa segura', () {
    expect(const BikeModeConfig().copyWith(lowBatteryPercent: 1).lowBatteryPercent, 5);
    expect(const BikeModeConfig().copyWith(lowBatteryPercent: 99).lowBatteryPercent, 50);
  });
}
