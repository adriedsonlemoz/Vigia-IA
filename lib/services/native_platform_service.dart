import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../core/app_metadata.dart';
import '../models/alert_preferences.dart';
import '../models/device_telemetry.dart';
import '../models/system_health.dart';
import 'error_log_service.dart';


class AppVersionInfo {
  const AppVersionInfo({required this.version, required this.build});

  final String version;
  final int build;
}

class CameraPermissionStatus {
  const CameraPermissionStatus({
    required this.granted,
    required this.prompted,
    required this.showRationale,
    required this.canRequest,
  });

  final bool granted;
  final bool prompted;
  final bool showRationale;
  final bool canRequest;

  factory CameraPermissionStatus.fromMap(Map<Object?, Object?> map) {
    return CameraPermissionStatus(
      granted: map['granted'] as bool? ?? false,
      prompted: map['prompted'] as bool? ?? false,
      showRationale: map['showRationale'] as bool? ?? false,
      canRequest: map['canRequest'] as bool? ?? false,
    );
  }
}


class LocalNetworkPermissionStatus {
  const LocalNetworkPermissionStatus({
    required this.required,
    required this.granted,
    required this.canRequest,
  });

  final bool required;
  final bool granted;
  final bool canRequest;

  factory LocalNetworkPermissionStatus.fromMap(Map<Object?, Object?> map) {
    return LocalNetworkPermissionStatus(
      required: map['required'] as bool? ?? false,
      granted: map['granted'] as bool? ?? false,
      canRequest: map['canRequest'] as bool? ?? false,
    );
  }
}

class NativePlatformService {
  NativePlatformService._();

  static final NativePlatformService instance = NativePlatformService._();
  static const MethodChannel _channel = MethodChannel('vigiaia/native');


