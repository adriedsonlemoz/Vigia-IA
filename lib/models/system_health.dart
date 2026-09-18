class SystemHealthSnapshot {
  const SystemHealthSnapshot({
    required this.createdAt,
    this.source = 'Parado',
    this.aiReady = false,
    this.fps = 0,
    this.batteryPercent,
    this.batteryTemperatureC,
    this.freeStorageMb,
    this.totalStorageMb,
    this.memoryUsedMb,
    this.backgroundActive = false,
    this.recentErrors = 0,
  });

  final DateTime createdAt;
  final String source;
  final bool aiReady;
  final double fps;
  final int? batteryPercent;
  final double? batteryTemperatureC;
  final int? freeStorageMb;
  final int? totalStorageMb;
  final int? memoryUsedMb;
  final bool backgroundActive;
  final int recentErrors;
}
