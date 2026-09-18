import '../models/alert_preferences.dart';
import '../models/monitoring_preset.dart';
import '../models/video_source_config.dart';

class MonitoringPresetService {
  const MonitoringPresetService();

  MonitorSettings apply(MonitorSettings current, MonitoringPreset preset) {
    return switch (preset) {
      MonitoringPreset.home => current.copyWith(
          preset: preset,
          confidenceThreshold: 0.60,
          repeatInterval: const Duration(seconds: 90),
          motionOnly: true,
          alertOutputs: current.alertOutputs.copyWith(voice: true, vibration: false),
        ),
      MonitoringPreset.away => current.copyWith(
          preset: preset,
          confidenceThreshold: 0.50,
          repeatInterval: const Duration(seconds: 45),
          motionOnly: true,
          backgroundMonitoringEnabled: true,
          cameraIntegrityEnabled: true,
          alertOutputs: const AlertOutputs(voice: true, sound: true, vibration: true, androidNotification: true),
        ),
      MonitoringPreset.night => current.copyWith(
          preset: preset,
          confidenceThreshold: 0.58,
          repeatInterval: const Duration(seconds: 120),
          motionOnly: true,
          alertOutputs: current.alertOutputs.copyWith(voice: false, sound: false, vibration: true),
        ),
      MonitoringPreset.custom => current.copyWith(preset: preset),
    };
  }
}
