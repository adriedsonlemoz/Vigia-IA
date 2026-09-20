enum BikeSensorSource { simulator, esp32 }

enum BikeSensorHealth { normal, warning, critical, disconnected }

class BikeSensorSnapshot {
  const BikeSensorSnapshot({
    required this.capturedAt,
    required this.source,
    required this.connected,
    required this.speedKmh,
    required this.frontTirePsi,
    required this.rearTirePsi,
    required this.sensorBatteryPercent,
    required this.tripDistanceKm,
    this.ambientTemperatureC,
  });

  final DateTime capturedAt;
  final BikeSensorSource source;
  final bool connected;
  final double speedKmh;
  final double frontTirePsi;
  final double rearTirePsi;
  final int sensorBatteryPercent;
  final double tripDistanceKm;
  final double? ambientTemperatureC;

  bool get simulated => source == BikeSensorSource.simulator;

  BikeSensorHealth get health {
    if (!connected) return BikeSensorHealth.disconnected;
    if (frontTirePsi < 28 || rearTirePsi < 28 || sensorBatteryPercent <= 5) {
      return BikeSensorHealth.critical;
    }
    if (frontTirePsi < 34 || rearTirePsi < 34 || sensorBatteryPercent <= 15) {
      return BikeSensorHealth.warning;
    }
    return BikeSensorHealth.normal;
  }

  String? get primaryWarning {
    if (!connected) return 'Sensores da bike sem conexão';
    if (frontTirePsi < 28) {
      return 'PRESSÃO DIANTEIRA BAIXA • ${frontTirePsi.toStringAsFixed(0)} PSI';
    }
    if (rearTirePsi < 28) {
      return 'PRESSÃO TRASEIRA BAIXA • ${rearTirePsi.toStringAsFixed(0)} PSI';
    }
    if (frontTirePsi < 34) {
      return 'Atenção no pneu dianteiro • ${frontTirePsi.toStringAsFixed(0)} PSI';
    }
    if (rearTirePsi < 34) {
      return 'Atenção no pneu traseiro • ${rearTirePsi.toStringAsFixed(0)} PSI';
    }
    if (sensorBatteryPercent <= 5) {
      return 'Bateria dos sensores crítica • $sensorBatteryPercent%';
    }
    if (sensorBatteryPercent <= 15) {
      return 'Bateria dos sensores baixa • $sensorBatteryPercent%';
    }
    return null;
  }
}
