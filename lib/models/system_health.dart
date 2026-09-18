enum SystemOperationalState { idle, healthy, attention }

class SystemHealthSnapshot {
  const SystemHealthSnapshot({
    required this.createdAt,
    this.source = 'Parado',
    this.monitoringActive = false,
    this.androidServiceActive = false,
    this.flutterHeartbeatFresh = false,
    this.androidServiceLeaseCount = 0,
    this.cameraActive = false,
    this.framesActive = false,
    this.aiReady = false,
    this.aiActive = false,
    this.lanServerActive = false,
    this.lanFramesActive = false,
    this.lanActive = false,
    this.connectedClients = 0,
    this.backgroundRequested = false,
    this.backgroundOperational = false,
    this.screenInteractive = true,
    this.cameraPermissionRequired = true,
    this.cameraPermissionGranted = false,
    this.localNetworkPermissionRequired = false,
    this.localNetworkPermissionGranted = true,
    this.notificationsAllowed = false,
    this.lastFrameAt,
    this.lanLastFrameAt,
    this.lanError,
    this.fps = 0,
    this.batteryPercent,
    this.batteryTemperatureC,
    this.freeStorageBytes,
    this.totalStorageBytes,
    this.memoryUsedBytes,
    this.recentErrors = 0,
    this.cameraHealth = CameraHealthState.unknown,
  });

  final DateTime createdAt;
  final String source;
  final bool monitoringActive;
  final bool androidServiceActive;
  final bool flutterHeartbeatFresh;
  final int androidServiceLeaseCount;
  final bool cameraActive;
  final bool framesActive;
  final bool aiReady;
  final bool aiActive;
  final bool lanServerActive;
  final bool lanFramesActive;
  /// LAN operacional: servidor ativo, JPEG recente e nenhuma falha atual.
  final bool lanActive;
  final int connectedClients;
  final bool backgroundRequested;
  final bool backgroundOperational;
  final bool screenInteractive;
  final bool cameraPermissionRequired;
  final bool cameraPermissionGranted;
  final bool localNetworkPermissionRequired;
  final bool localNetworkPermissionGranted;
  final bool notificationsAllowed;
  final DateTime? lastFrameAt;
  final DateTime? lanLastFrameAt;
  final String? lanError;
  final double fps;
  final int? batteryPercent;
  final double? batteryTemperatureC;
  final int? freeStorageBytes;
  final int? totalStorageBytes;
  final int? memoryUsedBytes;
  final int recentErrors;
  final CameraHealthState cameraHealth;

  SystemOperationalState get operationalState {
    if (!monitoringActive) return SystemOperationalState.idle;
    final cameraIntegrityOk =
        cameraHealth != CameraHealthState.obstructed &&
        cameraHealth != CameraHealthState.moved &&
        cameraHealth != CameraHealthState.offline;
    if (cameraActive && framesActive && aiActive && cameraIntegrityOk) {
      return SystemOperationalState.healthy;
    }
    return SystemOperationalState.attention;
  }

  bool get permissionsReady =>
      (!cameraPermissionRequired || cameraPermissionGranted) &&
      (!localNetworkPermissionRequired || localNetworkPermissionGranted);
}

enum CameraHealthState { unknown, ok, obstructed, moved, offline }
