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
}
