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

  Map<String, Object?> toJson() => <String, Object?>{
        'capturedAt': capturedAt.toUtc().toIso8601String(),
        'source': source.name,
        'connected': connected,
        'speedKmh': speedKmh,
        'frontTirePsi': frontTirePsi,
        'rearTirePsi': rearTirePsi,
        'batteryPercent': sensorBatteryPercent,
        'tripDistanceKm': tripDistanceKm,
        'temperatureC': ambientTemperatureC,
      };

  factory BikeSensorSnapshot.fromEsp32Json(
    Map<String, dynamic> json, {
    DateTime? receivedAt,
  }) {
    double number(String key, [double fallback = 0]) =>
        (json[key] as num?)?.toDouble() ?? fallback;
    final capturedAt = DateTime.tryParse(json['capturedAt'] as String? ?? '') ??
        receivedAt ??
        DateTime.now();
    final sourceName = json['source'] as String?;
    final source = BikeSensorSource.values.firstWhere(
      (value) => value.name == sourceName,
      orElse: () => BikeSensorSource.esp32,
    );
    return BikeSensorSnapshot(
      capturedAt: capturedAt,
      source: source,
      connected: json['connected'] as bool? ?? true,
      speedKmh: number('speedKmh').clamp(0, 180).toDouble(),
      frontTirePsi: number('frontTirePsi').clamp(0, 150).toDouble(),
      rearTirePsi: number('rearTirePsi').clamp(0, 150).toDouble(),
      sensorBatteryPercent:
          ((json['batteryPercent'] as num?)?.toInt() ?? 0).clamp(0, 100).toInt(),
      tripDistanceKm: number('tripDistanceKm').clamp(0, 999999).toDouble(),
      ambientTemperatureC: json['temperatureC'] is num
          ? (json['temperatureC'] as num).toDouble().clamp(-40, 125).toDouble()
          : null,
    );
  }

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
