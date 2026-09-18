import '../models/system_health.dart';

class RuntimeHealthService {
  RuntimeHealthService._();
  static final RuntimeHealthService instance = RuntimeHealthService._();

  String source = 'Parado';
  bool monitoringActive = false;
  bool cameraActive = false;
  bool aiReady = false;
  double fps = 0;
  bool backgroundActive = false;
  DateTime? lastFrameAt;
  CameraHealthState cameraHealth = CameraHealthState.unknown;
  bool lanActive = false;
  int lanClients = 0;
  DateTime? lanLastFrameAt;
  String? lanError;

  bool framesAreFresh(
    DateTime now, {
    Duration staleAfter = const Duration(seconds: 8),
  }) {
    final last = lastFrameAt;
    if (last == null) return false;
    final age = now.difference(last);
    return !age.isNegative && age <= staleAfter;
  }

  void updateFrame(DateTime at, double currentFps) {
    lastFrameAt = at;
    fps = currentFps;
    monitoringActive = true;
    cameraActive = true;
    cameraHealth = CameraHealthState.ok;
  }

  void updateSource({
    required String name,
    required bool monitoring,
    required bool active,
  }) {
    source = name;
    monitoringActive = monitoring;
    cameraActive = active;
    if (!active && monitoring) cameraHealth = CameraHealthState.offline;
  }

  void updateLan({
    required bool active,
    required int clients,
    DateTime? lastFrameAt,
    String? error,
  }) {
    lanActive = active;
    lanClients = clients;
    lanLastFrameAt = lastFrameAt;
    lanError = error;
  }

  void markCameraWarning(CameraHealthState value) => cameraHealth = value;

  void stopMonitoring() {
    source = 'Parado';
    monitoringActive = false;
    cameraActive = false;
    fps = 0;
    lastFrameAt = null;
    cameraHealth = CameraHealthState.unknown;
    updateLan(active: false, clients: 0);
  }
}
