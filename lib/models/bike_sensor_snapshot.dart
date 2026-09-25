import 'dart:math' as math;

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
    this.moduleId,
    this.minimumTirePressurePsi = 30,
    this.maximumTemperatureC = 65,
    this.speedAvailable = true,
    this.tirePressureAvailable = true,
    this.frontTirePressureAvailable = true,
    this.rearTirePressureAvailable = true,
    this.batteryAvailable = true,
    this.temperatureAvailable = true,
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
  final String? moduleId;
  final double minimumTirePressurePsi;
  final double maximumTemperatureC;
  final bool speedAvailable;
  final bool tirePressureAvailable;
  final bool frontTirePressureAvailable;
  final bool rearTirePressureAvailable;
  final bool batteryAvailable;
  final bool temperatureAvailable;

  double get criticalTirePressurePsi =>
      math.max(1, minimumTirePressurePsi - 6).toDouble();

  double get criticalTemperatureC => maximumTemperatureC + 10;

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
        'moduleId': moduleId,
        'minimumTirePressurePsi': minimumTirePressurePsi,
        'maximumTemperatureC': maximumTemperatureC,
        'speedAvailable': speedAvailable,
        'tirePressureAvailable': tirePressureAvailable,
        'frontTirePressureAvailable': frontTirePressureAvailable,
        'rearTirePressureAvailable': rearTirePressureAvailable,
        'batteryAvailable': batteryAvailable,
        'temperatureAvailable': temperatureAvailable,
      };

  factory BikeSensorSnapshot.fromEsp32Json(
    Map<String, dynamic> json, {
    DateTime? receivedAt,
    String? moduleId,
    double minimumTirePressurePsi = 30,
    double maximumTemperatureC = 65,
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
      moduleId: moduleId ?? json['moduleId'] as String?,
      minimumTirePressurePsi: minimumTirePressurePsi.clamp(1, 150).toDouble(),
      maximumTemperatureC: maximumTemperatureC.clamp(-40, 125).toDouble(),
      speedAvailable: json['speedKmh'] is num,
      tirePressureAvailable:
          json['frontTirePsi'] is num || json['rearTirePsi'] is num,
      frontTirePressureAvailable: json['frontTirePsi'] is num,
      rearTirePressureAvailable: json['rearTirePsi'] is num,
      batteryAvailable: json['batteryPercent'] is num,
      temperatureAvailable: json['temperatureC'] is num,
    );
  }

  bool get simulated => source == BikeSensorSource.simulator;

  BikeSensorHealth get health {
    if (!connected) return BikeSensorHealth.disconnected;
    final temperature = ambientTemperatureC;
    if ((frontTirePressureAvailable &&
            frontTirePsi <= criticalTirePressurePsi) ||
        (rearTirePressureAvailable &&
            rearTirePsi <= criticalTirePressurePsi) ||
        (batteryAvailable && sensorBatteryPercent <= 5) ||
        (temperatureAvailable &&
            temperature != null &&
            temperature >= criticalTemperatureC)) {
      return BikeSensorHealth.critical;
    }
    if ((frontTirePressureAvailable &&
            frontTirePsi < minimumTirePressurePsi) ||
        (rearTirePressureAvailable &&
            rearTirePsi < minimumTirePressurePsi) ||
        (batteryAvailable && sensorBatteryPercent <= 15) ||
        (temperatureAvailable &&
            temperature != null &&
            temperature >= maximumTemperatureC)) {
      return BikeSensorHealth.warning;
    }
    return BikeSensorHealth.normal;
  }

  String? get primaryWarning {
    if (!connected) return 'Sensores da bike sem conexão';
    if (frontTirePressureAvailable &&
        frontTirePsi <= criticalTirePressurePsi) {
      return 'PRESSÃO DIANTEIRA BAIXA • ${frontTirePsi.toStringAsFixed(0)} PSI';
    }
    if (rearTirePressureAvailable &&
        rearTirePsi <= criticalTirePressurePsi) {
      return 'PRESSÃO TRASEIRA BAIXA • ${rearTirePsi.toStringAsFixed(0)} PSI';
    }
    if (frontTirePressureAvailable &&
        frontTirePsi < minimumTirePressurePsi) {
      return 'Atenção no pneu dianteiro • ${frontTirePsi.toStringAsFixed(0)} PSI';
    }
    if (rearTirePressureAvailable &&
        rearTirePsi < minimumTirePressurePsi) {
      return 'Atenção no pneu traseiro • ${rearTirePsi.toStringAsFixed(0)} PSI';
    }
    if (batteryAvailable && sensorBatteryPercent <= 5) {
      return 'Bateria dos sensores crítica • $sensorBatteryPercent%';
    }
    if (batteryAvailable && sensorBatteryPercent <= 15) {
      return 'Bateria dos sensores baixa • $sensorBatteryPercent%';
    }
    final temperature = ambientTemperatureC;
    if (temperatureAvailable &&
        temperature != null &&
        temperature >= criticalTemperatureC) {
      return 'TEMPERATURA CRÍTICA • ${temperature.toStringAsFixed(0)} °C';
    }
    if (temperatureAvailable &&
        temperature != null &&
        temperature >= maximumTemperatureC) {
      return 'Temperatura alta • ${temperature.toStringAsFixed(0)} °C';
    }
    return null;
  }
}
