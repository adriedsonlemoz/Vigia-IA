import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/system_health.dart';
import 'package:vigiaia/services/diagnostic_report_service.dart';
import 'package:vigiaia/services/error_log_service.dart';

DiagnosticReport buildReport() {
  final generated = DateTime(2026, 9, 17, 22, 15, 30);
  return DiagnosticReport(
    generatedAt: generated,
    health: SystemHealthSnapshot(
      createdAt: generated,
      source: 'Câmera do dispositivo',
      monitoringActive: true,
      androidServiceActive: true,
      cameraActive: false,
      framesActive: false,
      aiReady: true,
      aiActive: false,
      lanServerActive: true,
      lanFramesActive: false,
      lanActive: false,
      connectedClients: 0,
      backgroundRequested: true,
      backgroundOperational: false,
      cameraPermissionGranted: true,
      localNetworkPermissionRequired: true,
      localNetworkPermissionGranted: false,
      notificationsAllowed: true,
      freeStorageBytes: 74_500_000_000,
      totalStorageBytes: 128_000_000_000,
      memoryUsedBytes: 820_000_000,
    ),
    mapDiagnostics: const {
      'gpsAvailability': 'ready',
      'gpsStreamActive': true,
      'gpsConsumers': 1,
      'gpsUpdatesPerMinute': 24,
      'gpsStreamStarts': 1,
      'gpsStreamErrors': 0,
      'gpsSampleAgeSeconds': 2,
      'accuracyMeters': 6.3,
      'rejectedGpsPoints': 3,
      'lastRejectionReason': 'staleReading',
      'recording': true,
      'paused': false,
      'navigating': true,
      'recordedPoints': 440,
      'offlineMode': 'offline',
      'offlinePackages': 2,
      'offlinePackageSelected': true,
      'offlineBusy': false,
      'offlineOpenErrors': 1,
      'latitude': -19.9,
      'longitude': -45.1,
      'path': '/dados/segredo.mbtiles',
    },
    rtspDiagnostics: const {
      'stage': 'preview_requested',
      'host': '192.168.1.5',
      'attemptAtMs': 1791760000000,
      'updatedAtMs': 1791760001000,
      'active': true,
      'lastExitReason': 'NATIVE_CRASH',
      'lastExitAtMs': 1791760002000,
      'lastExitStatus': 11,
    },
    audioDiagnostics: const {
      'state': 'failed',
      'lastPlaybackResult': 'failed',
      'lastErrorCode': 'MEDIA_ERROR_UNSUPPORTED',
      'lastErrorPhase': 'prepare_async',
      'lastFocusResultName': 'GRANTED',
      'mediaVolume': 6,
      'mediaMaxVolume': 15,
    },
    esp32Modules: const [
      <String, Object?>{
        'id': 'esp32-rear',
        'name': 'ESP32 traseiro',
        'runtime': <String, Object?>{'state': 'online', 'rssiDbm': -61},
      },
    ],
    entries: [
      ErrorLogEntry(
        id: '1',
        timestamp: generated,
        level: ErrorLogLevel.warning,
        source: 'Teste',
        message: 'Frames congelados',
      ),
    ],
  );
}

void main() {
  test('gera diagnostico com os mesmos estados do snapshot', () {
    final text = buildReport().toText();
    expect(text, contains('Serviço Android: ativo'));
    expect(text, contains('Frames chegando: não'));
    expect(text, contains('IA processando: não'));
    expect(text, contains('Servidor LAN: ativo'));
    expect(text, contains('Frames LAN recentes: não'));
    expect(text, contains('Transmissão LAN operacional: não'));
    expect(text, contains('Rede local: não concedida'));
    expect(text, contains('Armazenamento livre: 74,5 GB'));
    expect(text, contains('Frames congelados'));
    expect(text, contains('Erro: MEDIA_ERROR_UNSUPPORTED'));
    expect(text, contains('Etapa: prepare_async'));
    expect(text, contains('=== MÓDULOS ESP32 (1) ==='));
    expect(text, contains('=== RTSP / ENCERRAMENTO ANDROID ==='));
    expect(text, contains('Etapa persistida: preview_requested'));
    expect(text, contains('Última saída Android após a tentativa: NATIVE_CRASH'));
    expect(text, isNot(contains('senha@')));
    expect(text, contains('esp32-rear'));
    expect(text, contains('=== VIGIA MAPS / GPS ==='));
    expect(text, contains('Amostras GPS aceitas (último minuto): 24'));
    expect(text, contains('Erros ao abrir MBTiles nesta sessão: 1'));
    expect(text, contains('Tela apagada: não'));
    expect(text, isNot(contains('/dados/segredo.mbtiles')));
    expect(text, isNot(contains('-19.9')));
    expect(text, isNot(contains('-45.1')));
    expect(text, contains('online'));
  });

  test('exportacao grava exatamente o texto do diagnostico', () async {
    final temp = await Directory.systemTemp.createTemp('vigiaia_diag_test_');
    addTearDown(() => temp.delete(recursive: true));
    final report = buildReport();
    final service = DiagnosticReportService();

    final path = await service.export(report, directory: temp);
    expect(path, isNotNull);
    final file = File(path!);

    expect(await file.exists(), isTrue);
    expect(await file.readAsString(), report.toText());
    expect(path, contains('vigiaia_diagnostico_'));
  });
}
