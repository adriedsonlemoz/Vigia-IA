import '../models/system_health.dart';
import '../models/video_source_config.dart';
import 'app_settings_service.dart';
import 'background_monitor_service.dart';
import 'error_log_service.dart';
import 'native_platform_service.dart';
import 'runtime_health_service.dart';

class SystemHealthService {
  SystemHealthService({
    NativePlatformService? native,
    RuntimeHealthService? runtime,
    ErrorLogService? logs,
    AppSettingsService? settings,
  })  : _native = native ?? NativePlatformService.instance,
        _runtime = runtime ?? RuntimeHealthService.instance,
        _logs = logs ?? ErrorLogService.instance,
        _settings = settings ?? AppSettingsService.instance;

  final NativePlatformService _native;
  final RuntimeHealthService _runtime;
  final ErrorLogService _logs;
  final AppSettingsService _settings;

  Future<SystemHealthSnapshot> collect({DateTime? now}) async {
    final collectedAt = now ?? DateTime.now();
    final profile = await _settings.initialize();
    final background = await BackgroundMonitorService.status();
    final cameraPermission = await _native.cameraPermissionStatus();
    final cameraPermissionRequired =
        profile.source.type == VideoSourceType.localCamera;
    final lanPermission = await _native.localNetworkPermissionStatus();
    final notifications = await _native.notificationsAllowed();
    final framesActive = _runtime.framesAreFresh(collectedAt);
    final monitoringActive = _runtime.monitoringActive;
    final cameraActive = _runtime.cameraActive && framesActive;
    final aiActive = monitoringActive && framesActive && _runtime.aiReady;
    final backgroundRequested = profile.settings.backgroundMonitoringEnabled;
    final backgroundOperational = backgroundRequested &&
        background.running &&
        monitoringActive &&
        framesActive;
    final lanOperational =
        _runtime.lanActive && framesActive && _runtime.lanError == null;

    return _native.readSystemHealth(
      source: _runtime.source,
      monitoringActive: monitoringActive,
      androidServiceActive: background.running,
      cameraActive: cameraActive,
      framesActive: framesActive,
      aiReady: _runtime.aiReady,
      aiActive: aiActive,
      lanActive: lanOperational,
      connectedClients: _runtime.lanClients,
      backgroundRequested: backgroundRequested,
      backgroundOperational: backgroundOperational,
      screenInteractive: background.screenInteractive,
      cameraPermissionRequired: cameraPermissionRequired,
      cameraPermissionGranted: cameraPermission.granted,
      localNetworkPermissionRequired: lanPermission.required,
      localNetworkPermissionGranted: lanPermission.granted,
      notificationsAllowed: notifications,
      lastFrameAt: _runtime.lastFrameAt,
      lanLastFrameAt: _runtime.lanLastFrameAt,
      lanError: _runtime.lanError,
      fps: framesActive ? _runtime.fps : 0,
      recentErrors: _logs.problemCount,
      cameraHealth: framesActive
          ? _runtime.cameraHealth
          : monitoringActive
              ? CameraHealthState.offline
              : _runtime.cameraHealth,
    );
  }
}
