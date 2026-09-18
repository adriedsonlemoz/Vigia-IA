import 'package:vigiaia/models/video_source_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fonte de celular remoto é serializável', () {
    const original = VideoSourceConfig(
      type: VideoSourceType.remotePhone,
      remoteBaseUrl: 'http://192.168.0.20:8765',
      remoteAccessKey: 'ABC123',
      displayName: 'Celular da garagem',
      cameraId: 'garagem',
    );

    final restored = VideoSourceConfig.fromJson(original.toJson().cast<String, dynamic>());
    expect(restored.type, VideoSourceType.remotePhone);
    expect(restored.remoteBaseUrl, 'http://192.168.0.20:8765');
    expect(restored.remoteAccessKey, 'ABC123');
    expect(restored.displayName, 'Celular da garagem');
    expect(restored.cameraId, 'garagem');
  });

  test('serialização sem dados sensíveis omite chave e RTSP', () {
    const source = VideoSourceConfig(
      type: VideoSourceType.rtsp,
      rtspUrl: 'rtsp://usuario:senha@192.168.0.10/stream',
      remoteAccessKey: 'SEGREDO',
    );

    final json = source.toJson(includeSensitive: false);
    expect(json['rtspUrl'], isNull);
    expect(json['remoteAccessKey'], isNull);
  });
}
