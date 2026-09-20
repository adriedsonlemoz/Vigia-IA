import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/session_status.dart';

void main() {
  test('resumo compacto mantém vídeo curto e separa métricas detalhadas', () {
    final status = SessionStatusData(
      sampledAt: DateTime.utc(2026, 9, 20),
      imageSource: 'Celular remoto',
      aiDevice: 'Este celular',
      sourceConnection: 'Rede local / hotspot',
      sourceOnline: true,
      receivedFps: 5.25,
      analyzedFps: 2.5,
      framesReceived: 100,
      framesAnalyzed: 48,
      framesDropped: 52,
      frameWidth: 960,
      frameHeight: 540,
      analysisWidth: 640,
      analysisHeight: 360,
      inferenceMs: 132.4,
      frameDelayMs: 87,
      networkLatencyMs: 21,
    );

    expect(status.frameResolution, '960×540');
    expect(status.analysisResolution, '640×360');
    expect(status.compactVideoSummary, contains('5.3 FPS recebidos'));
    expect(status.compactVideoSummary, contains('2.5 FPS analisados'));
    expect(status.compactVideoSummary, contains('atraso 87 ms'));
  });
}
