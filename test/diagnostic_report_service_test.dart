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
    audioDiagnostics: const {
      'state': 'failed',
      'lastPlaybackResult': 'failed',
      'lastErrorCode': 'MEDIA_ERROR_UNSUPPORTED',
      'lastErrorPhase': 'prepare_async',
      'lastFocusResultName': 'GRANTED',
      'mediaVolume': 6,
      'mediaMaxVolume': 15,
    },
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
