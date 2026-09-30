import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/core/video_source_status.dart';
import 'package:vigiaia/models/monitor_ai_pip_status.dart';
import 'package:vigiaia/services/monitor_ai_status_resolver.dart';

void main() {
  const interval = Duration(milliseconds: 800);
  final now = DateTime(2026, 9, 25, 17, 0);

  MonitorAiPipStatus resolve({
    bool aiEnabled = true,
    bool detectorReady = true,
    bool initializing = false,
    bool processing = false,
    VideoSourceState sourceState = VideoSourceState.streaming,
    bool networkSource = false,
    DateTime? lastFrameAt,
    bool possibleAiError = false,
  }) {
    return MonitorAiStatusResolver.resolve(
      aiEnabled: aiEnabled,
      detectorReady: detectorReady,
      initializing: initializing,
      processing: processing,
      sourceState: sourceState,
      networkSource: networkSource,
      lastFrameAt: lastFrameAt ?? now,
      expectedFrameInterval: interval,
      possibleAiError: possibleAiError,
      now: now,
    );
  }

  test('nunca mostra analisando quando a IA esta desligada', () {
    final status = resolve(
      aiEnabled: false,
      processing: true,
    );

    expect(status.state, MonitorAiPipState.disabled);
    expect(status.label, 'IA desligada');
  });

  test('distingue analisando de IA ativa', () {
    expect(
      resolve(processing: true).state,
      MonitorAiPipState.analyzing,
    );
    expect(
      resolve(processing: false).state,
      MonitorAiPipState.active,
    );
  });

  test('aguarda primeiro frame e marca ausencia prolongada', () {
    final waiting = MonitorAiStatusResolver.resolve(
      aiEnabled: true,
      detectorReady: true,
      initializing: false,
      processing: false,
      sourceState: VideoSourceState.streaming,
      networkSource: false,
      lastFrameAt: null,
      expectedFrameInterval: interval,
      now: now,
    );
    final stale = resolve(
      lastFrameAt: now.subtract(const Duration(seconds: 9)),
    );

    expect(waiting.state, MonitorAiPipState.waitingFrames);
    expect(stale.state, MonitorAiPipState.noFrames);
  });

  test('erro de fonte local vira camera indisponivel', () {
    final status = resolve(sourceState: VideoSourceState.error);
    expect(status.state, MonitorAiPipState.cameraUnavailable);
  });

  test('falha de rede vira conexao perdida', () {
    final reconnecting = resolve(
      sourceState: VideoSourceState.reconnecting,
      networkSource: true,
    );
    final error = resolve(
      sourceState: VideoSourceState.error,
      networkSource: true,
    );

    expect(reconnecting.state, MonitorAiPipState.connectionLost);
    expect(error.state, MonitorAiPipState.connectionLost);
  });

  test('detector inesperadamente indisponivel sinaliza possivel erro', () {
    final status = resolve(detectorReady: false);
    expect(status.state, MonitorAiPipState.possibleError);
  });

  test('erro conhecido da IA tem prioridade sobre estado ativo', () {
    final status = resolve(possibleAiError: true);
    expect(status.state, MonitorAiPipState.possibleError);
  });
}
