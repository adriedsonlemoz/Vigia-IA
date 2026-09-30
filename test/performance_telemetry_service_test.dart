import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/performance_telemetry_service.dart';

PerformanceFrameSample sample({
  required DateTime timestamp,
  double sourceConversionMs = 12,
  double isolateMs = 20,
  double resizeMs = 30,
  double tensorMs = 40,
  double liteRtMs = 200,
  double tensorTransferMs = 0,
  double totalMs = 340,
}) =>
    PerformanceFrameSample(
      timestamp: timestamp,
      imageSource: 'Câmera deste celular',
      detectorDiagnostics: 'EfficientDet Lite0',
      frameWidth: 720,
      frameHeight: 480,
      analysisWidth: 640,
      analysisHeight: 426,
      receivedFps: 2.5,
      analyzedFps: 2.2,
      framesReceived: 10,
      framesAnalyzed: 9,
      framesDroppedProcessing: 1,
      framesSkippedOptimization: 0,
      detectorRuns: 1,
      auxiliaryInferenceRuns: 0,
      expectedFrameIntervalMs: 400,
      deviceManufacturer: 'Xiaomi',
      deviceModel: 'Teste',
      androidVersion: '16',
      androidSdk: 36,
      sourceConversionMs: sourceConversionMs,
      isolateTransferAndQueueMs: isolateMs,
      resizeLetterboxMs: resizeMs,
      tensorBuildMs: tensorMs,
      liteRtMs: liteRtMs,
      tensorTransferMs: tensorTransferMs,
      totalProcessingMs: totalMs,
      cpuPercent: 35,
      batteryTemperatureC: 38,
    );

void main() {
  test('percentis resumem as etapas sem confundir maximo com mediana', () {
    final summary = PerformanceStageSummary.fromValues(
      <double>[10, 20, 30, 40, 50],
    );

    expect(summary.count, 5);
    expect(summary.mean, 30);
    expect(summary.minimum, 10);
    expect(summary.maximum, 50);
    expect(summary.p50, 30);
    expect(summary.p90, 50);
  });

  test('relatorio identifica LiteRT como gargalo e exporta contexto', () {
    final start = DateTime.utc(2026, 9, 20, 12);
    final report = PerformanceTelemetryReport(
      generatedAt: start.add(const Duration(minutes: 1)),
      sessionStartedAt: start,
      samples: <PerformanceFrameSample>[
        sample(timestamp: start, liteRtMs: 900, totalMs: 1100),
        sample(
          timestamp: start.add(const Duration(seconds: 1)),
          liteRtMs: 1000,
          totalMs: 1200,
        ),
      ],
      deepTraceSamples: const <PerformanceFrameSample>[],
      deepTraceStartedAt: null,
      deepTraceEndedAt: null,
    );

    expect(report.likelyBottleneck, 'LiteRT / TFLite nativo');
    final text = report.toText();
    expect(text, contains('Xiaomi Teste'));
    expect(text, contains('Android: 16 (SDK 36)'));
    expect(text, contains('OCORRÊNCIAS IMPORTANTES'));
    expect(text, contains('LiteRT / TFLite nativo'));
    expect(report.toCsv(), contains('liteRtMs'));
    expect(report.toJsonText(), contains('"likelyBottleneck"'));
  });

  test('diagnostico profundo tem prioridade sobre amostra normal', () {
    final start = DateTime.utc(2026, 9, 20, 12);
    final report = PerformanceTelemetryReport(
      generatedAt: start,
      sessionStartedAt: start,
      samples: <PerformanceFrameSample>[
        sample(timestamp: start, liteRtMs: 900),
      ],
      deepTraceSamples: <PerformanceFrameSample>[
        sample(timestamp: start, liteRtMs: 90, tensorMs: 500),
      ],
      deepTraceStartedAt: start,
      deepTraceEndedAt: start.add(const Duration(seconds: 30)),
    );

    expect(report.analysisSamples, hasLength(1));
    expect(report.likelyBottleneck, 'Montagem do tensor');
  });
  test('transferência não é atribuída à inferência nativa e CSV mantém colunas alinhadas', () {
    final start = DateTime.utc(2026, 9, 21);
    final report = PerformanceTelemetryReport(
      generatedAt: start, sessionStartedAt: start,
      samples: [sample(timestamp: start, liteRtMs: 50, tensorTransferMs: 700, totalMs: 900)],
      deepTraceSamples: const [], deepTraceStartedAt: null, deepTraceEndedAt: null,
      audioDiagnostics: const {
        'state': 'failed',
        'lastError': 'MEDIA_ERROR_UNKNOWN / MEDIA_ERROR_MALFORMED',
        'lastErrorCode': 'MEDIA_ERROR_MALFORMED',
        'lastErrorPhase': 'prepare_async',
        'lastSource': 'override',
        'lastFocusResultName': 'FAILED',
        'mediaVolume': 7,
        'mediaMaxVolume': 15,
      },
      alertEvents: const [{'event': 'tts_started'}],
    );
    expect(report.likelyBottleneck, 'Transferência dos tensores + API Dart');
    final json = jsonDecode(report.toJsonText()) as Map<String, dynamic>;
    expect(json['schemaVersion'], 3);
    expect(json['audioDiagnostics']['lastErrorCode'], 'MEDIA_ERROR_MALFORMED');
    expect(json['alertEvents'].first['event'], 'tts_started');
    expect(report.toText(), contains('Etapa: prepare_async'));
    expect(report.toText(), contains('Foco de áudio: FAILED'));
    final rows = report.toCsv().trim().split('\n');
    final columns = rows[0].split(',');
    final values = rows[1].split(',');
    expect(values.length, columns.length);
    expect(double.parse(values[columns.indexOf('liteRtMs')]), 50);
    expect(double.parse(values[columns.indexOf('tensorTransferMs')]), 700);
  });

}
