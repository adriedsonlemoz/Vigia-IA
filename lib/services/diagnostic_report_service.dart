import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../core/app_metadata.dart';
import '../models/system_health.dart';
import '../utils/storage_size_formatter.dart';
import 'error_log_service.dart';
import 'esp32_telemetry_service.dart';
import 'native_platform_service.dart';
import 'performance_telemetry_service.dart';
import 'system_health_service.dart';

class DiagnosticReport {
  DiagnosticReport({
    required this.generatedAt,
    required this.health,
    this.audioDiagnostics = const {},
    this.alertEvents = const [],
    this.esp32Modules = const [],
    required List<ErrorLogEntry> entries,
  }) : entries = List<ErrorLogEntry>.unmodifiable(entries);

  final DateTime generatedAt;
  final SystemHealthSnapshot health;
  final Map<String, Object?> audioDiagnostics;
  final List<Map<String, Object?>> alertEvents;
  final List<Map<String, Object?>> esp32Modules;
  final List<ErrorLogEntry> entries;

  int get problemCount => entries
      .where((entry) => entry.level != ErrorLogLevel.info)
      .length;

  String toText() {
    final h = health;
    final buffer = StringBuffer()
      ..writeln('Vigia IA - Diagnóstico')
      ..writeln('Versão: ${AppMetadata.version}+${AppMetadata.build}')
      ..writeln('Gerado em: ${generatedAt.toIso8601String()}')
      ..writeln()
      ..writeln('=== ESTADO ATUAL ===')
      ..writeln('Monitoramento IA: ${_yesNo(h.monitoringActive)}')
      ..writeln('Serviço Android: ${_activeInactive(h.androidServiceActive)}')
      ..writeln('Heartbeat Flutter: ${_yesNo(h.flutterHeartbeatFresh)}')
      ..writeln('Leases do serviço: ${h.androidServiceLeaseCount}')
      ..writeln('Câmera/fonte: ${_activeInactive(h.cameraActive)} (${h.source})')
      ..writeln('Integridade da câmera: ${h.cameraHealth.name}')
      ..writeln('Frames chegando: ${_yesNo(h.framesActive)}')
      ..writeln('IA pronta: ${_yesNo(h.aiReady)}')
      ..writeln('IA processando: ${_yesNo(h.aiActive)}')
      ..writeln('FPS: ${h.framesActive ? h.fps.toStringAsFixed(1) : 'sem amostra'}')
      ..writeln('Servidor LAN: ${_activeInactive(h.lanServerActive)}')
      ..writeln('Frames LAN recentes: ${_yesNo(h.lanFramesActive)}')
      ..writeln('Transmissão LAN operacional: ${_yesNo(h.lanActive)}')
      ..writeln('Clientes LAN: ${h.connectedClients}')
      ..writeln('Último frame LAN: ${h.lanLastFrameAt?.toIso8601String() ?? 'nenhum'}')
      ..writeln('Segundo plano solicitado: ${_yesNo(h.backgroundRequested)}')
      ..writeln('Segundo plano operacional: ${_yesNo(h.backgroundOperational)}')
      ..writeln('Tela interativa: ${_yesNo(h.screenInteractive)}')
      ..writeln('Último frame: ${h.lastFrameAt?.toIso8601String() ?? 'nenhum'}')
      ..writeln()
      ..writeln('=== PERMISSÕES ===')
      ..writeln('Câmera: ${h.cameraPermissionRequired ? _grantedDenied(h.cameraPermissionGranted) : 'não exigida para a fonte atual'}')
      ..writeln(
        'Rede local: ${h.localNetworkPermissionRequired ? _grantedDenied(h.localNetworkPermissionGranted) : 'não exigida pelo Android'}',
      )
      ..writeln('Notificações: ${_grantedDenied(h.notificationsAllowed)}')
      ..writeln()
      ..writeln('=== DISPOSITIVO ===')
      ..writeln('Bateria: ${h.batteryPercent == null ? 'indisponível' : '${h.batteryPercent}%'}')
      ..writeln(
        'Carregamento: ${h.batteryCharging == null ? 'indisponível' : h.batteryCharging! ? '${h.batteryPowerSource ?? 'carregando'}${h.batteryCurrentMa == null ? '' : ' • ${h.batteryCurrentMa!.toStringAsFixed(0)} mA'}' : 'usando bateria'}',
      )
      ..writeln(
        'Temperatura da bateria: ${h.batteryTemperatureC == null ? 'indisponível' : '${h.batteryTemperatureC!.toStringAsFixed(1)} °C'}',
      )
      ..writeln(
        'Tela/brilho: ${h.screenBrightnessPercent == null ? 'indisponível' : '${h.screenBrightnessPercent}%'}${h.screenDimmedByBike ? ' • reduzido pelo Modo Bike' : ''}',
      )
      ..writeln(
        'CPU do Vigia IA: ${h.appCpuPercent == null ? 'indisponível' : '${h.appCpuPercent!.toStringAsFixed(1)}%'}',
      )
      ..writeln(
        'Memória do processo: ${_formatBytes(h.memoryUsedBytes)}',
      )
      ..writeln(
        'Memória disponível no aparelho: ${_formatBytes(h.memoryAvailableBytes)}',
      )
      ..writeln(
        'Memória total do aparelho: ${_formatBytes(h.memoryTotalBytes)}',
      )
      ..writeln(
        'Armazenamento livre: ${_formatBytes(h.freeStorageBytes)}',
      )
      ..writeln(
        'Armazenamento total: ${_formatBytes(h.totalStorageBytes)}',
      );

    if (h.lanError?.isNotEmpty == true) {
      buffer.writeln('Erro LAN: ${h.lanError}');
    }

    buffer
      ..writeln()
      ..writeln('=== MÓDULOS ESP32 (${esp32Modules.length}) ===');
    if (esp32Modules.isEmpty) {
      buffer.writeln('Nenhum módulo ESP32 cadastrado.');
    } else {
      for (final module in esp32Modules) {
        buffer.writeln(jsonEncode(module));
      }
    }

    buffer
      ..writeln()
      ..writeln('=== REGISTROS TÉCNICOS (${entries.length}) ===');
    if (entries.isEmpty) {
      buffer.writeln('Nenhum registro técnico armazenado.');
    } else {
      for (final entry in entries) {
        buffer
          ..writeln(
            '[${entry.timestamp.toIso8601String()}] '
            '${entry.level.name.toUpperCase()} | ${entry.source}',
          )
          ..writeln(entry.message);
        if (entry.context.isNotEmpty) {
          buffer.writeln(
            entry.context.entries
                .map((item) => '${item.key}=${item.value}')
                .join(' | '),
          );
        }
        if (entry.details?.isNotEmpty == true) buffer.writeln(entry.details);
        buffer.writeln('---');
      }
    }
    buffer
      ..writeln('\n=== ÁUDIO ===')
      ..writeln('Estado: ${audioDiagnostics['state'] ?? 'indisponível'}')
      ..writeln('Último resultado: ${audioDiagnostics['lastPlaybackResult'] ?? 'indisponível'}')
      ..writeln('Origem: ${audioDiagnostics['lastSource'] ?? 'indisponível'}')
      ..writeln('Fallback para áudio integrado: ${audioDiagnostics['lastPlaybackUsedFallback'] == true ? 'sim' : 'não'}')
      ..writeln('Motivo do fallback: ${audioDiagnostics['lastFallbackReason'] ?? 'nenhum'}')
      ..writeln('Erro: ${audioDiagnostics['lastErrorCode'] ?? 'nenhum'}')
      ..writeln('Detalhe: ${audioDiagnostics['lastError'] ?? 'nenhum'}')
      ..writeln('Etapa: ${audioDiagnostics['lastErrorPhase'] ?? 'indisponível'}')
      ..writeln('Foco: ${audioDiagnostics['lastFocusResultName'] ?? 'indisponível'}')
      ..writeln('Volume: ${audioDiagnostics['mediaVolume'] ?? '?'} / ${audioDiagnostics['mediaMaxVolume'] ?? '?'}')
      ..writeln('Dados técnicos: ${jsonEncode(audioDiagnostics)}');
    for (final event in alertEvents) { buffer.writeln(jsonEncode(event)); }
    return buffer.toString();
  }

