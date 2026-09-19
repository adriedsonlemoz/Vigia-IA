import 'device_telemetry.dart';

enum RemotePhoneWarningLevel { attention, critical }

class RemotePhoneWarning {
  const RemotePhoneWarning({
    required this.code,
    required this.title,
    required this.detail,
    required this.level,
  });

  final String code;
  final String title;
  final String detail;
  final RemotePhoneWarningLevel level;
}

class RemotePhoneStatus {
  const RemotePhoneStatus({
    required this.receivedAt,
    required this.online,
    required this.bikeMode,
    required this.name,
    this.lastFrameAt,
    this.bikeProfile,
    this.device,
    this.alertLowBattery = true,
    this.lowBatteryPercent = 20,
    this.cameraFps,
    this.networkLatencyMs,
  });

  final DateTime receivedAt;
  final bool online;
  final DateTime? lastFrameAt;
  final bool bikeMode;
  final String? bikeProfile;
  final DeviceTelemetrySnapshot? device;
  final bool alertLowBattery;
  final int lowBatteryPercent;
  final String name;
  final double? cameraFps;
  final int? networkLatencyMs;

  factory RemotePhoneStatus.fromJson(
    Map<String, dynamic> json, {
    DateTime? receivedAt,
    int? networkLatencyMs,
  }) {
    final rawDevice = json['device'];
    return RemotePhoneStatus(
      receivedAt: receivedAt ?? DateTime.now(),
      online: json['online'] as bool? ?? json['serverActive'] as bool? ?? true,
      lastFrameAt: DateTime.tryParse(json['lastFrameAt'] as String? ?? ''),
      bikeMode: json['bikeMode'] as bool? ?? false,
      bikeProfile: json['bikeProfile'] as String?,
      device: rawDevice is Map
          ? DeviceTelemetrySnapshot.fromJson(
              Map<String, dynamic>.from(rawDevice as Map),
            )
          : null,
      alertLowBattery: json['alertLowBattery'] as bool? ?? true,
      lowBatteryPercent:
          ((json['lowBatteryPercent'] as num?)?.toInt() ?? 20).clamp(5, 50).toInt(),
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : 'Celular traseiro',
      cameraFps: (json['fps'] as num?)?.toDouble(),
      networkLatencyMs: networkLatencyMs,
    );
  }

  String get profileLabel => switch (bikeProfile) {
        'normal' => 'Normal',
        'economy' => 'Economia',
        'extremeEconomy' => 'Economia extrema',
        _ => bikeMode ? 'Ativo' : 'Desativado',
      };

  bool isStale([DateTime? now]) {
    final current = now ?? DateTime.now();
    final age = current.difference(receivedAt);
    return age.isNegative || age > const Duration(seconds: 16);
  }

  List<RemotePhoneWarning> warnings([DateTime? now]) {
    final result = <RemotePhoneWarning>[];
    if (isStale(now)) {
      result.add(
        const RemotePhoneWarning(
          code: 'telemetry_stale',
          title: 'Telemetria atrasada',
          detail: 'O celular da frente deixou de receber o estado recente do aparelho traseiro.',
          level: RemotePhoneWarningLevel.attention,
        ),
      );
    }

    final telemetry = device;
    if (telemetry == null) return result;

    final battery = telemetry.batteryPercent;
    if (alertLowBattery && battery != null && battery <= lowBatteryPercent) {
      result.add(
        RemotePhoneWarning(
          code: 'battery_low',
          title: 'Bateria traseira baixa',
          detail: telemetry.batteryCharging == true
              ? '$battery% e carregando.'
              : '$battery% restantes no celular traseiro.',
          level: battery <= 10
              ? RemotePhoneWarningLevel.critical
              : RemotePhoneWarningLevel.attention,
        ),
      );
    }

    final temperature = telemetry.batteryTemperatureC;
    if (temperature != null && temperature >= 40) {
      result.add(
        RemotePhoneWarning(
          code: 'battery_hot',
          title: temperature >= 45
              ? 'Temperatura traseira alta'
              : 'Temperatura traseira elevada',
          detail: '${temperature.toStringAsFixed(1)} °C na bateria.',
          level: temperature >= 45
              ? RemotePhoneWarningLevel.critical
              : RemotePhoneWarningLevel.attention,
        ),
      );
    }

    final cpu = telemetry.appCpuPercent;
    if (cpu != null && cpu >= 85) {
      result.add(
        RemotePhoneWarning(
          code: 'cpu_high',
          title: 'Processamento elevado',
          detail: 'Vigia IA usando ${cpu.toStringAsFixed(0)}% de CPU no aparelho traseiro.',
          level: RemotePhoneWarningLevel.attention,
        ),
      );
    }

    final available = telemetry.memoryAvailableBytes;
    final total = telemetry.memoryTotalBytes;
    if (available != null && total != null && total > 0 && available / total <= 0.10) {
      result.add(
        const RemotePhoneWarning(
          code: 'memory_low',
          title: 'Pouca memória disponível',
          detail: 'O celular traseiro está com menos de 10% da memória RAM disponível.',
          level: RemotePhoneWarningLevel.attention,
        ),
      );
    }
    return result;
  }
}
