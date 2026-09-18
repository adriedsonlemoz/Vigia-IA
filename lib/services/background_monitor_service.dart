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
  });

  final bool running;
  final bool usesCamera;
  final bool screenInteractive;
  final String statusText;
  final int startedAtElapsedRealtime;

  factory BackgroundMonitorStatus.fromMap(Map<Object?, Object?> map) {
    return BackgroundMonitorStatus(
      running: map['running'] as bool? ?? false,
      usesCamera: map['usesCamera'] as bool? ?? false,
      screenInteractive: map['screenInteractive'] as bool? ?? true,
      statusText: map['statusText'] as String? ?? '',
      startedAtElapsedRealtime:
          (map['startedAtElapsedRealtime'] as num?)?.toInt() ?? 0,
    );
  }
}

class BackgroundMonitorService {
  BackgroundMonitorService._();

  static const MethodChannel _channel =
      MethodChannel('vigiaia/background');

  static Future<bool> start({
    bool usesCamera = true,
    String? statusText,
  }) async {
    if (!Platform.isAndroid) return false;
    try {
      final arguments = <String, Object?>{'usesCamera': usesCamera};
      if (statusText != null) {
        arguments['statusText'] = statusText;
      }
      return await _channel.invokeMethod<bool>('start', arguments) ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('stop');
    } on PlatformException {
      // Encerrar o serviço é best effort e não deve derrubar o monitor.
    }
  }

  static Future<void> updateStatus(String text) async {
    if (!Platform.isAndroid || text.trim().isEmpty) return;
    try {
      await _channel.invokeMethod<bool>('updateStatus', <String, Object?>{
        'text': text.trim(),
      });
    } on PlatformException {
      // A notificação é informativa; falhar ao atualizá-la não encerra o monitor.
    }
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
      // A configuração continua salva no perfil Flutter mesmo se o canal nativo falhar.
    }
  }
}
