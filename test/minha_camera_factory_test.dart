import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/video_source_config.dart';
import 'package:vigiaia/sources/minha_camera_mjpeg_source.dart';
import 'package:vigiaia/sources/remote_phone_camera_source.dart';
import 'package:vigiaia/sources/remote_phone_source_factory.dart';

void main() {
  test('QR Minha Câmera seleciona streaming MJPEG com IA no receptor', () async {
    final source = createRemotePhoneVideoSource(
      const VideoSourceConfig(
        type: VideoSourceType.remotePhone,
        remoteBaseUrl: 'http://192.168.0.10:8765/live/0123456789abcdef0123456789abcdef',
      ),
      analysisInterval: const Duration(milliseconds: 800),
    );
    expect(source, isA<MinhaCameraMjpegSource>());
    expect((source as MinhaCameraMjpegSource).emitFrames, isTrue);
    await source.dispose();
  });
  test('modo sem IA mantém fonte MJPEG mas não gera frames de análise', () async {
    final source = createRemotePhoneVideoSource(
      const VideoSourceConfig(
        type: VideoSourceType.remotePhone,
        remoteBaseUrl: 'http://192.168.0.10:8765/live/0123456789abcdef0123456789abcdef',
        analysisEnabled: false,
      ),
      analysisInterval: const Duration(milliseconds: 800),
    );
    expect(source, isA<MinhaCameraMjpegSource>());
    expect((source as MinhaCameraMjpegSource).emitFrames, isFalse);
    await source.dispose();
  });
  test('pareamento Vigia antigo permanece no receptor antigo', () async {
    final source = createRemotePhoneVideoSource(
      const VideoSourceConfig(
        type: VideoSourceType.remotePhone,
        remoteBaseUrl: 'http://192.168.0.10:8766',
        remoteAccessKey: 'AB12CD34EF56',
      ),
      analysisInterval: const Duration(milliseconds: 800),
    );
    expect(source, isA<RemotePhoneCameraSource>());
    await source.dispose();
  });
}
