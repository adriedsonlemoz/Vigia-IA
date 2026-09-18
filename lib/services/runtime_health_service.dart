class RuntimeHealthService {
  RuntimeHealthService._();
  static final RuntimeHealthService instance = RuntimeHealthService._();

  String source = 'Parado';
  bool aiReady = false;
  double fps = 0;
  bool backgroundActive = false;
  DateTime? lastFrameAt;
  CameraHealthState cameraHealth = CameraHealthState.unknown;

  void updateFrame(DateTime at, double currentFps) {
    lastFrameAt = at;
    fps = currentFps;
    cameraHealth = CameraHealthState.ok;
  }

  void markCameraWarning(CameraHealthState value) => cameraHealth = value;
}

enum CameraHealthState { unknown, ok, obstructed, moved, offline }
