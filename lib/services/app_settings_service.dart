import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/alert_preferences.dart';
import '../models/monitor_schedule.dart';
import '../models/object_filter_catalog.dart';
import '../models/monitoring_preset.dart';
import '../models/monitoring_zone.dart';
import '../models/smart_alert_rules.dart';
import '../models/storage_policy.dart';
import '../models/video_source_config.dart';
import 'error_log_service.dart';
import 'background_monitor_service.dart';
import 'native_platform_service.dart';

class AppSettingsService {
  AppSettingsService._();

  static final AppSettingsService instance = AppSettingsService._();

  final ErrorLogService _logs = ErrorLogService.instance;
  final NativePlatformService _native = NativePlatformService.instance;
  Future<void> _tail = Future<void>.value();
  PersistedMonitorProfile _profile = const PersistedMonitorProfile();
  bool _initialized = false;
  File? _file;

  PersistedMonitorProfile get profile => _profile;

  Future<PersistedMonitorProfile> initialize() async {
    if (_initialized) return _profile;
    final root = await getApplicationSupportDirectory();
    _file = File('${root.path}${Platform.pathSeparator}monitor_settings.json');
    final file = _file!;
    if (await file.exists()) {
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map) {
          _profile = await _fromJson(decoded.cast<String, dynamic>());
        }
      } catch (error, stackTrace) {
        await _logs.recordException(
          source: 'Configurações',
          error: error,
          stackTrace: stackTrace,
          message: 'Falha ao carregar configurações salvas; usando padrões.',
          level: ErrorLogLevel.warning,
        );
      }
    }
    _initialized = true;
    return _profile;
  }

  Future<void> saveProfile(PersistedMonitorProfile profile) async {
    _profile = profile;
    await _enqueue(() async {
      await initialize();
      _profile = profile;
      final file = _file!;
      final temporary = File('${file.path}.tmp');
      final encoded = await _toJson(profile, protectSecrets: true);
      await temporary.writeAsString(jsonEncode(encoded), flush: true);
      if (await file.exists()) await file.delete();
      await temporary.rename(file.path);
      await BackgroundMonitorService.configureRecovery(
        enabled: profile.settings.backgroundMonitoringEnabled,
        schedule: profile.settings.schedule,
      );
    });
  }

  Future<void> updateRuntime({
    VideoSourceConfig? source,
    MonitorSettings? settings,
  }) async {
    final current = await initialize();
    await saveProfile(
      PersistedMonitorProfile(
        source: source ?? current.source,
        settings: settings ?? current.settings,
      ),
    );
  }

  Future<Map<String, Object?>> exportPortableProfile() async {
    final current = await initialize();
    final result = await _toJson(current, protectSecrets: false);
    final source = (result['source'] as Map).cast<String, Object?>();
    source['rtspUrl'] = _redactRtspCredentials(current.source.rtspUrl);
    source['remoteAccessKey'] = null;
    source['credentialsOmitted'] = true;
    return result;
  }

  Future<void> importPortableProfile(Map<String, dynamic> json) async {
    final imported = await _fromJson(json, allowProtectedSecrets: false);
    final current = await initialize();
    final mergedSource = imported.source.copyWith(
      rtspUrl: _restoreRtspCredentialsWhenCompatible(
        imported.source.rtspUrl,
        current.source.rtspUrl,
      ),
      remoteAccessKey: imported.source.remoteAccessKey ?? current.source.remoteAccessKey,
    );
    await saveProfile(PersistedMonitorProfile(source: mergedSource, settings: imported.settings));
  }

  String? _redactRtspCredentials(String? raw) {
    if (raw == null || raw.isEmpty) return raw;
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'rtsp' || uri.host.isEmpty) return null;
    return uri.replace(userInfo: '').toString();
  }

  String? _restoreRtspCredentialsWhenCompatible(String? imported, String? current) {
    if (imported == null || imported.isEmpty) return current;
    final importedUri = Uri.tryParse(imported);
    final currentUri = Uri.tryParse(current ?? '');
    if (importedUri == null || importedUri.scheme != 'rtsp') return current;
    if (importedUri.userInfo.isNotEmpty || currentUri == null || currentUri.userInfo.isEmpty) {
      return imported;
    }
    final sameEndpoint = importedUri.host == currentUri.host &&
        importedUri.port == currentUri.port &&
        importedUri.path == currentUri.path &&
        importedUri.query == currentUri.query;
    if (!sameEndpoint) return imported;
    return importedUri.replace(userInfo: currentUri.userInfo).toString();
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final previous = _tail;
    final completer = Completer<void>();
    _tail = () async {
      try {
        await previous;
      } catch (_) {}
      try {
        await operation();
        if (!completer.isCompleted) completer.complete();
      } catch (error, stackTrace) {
        await _logs.recordException(
          source: 'Configurações',
          error: error,
          stackTrace: stackTrace,
          message: 'Não foi possível persistir as configurações.',
          level: ErrorLogLevel.warning,
        );
        if (!completer.isCompleted) completer.complete();
      }
    }();
    return completer.future;
  }

  Future<Map<String, Object?>> _toJson(
    PersistedMonitorProfile profile, {
    required bool protectSecrets,
  }) async {
    final settings = profile.settings;
    final rules = settings.smartAlertRules;
    final source = profile.source.toJson(includeSensitive: !protectSecrets);
    if (protectSecrets) {
      source['rtspUrl'] = null;
      source['remoteAccessKey'] = null;
      if ((profile.source.rtspUrl ?? '').isNotEmpty) {
        source['rtspSecret'] = await _native.protectSecret(profile.source.rtspUrl!);
      }
      if ((profile.source.remoteAccessKey ?? '').isNotEmpty) {
        source['remoteAccessKeySecret'] = await _native.protectSecret(profile.source.remoteAccessKey!);
      }
    }
    return <String, Object?>{
      'version': 8,
      'source': source,
      'settings': <String, Object?>{
        'confidenceThreshold': settings.confidenceThreshold,
        'repeatIntervalMs': settings.repeatInterval.inMilliseconds,
        'absenceResetMs': settings.absenceReset.inMilliseconds,
        'maxResults': settings.maxResults,
        'motionOnly': settings.motionOnly,
        'motionConfirmationHits': settings.motionConfirmationHits,
        'alertLabels': settings.alertLabels.toList()..sort(),
        'monitoringZones': settings.monitoringZones.map((zone) => zone.toJson()).toList(growable: false),
        'smartAlertRules': <String, Object?>{
          'enabled': rules.enabled,
          'personMs': rules.personMinimumPresence.inMilliseconds,
          'vehicleMs': rules.vehicleMinimumPresence.inMilliseconds,
          'animalMs': rules.animalMinimumPresence.inMilliseconds,
          'otherMs': rules.otherMinimumPresence.inMilliseconds,
          'ignoreStationaryVehicles': rules.ignoreStationaryVehicles,
        },
        'clipRecordingEnabled': settings.clipRecordingEnabled,
        'clipDurationMs': settings.clipDuration.inMilliseconds,
        'clipFormatPreference': settings.clipFormatPreference.name,
        'trackingEnabled': settings.trackingEnabled,
        'announceEntryExit': settings.announceEntryExit,
        'backgroundMonitoringEnabled': settings.backgroundMonitoringEnabled,
        'voiceEnabled': settings.alertOutputs.voice,
        'alertOutputs': settings.alertOutputs.toJson(),
        'voiceAlertPreferences': settings.voiceAlertPreferences.toJson(),
        'alertMessages': settings.alertMessages.toJson(),
        'storagePolicy': settings.storagePolicy.toJson(),
        'preset': settings.preset.name,
        'cameraIntegrityEnabled': settings.cameraIntegrityEnabled,
        'schedule': settings.schedule.toJson(),
      },
    };
  }

  Future<PersistedMonitorProfile> _fromJson(
    Map<String, dynamic> json, {
    bool allowProtectedSecrets = true,
  }) async {
    final sourceJson = (json['source'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final settingsJson = (json['settings'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final rulesJson = (settingsJson['smartAlertRules'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final scheduleJson = (settingsJson['schedule'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final alertOutputsJson = (settingsJson['alertOutputs'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final voiceAlertPreferencesJson = (settingsJson['voiceAlertPreferences'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final alertMessagesJson = (settingsJson['alertMessages'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final storagePolicyJson = (settingsJson['storagePolicy'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};

    final zones = (settingsJson['monitoringZones'] as List?)
            ?.whereType<Map>()
            .map((item) => MonitoringZoneProfile.fromJson(item.cast<String, dynamic>()))
            .toList(growable: false) ??
        const <MonitoringZoneProfile>[MonitoringZoneProfile.primary()];
    final storedLabels = (settingsJson['alertLabels'] as List?)?.whereType<String>().toSet() ?? const MonitorSettings().alertLabels;
    final labels = ObjectFilterCatalog.normalizeSelection(storedLabels);

    final profileVersion = (json['version'] as num?)?.toInt() ?? 0;
    final storedVehicleMs = (rulesJson['vehicleMs'] as num?)?.toInt();
    final storedAnimalMs = (rulesJson['animalMs'] as num?)?.toInt();
    final storedOtherMs = (rulesJson['otherMs'] as num?)?.toInt();
    final rules = SmartAlertRules(
      enabled: rulesJson['enabled'] as bool? ?? true,
      personMinimumPresence: Duration(milliseconds: (rulesJson['personMs'] as num?)?.toInt() ?? 0),
      vehicleMinimumPresence: Duration(
        milliseconds: profileVersion < 7 && storedVehicleMs == 1000
            ? 600
            : (storedVehicleMs ?? 600),
      ),
      animalMinimumPresence: Duration(
        milliseconds: profileVersion < 7 && storedAnimalMs == 3000
            ? 800
            : (storedAnimalMs ?? 800),
      ),
      otherMinimumPresence: Duration(
        milliseconds: profileVersion < 7 && storedOtherMs == 2000
            ? 1200
            : (storedOtherMs ?? 1200),
      ),
      ignoreStationaryVehicles: rulesJson['ignoreStationaryVehicles'] as bool? ?? true,
    );

    var source = VideoSourceConfig.fromJson(sourceJson);
    if (profileVersion < 6 && source.analysisInterval == const Duration(milliseconds: 800)) {
      source = source.copyWith(analysisInterval: const Duration(milliseconds: 400));
    }
    if (allowProtectedSecrets) {
      final protectedRtsp = sourceJson['rtspSecret'] as String?;
      final protectedRemoteKey = sourceJson['remoteAccessKeySecret'] as String?;
      final restoredRtsp = await _native.unprotectSecret(protectedRtsp);
      final restoredRemoteKey = await _native.unprotectSecret(protectedRemoteKey);
      source = source.copyWith(
        rtspUrl: restoredRtsp ?? source.rtspUrl,
        remoteAccessKey: restoredRemoteKey ?? source.remoteAccessKey,
      );
    }

    final legacyVoice = settingsJson['voiceEnabled'] as bool?;
    final outputs = AlertOutputs.fromJson(alertOutputsJson, legacyVoice: legacyVoice);
    final clipFormatName = settingsJson['clipFormatPreference'] as String?;
    final clipFormat = ClipFormatPreference.values.firstWhere(
      (item) => item.name == clipFormatName,
      orElse: () => ClipFormatPreference.mp4WithGifFallback,
    );
    final presetName = settingsJson['preset'] as String?;
    final preset = MonitoringPreset.values.firstWhere(
      (item) => item.name == presetName,
      orElse: () => MonitoringPreset.custom,
    );

    return PersistedMonitorProfile(
      source: source,
      settings: MonitorSettings(
        confidenceThreshold: (settingsJson['confidenceThreshold'] as num?)?.toDouble() ?? 0.55,
        repeatInterval: Duration(milliseconds: (settingsJson['repeatIntervalMs'] as num?)?.toInt() ?? 60000),
        absenceReset: Duration(
          milliseconds: _migratedAbsenceResetMs(
            profileVersion,
            (settingsJson['absenceResetMs'] as num?)?.toInt(),
          ),
        ),
        maxResults: (settingsJson['maxResults'] as num?)?.toInt() ?? 10,
        motionOnly: settingsJson['motionOnly'] as bool? ?? true,
        motionConfirmationHits: (settingsJson['motionConfirmationHits'] as num?)?.toInt() ?? 2,
        alertLabels: labels,
        monitoringZones: zones.isEmpty ? const <MonitoringZoneProfile>[MonitoringZoneProfile.primary()] : zones,
        smartAlertRules: rules,
        clipRecordingEnabled: settingsJson['clipRecordingEnabled'] as bool? ?? true,
        clipDuration: Duration(milliseconds: ((settingsJson['clipDurationMs'] as num?)?.toInt() ?? 8000).clamp(3000, 20000).toInt()),
        clipFormatPreference: clipFormat,
        trackingEnabled: settingsJson['trackingEnabled'] as bool? ?? true,
        announceEntryExit: settingsJson['announceEntryExit'] as bool? ?? true,
        backgroundMonitoringEnabled: settingsJson['backgroundMonitoringEnabled'] as bool? ?? false,
        voiceEnabled: outputs.voice,
        alertOutputs: outputs,
        voiceAlertPreferences: VoiceAlertPreferences.fromJson(voiceAlertPreferencesJson),
        alertMessages: AlertMessages.fromJson(alertMessagesJson),
        storagePolicy: StoragePolicy.fromJson(storagePolicyJson),
        preset: preset,
        cameraIntegrityEnabled: settingsJson['cameraIntegrityEnabled'] as bool? ?? true,
        schedule: MonitorSchedule.fromJson(scheduleJson),
      ),
    );
  }
  int _migratedAbsenceResetMs(int profileVersion, int? stored) {
    final value = stored ?? 1000;
    if (profileVersion < 6 && value == 3000) return 1000;
    return value.clamp(500, 30000).toInt();
  }

}
