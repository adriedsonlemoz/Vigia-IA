class DeviceTelemetrySnapshot {
  const DeviceTelemetrySnapshot({
    required this.createdAt,
    this.batteryPercent,
    this.batteryCharging,
    this.batteryPowerSource,
    this.batteryCurrentMa,
    this.batteryTemperatureC,
    this.screenBrightnessPercent,
    this.automaticBrightness,
    this.screenInteractive,
    this.screenDimmedByBike = false,
    this.appCpuPercent,
    this.processorCount,
    this.appMemoryUsedBytes,
    this.memoryAvailableBytes,
    this.memoryTotalBytes,
    this.freeStorageBytes,
    this.totalStorageBytes,
  });

  final DateTime createdAt;
  final int? batteryPercent;
  final bool? batteryCharging;
  final String? batteryPowerSource;
  final double? batteryCurrentMa;
  final double? batteryTemperatureC;
  final int? screenBrightnessPercent;
  final bool? automaticBrightness;
  final bool? screenInteractive;
  final bool screenDimmedByBike;
  final double? appCpuPercent;
  final int? processorCount;
  final int? appMemoryUsedBytes;
  final int? memoryAvailableBytes;
  final int? memoryTotalBytes;
  final int? freeStorageBytes;
  final int? totalStorageBytes;

  factory DeviceTelemetrySnapshot.fromMap(Map<Object?, Object?> map) =>
      DeviceTelemetrySnapshot._fromMap(map, createdAt: DateTime.now());

  factory DeviceTelemetrySnapshot.fromJson(Map<String, dynamic> json) =>
      DeviceTelemetrySnapshot._fromMap(
        json,
        createdAt: DateTime.tryParse(json['capturedAt'] as String? ?? '') ?? DateTime.now(),
      );

  factory DeviceTelemetrySnapshot._fromMap(
    Map<Object?, Object?> map, {
    required DateTime createdAt,
  }) {
    int? integer(String key) => (map[key] as num?)?.toInt();
    double? decimal(String key) => (map[key] as num?)?.toDouble();
    return DeviceTelemetrySnapshot(
      createdAt: createdAt,
      batteryPercent: integer('batteryPercent'),
      batteryCharging: map['batteryCharging'] as bool?,
      batteryPowerSource: map['batteryPowerSource'] as String?,
      batteryCurrentMa: decimal('batteryCurrentMa'),
      batteryTemperatureC: decimal('batteryTemperatureC'),
      screenBrightnessPercent: integer('screenBrightnessPercent'),
      automaticBrightness: map['automaticBrightness'] as bool?,
      screenInteractive: map['screenInteractive'] as bool?,
      screenDimmedByBike: map['screenDimmedByBike'] as bool? ?? false,
      appCpuPercent: decimal('appCpuPercent'),
      processorCount: integer('processorCount'),
      appMemoryUsedBytes: integer('memoryUsedBytes'),
      memoryAvailableBytes: integer('memoryAvailableBytes'),
      memoryTotalBytes: integer('memoryTotalBytes'),
      freeStorageBytes: integer('freeStorageBytes'),
      totalStorageBytes: integer('totalStorageBytes'),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'capturedAt': createdAt.toIso8601String(),
        'batteryPercent': batteryPercent,
        'batteryCharging': batteryCharging,
        'batteryPowerSource': batteryPowerSource,
        'batteryCurrentMa': batteryCurrentMa,
        'batteryTemperatureC': batteryTemperatureC,
        'screenBrightnessPercent': screenBrightnessPercent,
        'automaticBrightness': automaticBrightness,
        'screenInteractive': screenInteractive,
        'screenDimmedByBike': screenDimmedByBike,
        'appCpuPercent': appCpuPercent,
        'processorCount': processorCount,
        'memoryUsedBytes': appMemoryUsedBytes,
        'memoryAvailableBytes': memoryAvailableBytes,
        'memoryTotalBytes': memoryTotalBytes,
        'freeStorageBytes': freeStorageBytes,
        'totalStorageBytes': totalStorageBytes,
      };
}
