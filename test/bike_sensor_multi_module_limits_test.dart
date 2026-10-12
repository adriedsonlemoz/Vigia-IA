import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/bike_sensor_snapshot.dart';

void main() {
  BikeSensorSnapshot reading({
    double front = 42,
    double rear = 42,
    double defaultLimit = 30,
    double? frontLimit,
    double? rearLimit,
    bool frontAvailable = true,
    bool rearAvailable = true,
  }) => BikeSensorSnapshot(
        capturedAt: DateTime(2026, 10, 12),
        source: BikeSensorSource.esp32,
        connected: true,
        speedKmh: 0,
        frontTirePsi: front,
        rearTirePsi: rear,
        sensorBatteryPercent: 80,
        tripDistanceKm: 0,
        minimumTirePressurePsi: defaultLimit,
        frontMinimumTirePressurePsi: frontLimit,
        rearMinimumTirePressurePsi: rearLimit,
        frontTirePressureAvailable: frontAvailable,
        rearTirePressureAvailable: rearAvailable,
      );

  test('limite dianteiro de um modulo nao gera falso alerta traseiro', () {
    final value = reading(
      front: 44,
      rear: 32,
      defaultLimit: 42,
      frontLimit: 42,
      rearLimit: 28,
    );
    expect(value.effectiveFrontMinimumPsi, 42);
    expect(value.effectiveRearMinimumPsi, 28);
    expect(value.health, BikeSensorHealth.normal);
    expect(value.primaryWarning, isNull);
  });

  test('cada pneu respeita seu limite e criticidade independente', () {
    final value = reading(
      front: 36,
      rear: 26,
      frontLimit: 42,
      rearLimit: 28,
    );
    expect(value.frontCriticalTirePressurePsi, 36);
    expect(value.rearCriticalTirePressurePsi, 22);
    expect(value.health, BikeSensorHealth.critical);
    expect(value.primaryWarning, contains('DIANTEIRA'));
  });

  test('campos opcionais preservam comportamento de modulo unico', () {
    final value = reading(front: 29, rear: 32);
    expect(value.effectiveFrontMinimumPsi, 30);
    expect(value.effectiveRearMinimumPsi, 30);
    expect(value.health, BikeSensorHealth.warning);
  });

  test('pneu sem sensor nao dispara alerta por valor zero', () {
    final value = reading(
      front: 0,
      rear: 38,
      frontLimit: 50,
      rearLimit: 30,
      frontAvailable: false,
    );
    expect(value.primaryWarning, isNull);
    expect(value.health, BikeSensorHealth.normal);
  });

  test('campo diagnostico identifica o limite de cada pneu', () {
    final value = reading(frontLimit: 40, rearLimit: 25);
    final json = value.toJson();
    expect(json['frontMinimumTirePressurePsi'], 40);
    expect(json['rearMinimumTirePressurePsi'], 25);
  });
}
