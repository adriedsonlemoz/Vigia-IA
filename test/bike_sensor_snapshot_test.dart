import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/bike_sensor_snapshot.dart';

void main() {
  BikeSensorSnapshot snapshot({
    bool connected = true,
    double frontPsi = 42,
    double rearPsi = 45,
    int battery = 82,
  }) =>
      BikeSensorSnapshot(
        capturedAt: DateTime(2026, 9, 20),
        source: BikeSensorSource.simulator,
        connected: connected,
        speedKmh: 24,
        frontTirePsi: frontPsi,
        rearTirePsi: rearPsi,
        sensorBatteryPercent: battery,
        tripDistanceKm: 1.2,
      );

  test('dados normais deixam HUD sem alerta', () {
    final data = snapshot();
    expect(data.simulated, isTrue);
    expect(data.health, BikeSensorHealth.normal);
    expect(data.primaryWarning, isNull);
  });

  test('pressao critica do pneu dianteiro gera alerta prioritario', () {
    final data = snapshot(frontPsi: 24);
    expect(data.health, BikeSensorHealth.critical);
    expect(data.primaryWarning, contains('DIANTEIRA BAIXA'));
    expect(data.primaryWarning, contains('24 PSI'));
  });

  test('bateria baixa dos sensores gera atencao', () {
    final data = snapshot(battery: 8);
    expect(data.health, BikeSensorHealth.warning);
    expect(data.primaryWarning, contains('Bateria dos sensores baixa'));
  });

  test('perda de conexao domina os outros estados', () {
    final data = snapshot(connected: false, frontPsi: 20, battery: 2);
    expect(data.health, BikeSensorHealth.disconnected);
    expect(data.primaryWarning, 'Sensores da bike sem conexão');
  });

  test('telemetria ESP32 converte Hall, temperatura, pneus e bateria', () {
    final data = BikeSensorSnapshot.fromEsp32Json(<String, dynamic>{
      'capturedAt': '2026-09-22T10:30:00.000Z',
      'connected': true,
      'speedKmh': 31.4,
      'temperatureC': 27.8,
      'frontTirePsi': 41.2,
      'rearTirePsi': 44.6,
      'batteryPercent': 76,
      'tripDistanceKm': 12.3,
    });

    expect(data.source, BikeSensorSource.esp32);
    expect(data.speedKmh, 31.4);
    expect(data.ambientTemperatureC, 27.8);
    expect(data.frontTirePsi, 41.2);
    expect(data.rearTirePsi, 44.6);
    expect(data.sensorBatteryPercent, 76);
    expect(data.toJson()['temperatureC'], 27.8);
  });

  test('telemetria fora do limite e normalizada antes de chegar ao HUD', () {
    final data = BikeSensorSnapshot.fromEsp32Json(<String, dynamic>{
      'speedKmh': -8,
      'temperatureC': 180,
      'frontTirePsi': -3,
      'rearTirePsi': 220,
      'batteryPercent': 130,
      'tripDistanceKm': -1,
    });

    expect(data.speedKmh, 0);
    expect(data.ambientTemperatureC, 125);
    expect(data.frontTirePsi, 0);
    expect(data.rearTirePsi, 150);
    expect(data.sensorBatteryPercent, 100);
    expect(data.tripDistanceKm, 0);
  });


  test('limites configurados pelo modulo controlam pressao e temperatura', () {
    final pressureWarning = BikeSensorSnapshot.fromEsp32Json(
      <String, dynamic>{
        'frontTirePsi': 36,
        'rearTirePsi': 42,
        'batteryPercent': 80,
        'temperatureC': 30,
      },
      minimumTirePressurePsi: 38,
      maximumTemperatureC: 60,
    );
    expect(pressureWarning.health, BikeSensorHealth.warning);
    expect(pressureWarning.primaryWarning, contains('pneu dianteiro'));

    final temperatureWarning = BikeSensorSnapshot.fromEsp32Json(
      <String, dynamic>{
        'frontTirePsi': 42,
        'rearTirePsi': 45,
        'batteryPercent': 80,
        'temperatureC': 62,
      },
      minimumTirePressurePsi: 30,
      maximumTemperatureC: 60,
    );
    expect(temperatureWarning.health, BikeSensorHealth.warning);
    expect(temperatureWarning.primaryWarning, contains('Temperatura alta'));
  });


  test('campos ausentes nao viram falso alerta de sensor', () {
    final data = BikeSensorSnapshot.fromEsp32Json(<String, dynamic>{
      'speedKmh': 18.5,
    });

    expect(data.speedAvailable, isTrue);
    expect(data.tirePressureAvailable, isFalse);
    expect(data.batteryAvailable, isFalse);
    expect(data.temperatureAvailable, isFalse);
    expect(data.health, BikeSensorHealth.normal);
    expect(data.primaryWarning, isNull);
  });


  test('um unico sensor de pneu nao gera alerta falso no outro pneu', () {
    final data = BikeSensorSnapshot.fromEsp32Json(<String, dynamic>{
      'frontTirePsi': 41,
    });

    expect(data.frontTirePressureAvailable, isTrue);
    expect(data.rearTirePressureAvailable, isFalse);
    expect(data.health, BikeSensorHealth.normal);
    expect(data.primaryWarning, isNull);
  });
}
