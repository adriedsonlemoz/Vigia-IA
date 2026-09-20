import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/session_status.dart';

SessionStatusData status({
  bool sourceOnline = true,
  bool sourceConnecting = false,
  double receivedFps = 2.5,
  int framesReceived = 20,
  int framesDroppedProcessing = 0,
  int framesSkippedOptimization = 0,
  int expectedFrameIntervalMs = 400,
  DateTime? sampledAt,
  DateTime? lastFrameReceivedAt,
  double? inferenceMs = 120,
  double? preprocessMs,
  double? primaryInferenceMs,
  double? auxiliaryInferenceMs,
  double? postprocessMs,
  double? totalProcessingMs,
  double? endToEndMs,
  int detectorRuns = 0,
  int auxiliaryInferenceRuns = 0,
  int detailScansSkippedByBudget = 0,
  int? frameDelayMs = 80,
  int? networkLatencyMs,
}) {
  final now = sampledAt ?? DateTime.utc(2026, 9, 20, 3);
  return SessionStatusData(
    sampledAt: now,
    imageSource: 'Celular remoto',
    aiDevice: 'Este celular',
    sourceConnection: 'Rede local / hotspot',
    sourceOnline: sourceOnline,
    sourceConnecting: sourceConnecting,
    receivedFps: receivedFps,
    analyzedFps: 2.2,
    framesReceived: framesReceived,
    framesAnalyzed: 18,
    framesDropped: framesDroppedProcessing + framesSkippedOptimization,
    framesDroppedProcessing: framesDroppedProcessing,
    framesSkippedOptimization: framesSkippedOptimization,
    expectedFrameIntervalMs: expectedFrameIntervalMs,
    lastFrameReceivedAt: lastFrameReceivedAt ?? now.subtract(const Duration(milliseconds: 150)),
    frameWidth: 960,
    frameHeight: 540,
    analysisWidth: 640,
    analysisHeight: 360,
    inferenceMs: inferenceMs,
    preprocessMs: preprocessMs,
    primaryInferenceMs: primaryInferenceMs,
    auxiliaryInferenceMs: auxiliaryInferenceMs,
    postprocessMs: postprocessMs,
    totalProcessingMs: totalProcessingMs,
    endToEndMs: endToEndMs,
    detectorRuns: detectorRuns,
    auxiliaryInferenceRuns: auxiliaryInferenceRuns,
    detailScansSkippedByBudget: detailScansSkippedByBudget,
    frameDelayMs: frameDelayMs,
    networkLatencyMs: networkLatencyMs,
  );
}

void main() {
  test('resumo compacto mantém vídeo curto e separa métricas detalhadas', () {
    final value = status(
      receivedFps: 5.25,
      frameDelayMs: 87,
      networkLatencyMs: 21,
    );

    expect(value.frameResolution, '960×540');
    expect(value.analysisResolution, '640×360');
    expect(value.compactVideoSummary, contains('5.3 FPS recebidos'));
    expect(value.compactVideoSummary, contains('2.2 FPS analisados'));
    expect(value.compactVideoSummary, contains('atraso 87 ms'));
  });

  test('sessão saudável respeita o intervalo configurado da fonte', () {
    final value = status(
      receivedFps: 2.3,
      expectedFrameIntervalMs: 400,
      inferenceMs: 180,
      frameDelayMs: 90,
    );

    expect(value.expectedReceivedFps, 2.5);
    expect(value.health.state, SessionHealthState.healthy);
    expect(value.health.bottleneck, SessionBottleneck.none);
  });

  test('imagem antiga torna a sessão instável e aponta captura ou rede', () {
    final now = DateTime.utc(2026, 9, 20, 3);
    final value = status(
      sampledAt: now,
      lastFrameReceivedAt: now.subtract(const Duration(seconds: 6)),
    );

    expect(value.health.state, SessionHealthState.unstable);
    expect(value.health.issues.any((issue) => issue.code == 'frame_frozen'), isTrue);
  });

  test('latência alta aponta rede como gargalo', () {
    final value = status(networkLatencyMs: 1200);

    expect(value.health.state, SessionHealthState.unstable);
    expect(value.health.bottleneck, SessionBottleneck.network);
  });

  test('pulos por otimização não são tratados como perda de desempenho', () {
    final value = status(
      framesReceived: 100,
      framesDroppedProcessing: 0,
      framesSkippedOptimization: 80,
    );

    expect(value.processingDropPercent, 0);
    expect(
      value.health.issues.any((issue) => issue.code.startsWith('processing_drop_')),
      isFalse,
    );
  });

  test('perdas por IA ocupada identificam gargalo de processamento', () {
    final value = status(
      framesReceived: 100,
      framesDroppedProcessing: 55,
      framesSkippedOptimization: 0,
    );

    expect(value.processingDropPercent, 55);
    expect(value.health.state, SessionHealthState.unstable);
    expect(value.health.bottleneck, SessionBottleneck.ai);
    expect(
      value.health.issues.any((issue) => issue.code == 'processing_drop_critical'),
      isTrue,
    );
  });

  test('fonte reconectando pede atenção sem marcar desconectado definitivo', () {
    final value = status(
      sourceOnline: false,
      sourceConnecting: true,
      receivedFps: 0,
      framesReceived: 0,
      lastFrameReceivedAt: DateTime.utc(2026, 9, 20, 3),
    );

    expect(value.health.state, SessionHealthState.attention);
    expect(value.health.issues.first.code, 'source_reconnecting');
  });
  test('pipeline calcula orçamento, folga e maior etapa local', () {
    final value = status(
      expectedFrameIntervalMs: 400,
      preprocessMs: 24,
      primaryInferenceMs: 150,
      auxiliaryInferenceMs: 35,
      postprocessMs: 31,
      totalProcessingMs: 240,
      endToEndMs: 315,
      detectorRuns: 2,
      auxiliaryInferenceRuns: 1,
      detailScansSkippedByBudget: 3,
    );

    expect(value.processingBudgetUsagePercent, 60);
    expect(value.processingHeadroomMs, 160);
    expect(value.pipelineHotspot, 'Inferência principal');
    expect(value.detectorRuns, 2);
    expect(value.detailScansSkippedByBudget, 3);
  });

  test('pipeline acima do intervalo aparece na saúde da sessão', () {
    final value = status(
      expectedFrameIntervalMs: 400,
      inferenceMs: 250,
      totalProcessingMs: 650,
    );

    expect(value.health.state, SessionHealthState.unstable);
    expect(
      value.health.issues.any((issue) => issue.code == 'pipeline_budget_critical'),
      isTrue,
    );
  });

}
