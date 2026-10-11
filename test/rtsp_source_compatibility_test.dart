import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/video_source_config.dart';
import 'package:vigiaia/services/rtsp_diagnostics_service.dart';

void main() {
  test('configuração RTSP preserva modo de software em JSON/copyWith', () {
    const initial = VideoSourceConfig(
      type: VideoSourceType.rtsp,
      rtspUrl: 'rtsp://192.168.1.4:554/stream',
      rtspSoftwareDecoding: true,
    );
    final restored = VideoSourceConfig.fromJson(initial.toJson().cast<String, dynamic>());
    expect(restored.rtspSoftwareDecoding, isTrue);
    expect(restored.copyWith(displayName: 'Teste').rtspSoftwareDecoding, isTrue);
    expect(VideoSourceConfig.fromJson(<String, dynamic>{'type': 'rtsp'})
        .rtspSoftwareDecoding, isFalse);
  });

  test('telemetria retém apenas host e não credenciais/caminho', () {
    expect(RtspDiagnosticsService.safeHost(
      'rtsp://usuario:senha@192.168.1.5:8554/live?token=abc',
    ), '192.168.1.5');
    expect(RtspDiagnosticsService.safeHost('file:///segredo'), isEmpty);
  });
}
