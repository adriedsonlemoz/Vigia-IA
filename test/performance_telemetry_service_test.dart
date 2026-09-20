import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/performance_telemetry_service.dart';

PerformanceFrameSample sample({
  required DateTime timestamp,
  double sourceConversionMs = 12,
  double isolateMs = 20,
  double resizeMs = 30,
  double tensorMs = 40,
  double liteRtMs = 200,
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

    expect(report.likelyBottleneck, 'LiteRT / TFLite puro');
    final text = report.toText();
    expect(text, contains('Xiaomi Teste'));
    expect(text, contains('Android: 16 (SDK 36)'));
    expect(text, contains('OCORRÊNCIAS IMPORTANTES'));
    expect(text, contains('LiteRT / TFLite puro'));
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
}
