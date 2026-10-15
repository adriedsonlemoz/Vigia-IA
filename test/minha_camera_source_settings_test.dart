import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/video_source_config.dart';

void main() {
  const url = 'http://192.168.43.1:8765/live/0123456789abcdef0123456789abcdef';
  test('IA é opcional e configuração persiste ao reabrir', () {
    const config = VideoSourceConfig(
      type: VideoSourceType.remotePhone,
      remoteBaseUrl: url,
      displayName: 'Minha Câmera',
      analysisEnabled: false,
    );
    final restored = VideoSourceConfig.fromJson(config.toJson());
    expect(restored.analysisEnabled, isFalse);
    expect(restored.remoteBaseUrl, url);
    expect(config.copyWith(analysisEnabled: true).analysisEnabled, isTrue);
    expect(VideoSourceConfig(type: VideoSourceType.remotePhone).analysisEnabled, isTrue);
  });
  test('export sem dados sensíveis omite URL que inclui token', () {
    const config = VideoSourceConfig(type: VideoSourceType.remotePhone, remoteBaseUrl: url);
    expect(config.toJson(includeSensitive: false)['remoteBaseUrl'], isNull);
  });
}