  static String _yesNo(bool value) => value ? 'sim' : 'não';
  static String _activeInactive(bool value) => value ? 'ativo' : 'inativo';
  static String _grantedDenied(bool value) => value ? 'concedida' : 'não concedida';
  static String _formatBytes(int? bytes) =>
      bytes == null ? 'indisponível' : StorageSizeFormatter.formatBytes(bytes);
}

class DiagnosticReportService {
  DiagnosticReportService({
    SystemHealthService? health,
    ErrorLogService? logs,
    NativePlatformService? native,
  })  : _health = health ?? SystemHealthService(),
        _logs = logs ?? ErrorLogService.instance,
        _native = native ?? NativePlatformService.instance;

  final SystemHealthService _health;
  final ErrorLogService _logs;
  final NativePlatformService _native;

  Future<DiagnosticReport> capture() async {
    await _logs.initialize();
    await Esp32TelemetryService.instance.initialize();
    final health = await _health.collect();
    return DiagnosticReport(
      generatedAt: health.createdAt,
      health: health,
      audioDiagnostics: await _native.audioDiagnostics(),
      alertEvents: PerformanceTelemetryService.instance.createReport().alertEvents,
      esp32Modules: Esp32TelemetryService.instance.diagnostics,
      entries: List<ErrorLogEntry>.of(_logs.entries),
    );
  }

  Future<String?> export(
    DiagnosticReport report, {
    Directory? directory,
    bool chooseLocation = false,
  }) async {
    final fileName =
        'vigiaia_diagnostico_${_stamp(report.generatedAt)}.txt';
    if (directory != null) {
      final exports = Directory(
        '${directory.path}${Platform.pathSeparator}exports${Platform.pathSeparator}diagnostico',
      );
      await exports.create(recursive: true);
      final file = File(
        '${exports.path}${Platform.pathSeparator}$fileName',
      );
      await file.writeAsString(report.toText(), flush: true);
      return file.path;
    }

    final bytes = Uint8List.fromList(utf8.encode(report.toText()));
    if (chooseLocation) {
      return _native.saveBytesWithPicker(
        fileName: fileName,
        mimeType: 'text/plain',
        bytes: bytes,
      );
    }
    return _native.saveBytesToDownloads(
      fileName: fileName,
      mimeType: 'text/plain',
      bytes: bytes,
    );
  }

  Future<bool> share(DiagnosticReport report) {
    return _native.shareText(
      subject: 'Vigia IA - Diagnóstico',
      text: report.toText(),
    );
  }

  String _stamp(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}${two(value.month)}${two(value.day)}-'
        '${two(value.hour)}${two(value.minute)}${two(value.second)}';
  }
}
