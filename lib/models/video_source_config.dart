import 'alert_preferences.dart';
import 'monitor_schedule.dart';
import 'monitoring_preset.dart';
import 'monitoring_zone.dart';
import 'object_filter_catalog.dart';
import 'smart_alert_rules.dart';
import 'storage_policy.dart';

enum VideoSourceType { localCamera, rtsp, remotePhone }

enum ClipFormatPreference { mp4WithGifFallback, gifOnly }

class VideoSourceConfig {
  const VideoSourceConfig({
    required this.type,
    this.rtspUrl,
    this.remoteBaseUrl,
    this.remoteAccessKey,
    this.displayName,
    this.cameraId,
    this.analysisInterval = const Duration(milliseconds: 800),
  });

  final VideoSourceType type;
  final String? rtspUrl;
  final String? remoteBaseUrl;
  final String? remoteAccessKey;
  final String? displayName;
  final String? cameraId;
  final Duration analysisInterval;

  VideoSourceConfig copyWith({
    VideoSourceType? type,
    String? rtspUrl,
    bool clearRtspUrl = false,
    String? remoteBaseUrl,
    String? remoteAccessKey,
    String? displayName,
    String? cameraId,
    Duration? analysisInterval,
  }) =>
      VideoSourceConfig(
        type: type ?? this.type,
        rtspUrl: clearRtspUrl ? null : (rtspUrl ?? this.rtspUrl),
        remoteBaseUrl: remoteBaseUrl ?? this.remoteBaseUrl,
        remoteAccessKey: remoteAccessKey ?? this.remoteAccessKey,
        displayName: displayName ?? this.displayName,
        cameraId: cameraId ?? this.cameraId,
        analysisInterval: analysisInterval ?? this.analysisInterval,
      );

  Map<String, Object?> toJson({bool includeSensitive = true}) => <String, Object?>{
        'type': type.name,
        'rtspUrl': includeSensitive ? rtspUrl : null,
        'remoteBaseUrl': remoteBaseUrl,
        'remoteAccessKey': includeSensitive ? remoteAccessKey : null,
        'displayName': displayName,
        'cameraId': cameraId,
        'analysisIntervalMs': analysisInterval.inMilliseconds,
      };

  factory VideoSourceConfig.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String?;
    final type = VideoSourceType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () => VideoSourceType.localCamera,
    );
    return VideoSourceConfig(
      type: type,
      rtspUrl: json['rtspUrl'] as String?,
      remoteBaseUrl: json['remoteBaseUrl'] as String?,
      remoteAccessKey: json['remoteAccessKey'] as String?,
      displayName: json['displayName'] as String?,
      cameraId: json['cameraId'] as String?,
      analysisInterval: Duration(
        milliseconds: ((json['analysisIntervalMs'] as num?)?.toInt() ?? 800)
            .clamp(250, 5000)
            .toInt(),
      ),
    );
  }
}

class MonitorSettings {
  const MonitorSettings({
    this.confidenceThreshold = 0.55,
    this.repeatInterval = const Duration(seconds: 60),
    this.absenceReset = const Duration(seconds: 3),
    this.maxResults = 10,
    this.motionOnly = true,
    this.motionConfirmationHits = 2,
    this.alertLabels = ObjectFilterCatalog.recommended,
    this.monitoringZones = const <MonitoringZoneProfile>[
      MonitoringZoneProfile.primary(),
    ],
    this.smartAlertRules = const SmartAlertRules(),
    this.clipRecordingEnabled = true,
    this.clipDuration = const Duration(seconds: 8),
    this.clipFormatPreference = ClipFormatPreference.mp4WithGifFallback,
    this.trackingEnabled = true,
    this.announceEntryExit = true,
    this.backgroundMonitoringEnabled = false,
    this.voiceEnabled = true,
    this.alertOutputs = const AlertOutputs(),
    this.alertMessages = const AlertMessages(),
    this.storagePolicy = const StoragePolicy(),
    this.preset = MonitoringPreset.custom,
    this.cameraIntegrityEnabled = true,
    this.schedule = const MonitorSchedule(),
  });

  final double confidenceThreshold;
  final Duration repeatInterval;
  final Duration absenceReset;
  final int maxResults;
  final bool motionOnly;
  final int motionConfirmationHits;
  final Set<String> alertLabels;
  final List<MonitoringZoneProfile> monitoringZones;
  final SmartAlertRules smartAlertRules;
  final bool clipRecordingEnabled;
  final Duration clipDuration;
  final ClipFormatPreference clipFormatPreference;
  final bool trackingEnabled;
  final bool announceEntryExit;
  final bool backgroundMonitoringEnabled;
  final bool voiceEnabled;
  final AlertOutputs alertOutputs;
  final AlertMessages alertMessages;
  final StoragePolicy storagePolicy;
  final MonitoringPreset preset;
  final bool cameraIntegrityEnabled;
  final MonitorSchedule schedule;

  MonitorSettings copyWith({
    double? confidenceThreshold,
    Duration? repeatInterval,
    Duration? absenceReset,
    int? maxResults,
    bool? motionOnly,
    int? motionConfirmationHits,
    Set<String>? alertLabels,
    List<MonitoringZoneProfile>? monitoringZones,
    SmartAlertRules? smartAlertRules,
    bool? clipRecordingEnabled,
    Duration? clipDuration,
    ClipFormatPreference? clipFormatPreference,
    bool? trackingEnabled,
    bool? announceEntryExit,
    bool? backgroundMonitoringEnabled,
    bool? voiceEnabled,
    AlertOutputs? alertOutputs,
    AlertMessages? alertMessages,
    StoragePolicy? storagePolicy,
    MonitoringPreset? preset,
    bool? cameraIntegrityEnabled,
    MonitorSchedule? schedule,
  }) =>
      MonitorSettings(
        confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
        repeatInterval: repeatInterval ?? this.repeatInterval,
        absenceReset: absenceReset ?? this.absenceReset,
        maxResults: maxResults ?? this.maxResults,
        motionOnly: motionOnly ?? this.motionOnly,
        motionConfirmationHits: motionConfirmationHits ?? this.motionConfirmationHits,
        alertLabels: alertLabels ?? this.alertLabels,
        monitoringZones: monitoringZones ?? this.monitoringZones,
        smartAlertRules: smartAlertRules ?? this.smartAlertRules,
        clipRecordingEnabled: clipRecordingEnabled ?? this.clipRecordingEnabled,
        clipDuration: clipDuration ?? this.clipDuration,
        clipFormatPreference: clipFormatPreference ?? this.clipFormatPreference,
        trackingEnabled: trackingEnabled ?? this.trackingEnabled,
        announceEntryExit: announceEntryExit ?? this.announceEntryExit,
        backgroundMonitoringEnabled: backgroundMonitoringEnabled ?? this.backgroundMonitoringEnabled,
        voiceEnabled: voiceEnabled ?? this.voiceEnabled,
        alertOutputs: alertOutputs ?? this.alertOutputs,
        alertMessages: alertMessages ?? this.alertMessages,
        storagePolicy: storagePolicy ?? this.storagePolicy,
        preset: preset ?? this.preset,
        cameraIntegrityEnabled: cameraIntegrityEnabled ?? this.cameraIntegrityEnabled,
        schedule: schedule ?? this.schedule,
      );
}

class PersistedMonitorProfile {
  const PersistedMonitorProfile({
    this.source = const VideoSourceConfig(type: VideoSourceType.localCamera),
    this.settings = const MonitorSettings(),
  });

  final VideoSourceConfig source;
  final MonitorSettings settings;
}
