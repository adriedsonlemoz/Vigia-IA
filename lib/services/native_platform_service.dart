import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../models/alert_preferences.dart';
import '../models/system_health.dart';

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

  Future<SystemHealthSnapshot> readSystemHealth({
    required String source,
    required bool aiReady,
    required double fps,
    required bool backgroundActive,
    required int recentErrors,
    int? freeStorageMb,
    int? totalStorageMb,
  }) async {
    int? battery;
    double? temperature;
    int? memory;
    if (Platform.isAndroid) {
      try {
        final data = await _channel.invokeMapMethod<String, Object?>('systemHealth');
        battery = (data?['batteryPercent'] as num?)?.toInt();
        temperature = (data?['batteryTemperatureC'] as num?)?.toDouble();
        memory = (data?['memoryUsedMb'] as num?)?.toInt();
        freeStorageMb ??= (data?['freeStorageMb'] as num?)?.toInt();
        totalStorageMb ??= (data?['totalStorageMb'] as num?)?.toInt();
      } catch (_) {}
    }
    return SystemHealthSnapshot(
      createdAt: DateTime.now(),
      source: source,
      aiReady: aiReady,
      fps: fps,
      batteryPercent: battery,
      batteryTemperatureC: temperature,
      freeStorageMb: freeStorageMb,
      totalStorageMb: totalStorageMb,
      memoryUsedMb: memory,
      backgroundActive: backgroundActive,
      recentErrors: recentErrors,
    );
  }
}
