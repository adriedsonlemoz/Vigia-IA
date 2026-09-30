import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../models/monitor_schedule.dart';

class BackgroundMonitorStatus {
  const BackgroundMonitorStatus({
    required this.running,
    required this.usesCamera,
    required this.screenInteractive,
    required this.statusText,
    required this.startedAtElapsedRealtime,
    this.flutterHeartbeatFresh = false,
    this.lastFlutterHeartbeatElapsedRealtime = 0,
    this.leaseCount = 0,
  });

  final bool running;
  final bool usesCamera;
  final bool screenInteractive;
  final String statusText;
  final int startedAtElapsedRealtime;
  final bool flutterHeartbeatFresh;
  final int lastFlutterHeartbeatElapsedRealtime;
  final int leaseCount;

  factory BackgroundMonitorStatus.fromMap(Map<Object?, Object?> map) {
    return BackgroundMonitorStatus(
      running: map['running'] as bool? ?? false,
      usesCamera: map['usesCamera'] as bool? ?? false,
      screenInteractive: map['screenInteractive'] as bool? ?? true,
      statusText: map['statusText'] as String? ?? '',
      startedAtElapsedRealtime:
          (map['startedAtElapsedRealtime'] as num?)?.toInt() ?? 0,
      flutterHeartbeatFresh: map['flutterHeartbeatFresh'] as bool? ?? false,
      lastFlutterHeartbeatElapsedRealtime:
          (map['lastFlutterHeartbeatElapsedRealtime'] as num?)?.toInt() ?? 0,
      leaseCount: (map['leaseCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class BackgroundMonitorService {
  BackgroundMonitorService._();

  static const MethodChannel _channel = MethodChannel('vigiaia/background');
  static const String monitorOwner = 'monitor';
  static const String cameraModeOwner = 'cameraMode';
  static const String _legacyOwner = 'legacy';

  static final Set<String> _owners = <String>{};
  static Timer? _heartbeatTimer;

  static Future<bool> acquire({
    required String owner,
    bool usesCamera = true,
    String? statusText,
  }) async {
    if (!Platform.isAndroid) return false;
    final normalizedOwner = owner.trim();
    if (normalizedOwner.isEmpty) return false;
    try {
      final arguments = <String, Object?>{
        'owner': normalizedOwner,
        'usesCamera': usesCamera,
      };
      if (statusText != null) arguments['statusText'] = statusText;
      final started =
          await _channel.invokeMethod<bool>('acquire', arguments) ?? false;
      if (started) {
        _owners.add(normalizedOwner);
        await heartbeat();
        _ensureHeartbeatTimer();
      }
      return started;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> release(String owner) async {
    if (!Platform.isAndroid) return;
    final normalizedOwner = owner.trim();
    if (normalizedOwner.isEmpty) return;
    try {
      await _channel.invokeMethod<bool>('release', <String, Object?>{
        'owner': normalizedOwner,
      });
    } on PlatformException {
      // Liberar lease é best effort.
    } finally {
      _owners.remove(normalizedOwner);
      if (_owners.isEmpty) {
        _heartbeatTimer?.cancel();
        _heartbeatTimer = null;
      }
    }
  }

  /// Compatibilidade com chamadas antigas. Novos recursos devem usar leases.
  static Future<bool> start({
    bool usesCamera = true,
    String? statusText,
  }) =>
      acquire(
        owner: _legacyOwner,
        usesCamera: usesCamera,
        statusText: statusText,
      );

  /// Compatibilidade com chamadas antigas. Não encerra leases de outros donos.
  static Future<void> stop() => release(_legacyOwner);

  static Future<void> updateStatus(String text) async {
    if (!Platform.isAndroid || text.trim().isEmpty) return;
    try {
      await _channel.invokeMethod<bool>('updateStatus', <String, Object?>{
        'text': text.trim(),
      });
    } on PlatformException {
      // A notificação é informativa; falhar não encerra o monitor.
    }
  }

  static Future<void> heartbeat() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('heartbeat');
    } on PlatformException {
      // O watchdog nativo detectará a ausência caso o canal esteja indisponível.
    }
  }

  static void _ensureHeartbeatTimer() {
    _heartbeatTimer ??= Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(heartbeat()),
    );
  }

  static Future<BackgroundMonitorStatus> status() async {
    if (!Platform.isAndroid) {
      return const BackgroundMonitorStatus(
        running: false,
        usesCamera: false,
        screenInteractive: true,
        statusText: '',
        startedAtElapsedRealtime: 0,
      );
    }
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>('status');
      if (raw != null) return BackgroundMonitorStatus.fromMap(raw);
    } on PlatformException {
      // Retorna um estado seguro abaixo.
    }
    return const BackgroundMonitorStatus(
      running: false,
      usesCamera: false,
      screenInteractive: true,
      statusText: '',
      startedAtElapsedRealtime: 0,
    );
  }

  static Future<bool> isRunning() async => (await status()).running;

  static Future<bool> consumeResumeRequest() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('consumeResumeRequest') ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> configureRecovery({
    required bool enabled,
    required MonitorSchedule schedule,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('configureRecovery', <String, Object?>{
        'enabled': enabled,
        'schedule': jsonEncode(schedule.toJson()),
      });
    } on PlatformException {
      // O perfil Flutter continua sendo a fonte de verdade.
    }
  }
}