  Future<AppVersionInfo> appVersionInfo() async {
    if (!Platform.isAndroid) {
      return const AppVersionInfo(
        version: AppMetadata.version,
        build: AppMetadata.build,
      );
    }
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>('appVersionInfo');
      final version = raw?['versionName'] as String?;
      final buildValue = raw?['versionCode'];
      final build = buildValue is num ? buildValue.toInt() : null;
      if (version != null && version.isNotEmpty && build != null) {
        return AppVersionInfo(version: version, build: build);
      }
    } catch (_) {}
    return const AppVersionInfo(
      version: AppMetadata.version,
      build: AppMetadata.build,
    );
  }

  Future<String> protectSecret(String value) async {
    if (value.isEmpty) return '';
    if (!Platform.isAndroid) return 'fallback:${base64Encode(utf8.encode(value))}';
    try {
      final result = await _channel.invokeMethod<String>('protectSecret', <String, Object?>{'value': value});
      if (result == null || !result.startsWith('gcm:')) {
        throw StateError('Android Keystore não retornou uma credencial criptografada.');
      }
      return result;
    } catch (error) {
      // No Android, nunca degradar uma credencial para Base64/texto reversível.
      // Se o Keystore falhar, a persistência segura deve falhar junto.
      throw StateError('Não foi possível proteger a credencial no Android Keystore: $error');
    }
  }

  Future<String?> unprotectSecret(String? value) async {
    if (value == null || value.isEmpty) return null;
    if (value.startsWith('fallback:')) {
      try {
        return utf8.decode(base64Decode(value.substring('fallback:'.length)));
      } catch (_) {
        return null;
      }
    }
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('unprotectSecret', <String, Object?>{'value': value});
    } catch (_) {
      return null;
    }
  }

  Future<bool> requestCameraPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('requestCameraPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<CameraPermissionStatus> cameraPermissionStatus() async {
    if (!Platform.isAndroid) {
      return const CameraPermissionStatus(
        granted: true,
        prompted: true,
        showRationale: false,
        canRequest: false,
      );
    }
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
        'cameraPermissionStatus',
      );
      if (raw != null) return CameraPermissionStatus.fromMap(raw);
    } catch (_) {}
    return const CameraPermissionStatus(
      granted: false,
      prompted: false,
      showRationale: false,
      canRequest: false,
    );
  }

  Future<void> openAppSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('openAppSettings');
    } catch (_) {}
  }

  Future<bool> openExternalUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      return false;
    }
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'openExternalUrl',
            <String, Object?>{'url': uri.toString()},
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> onboardingCompleted() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('onboardingCompleted') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> markOnboardingCompleted() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('markOnboardingCompleted') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<String?> saveBytesToDownloads({
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>(
        'saveBytesToDownloads',
        <String, Object?>{
          'fileName': fileName,
          'mimeType': mimeType,
          'bytes': bytes,
        },
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> saveBytesWithPicker({
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>(
        'saveBytesWithPicker',
        <String, Object?>{
          'fileName': fileName,
          'mimeType': mimeType,
          'bytes': bytes,
        },
      );
    } catch (_) {
      return null;
    }
  }

  Future<({String path, String name, int sizeBytes})?> pickOfflineMapPackage() async {
    if (!Platform.isAndroid) return null;
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
        'pickOfflineMapPackage',
      );
      if (raw == null) return null;
      final path = raw['path'] as String?;
      if (path == null || path.isEmpty) return null;
      return (
        path: path,
        name: raw['name'] as String? ?? 'mapa_offline.mbtiles',
        sizeBytes: (raw['sizeBytes'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }


  Future<LocalNetworkPermissionStatus> localNetworkPermissionStatus() async {
    if (!Platform.isAndroid) {
      return const LocalNetworkPermissionStatus(
        required: false,
        granted: true,
        canRequest: false,
      );
    }
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
        'localNetworkPermissionStatus',
      );
      if (raw != null) return LocalNetworkPermissionStatus.fromMap(raw);
    } catch (_) {}
    return const LocalNetworkPermissionStatus(
      required: false,
      granted: false,
      canRequest: true,
    );
  }

  Future<bool> requestLocalNetworkPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('requestLocalNetworkPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('requestNotificationPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> notificationsAllowed() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('notificationsAllowed') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> stopAlertAudio() async {
    try { await _channel.invokeMethod<bool>('stopAlertAudio'); } catch (_) {}
  }

  Future<Map<String, Object?>> audioDiagnostics() async {
    try {
      final data = await _channel.invokeMapMethod<String, Object?>('audioDiagnostics');
      return data ?? <String, Object?>{};
    } catch (error) {
      return <String, Object?>{
        'state': 'indisponível',
        'channelError': error.toString(),
      };
    }
  }

  Future<void> setMonitorFullscreen(bool enabled) async {
    try {
      await _channel.invokeMethod<bool>('setMonitorFullscreen', {'enabled': enabled});
    } catch (_) { /* A API Flutter continua disponível em outras plataformas. */ }
  }

  Future<bool> playCustomAlertAudio(String slot, {int priority = 0, DateTime? capturedAt}) async {
    if (!Platform.isAndroid || slot.trim().isEmpty) return false;
    final normalizedSlot = slot.trim();
    try {
      final handled = await _channel.invokeMethod<bool>(
            'playCustomAlertAudio',
            <String, Object?>{'slot': normalizedSlot, 'priority': priority,
              if (capturedAt != null) 'capturedAtMs': capturedAt.millisecondsSinceEpoch},
          ) ??
          false;
      final diagnostics = await audioDiagnostics();
      final usedFallback = diagnostics['lastPlaybackUsedFallback'] == true;
      if (!handled || usedFallback) {
        await ErrorLogService.instance.record(
          level: handled ? ErrorLogLevel.warning : ErrorLogLevel.error,
          source: 'Áudio nativo',
          message: handled
              ? 'O áudio personalizado $normalizedSlot falhou; o áudio integrado foi usado.'
              : 'Falha ao reproduzir o áudio $normalizedSlot.',
          details: jsonEncode(diagnostics),
          context: <String, Object?>{
            'slot': normalizedSlot,
            'priority': priority,
            'code': diagnostics['lastErrorCode'],
            'phase': diagnostics['lastErrorPhase'],
            'source': diagnostics['lastSource'],
            'fallback': handled
                ? 'áudio integrado reproduzido'
                : 'TTS solicitado pelo fluxo de voz',
          },
        );
      }
      return handled;
    } catch (error, stackTrace) {
      await ErrorLogService.instance.recordException(
        source: 'Áudio nativo',
        error: error,
        stackTrace: stackTrace,
        message: 'A ponte Android falhou ao reproduzir o áudio $normalizedSlot.',
        context: <String, Object?>{
          'slot': normalizedSlot,
          'priority': priority,
          'capturedAt': capturedAt?.toIso8601String(),
        },
      );
      return false;
    }
  }

  Future<Set<String>> audioOverrideSlots() async {
    if (!Platform.isAndroid) return <String>{};
    try {
      final slots = await _channel.invokeListMethod<String>('audioOverrideSlots');
      return slots?.toSet() ?? <String>{};
    } catch (_) {
      return <String>{};
    }
  }

  Future<bool> importAudioOverride(String slot) async {
    if (!Platform.isAndroid || slot.trim().isEmpty) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'importAudioOverride',
            <String, Object?>{'slot': slot.trim()},
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> removeAudioOverride(String slot) async {
    if (!Platform.isAndroid || slot.trim().isEmpty) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'removeAudioOverride',
            <String, Object?>{'slot': slot.trim()},
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> removeAllAudioOverrides() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('removeAllAudioOverrides') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> startAudioRecording(String slot) async {
    if (!Platform.isAndroid || slot.trim().isEmpty) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'startAudioRecording',
            <String, Object?>{'slot': slot.trim()},
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> stopAudioRecording({required bool save}) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'stopAudioRecording',
            <String, Object?>{'save': save},
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<void> showAlertNotification({
    required String title,
    required String message,
    required AlertOutputs outputs,
  }) async {
    if (!Platform.isAndroid || (!outputs.androidNotification && !outputs.sound && !outputs.vibration)) return;
    try {
      await _channel.invokeMethod<void>('showAlertNotification', <String, Object?>{
        'title': title,
        'message': message,
        'notification': outputs.androidNotification,
        'sound': outputs.sound,
        'vibration': outputs.vibration,
      });
    } catch (_) {}
  }

  Future<bool> encodeMp4({
    required String outputPath,
    required List<Map<String, Object>> frames,
    required int fps,
  }) async {
    if (!Platform.isAndroid || frames.length < 2) return false;
    try {
      return await _channel.invokeMethod<bool>('encodeMp4', <String, Object?>{
            'outputPath': outputPath,
            'fps': fps.clamp(1, 12),
            'frames': frames,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> shareText({
    required String subject,
    required String text,
  }) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('shareText', <String, Object?>{
            'subject': subject,
            'text': text,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<DeviceTelemetrySnapshot> readDeviceTelemetry() async {
    if (!Platform.isAndroid) {
      return DeviceTelemetrySnapshot(createdAt: DateTime.now());
    }
    try {
      final data = await _channel.invokeMethod<Map<Object?, Object?>>('systemHealth');
      if (data != null) return DeviceTelemetrySnapshot.fromMap(data);
    } catch (_) {}
    return DeviceTelemetrySnapshot(createdAt: DateTime.now());
  }

  Future<void> setBikeScreenBrightness(double? value) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>(
        'setBikeScreenBrightness',
        <String, Object?>{'value': value},
      );
    } catch (_) {}
  }

  Future<SystemHealthSnapshot> readSystemHealth({
    required String source,
    required bool monitoringActive,
    required bool androidServiceActive,
    required bool flutterHeartbeatFresh,
    required int androidServiceLeaseCount,
    required bool cameraActive,
    required bool framesActive,
    required bool aiReady,
    required bool aiActive,
    required bool lanServerActive,
    required bool lanFramesActive,
    required bool lanActive,
    required int connectedClients,
    required bool backgroundRequested,
    required bool backgroundOperational,
    required bool screenInteractive,
    required bool cameraPermissionRequired,
    required bool cameraPermissionGranted,
    required bool localNetworkPermissionRequired,
    required bool localNetworkPermissionGranted,
    required bool notificationsAllowed,
    required DateTime? lastFrameAt,
    required DateTime? lanLastFrameAt,
    required String? lanError,
    required double fps,
    required int recentErrors,
    required CameraHealthState cameraHealth,
    int? freeStorageBytes,
    int? totalStorageBytes,
    int? memoryUsedBytes,
  }) async {
    final telemetry = await readDeviceTelemetry();
    memoryUsedBytes ??= telemetry.appMemoryUsedBytes;
    freeStorageBytes ??= telemetry.freeStorageBytes;
    totalStorageBytes ??= telemetry.totalStorageBytes;
    return SystemHealthSnapshot(
      createdAt: DateTime.now(),
      source: source,
      monitoringActive: monitoringActive,
      androidServiceActive: androidServiceActive,
      flutterHeartbeatFresh: flutterHeartbeatFresh,
      androidServiceLeaseCount: androidServiceLeaseCount,
      cameraActive: cameraActive,
      framesActive: framesActive,
      aiReady: aiReady,
      aiActive: aiActive,
      lanServerActive: lanServerActive,
      lanFramesActive: lanFramesActive,
      lanActive: lanActive,
      connectedClients: connectedClients,
      backgroundRequested: backgroundRequested,
      backgroundOperational: backgroundOperational,
      screenInteractive: screenInteractive,
      cameraPermissionRequired: cameraPermissionRequired,
      cameraPermissionGranted: cameraPermissionGranted,
      localNetworkPermissionRequired: localNetworkPermissionRequired,
      localNetworkPermissionGranted: localNetworkPermissionGranted,
      notificationsAllowed: notificationsAllowed,
      lastFrameAt: lastFrameAt,
      lanLastFrameAt: lanLastFrameAt,
      lanError: lanError,
      fps: fps,
      batteryPercent: telemetry.batteryPercent,
      batteryCharging: telemetry.batteryCharging,
      batteryPowerSource: telemetry.batteryPowerSource,
      batteryCurrentMa: telemetry.batteryCurrentMa,
      batteryTemperatureC: telemetry.batteryTemperatureC,
      screenBrightnessPercent: telemetry.screenBrightnessPercent,
      automaticBrightness: telemetry.automaticBrightness,
      screenDimmedByBike: telemetry.screenDimmedByBike,
      appCpuPercent: telemetry.appCpuPercent,
      processorCount: telemetry.processorCount,
      memoryAvailableBytes: telemetry.memoryAvailableBytes,
      memoryTotalBytes: telemetry.memoryTotalBytes,
      freeStorageBytes: freeStorageBytes,
      totalStorageBytes: totalStorageBytes,
      memoryUsedBytes: memoryUsedBytes,
      recentErrors: recentErrors,
      cameraHealth: cameraHealth,
    );
  }
}
