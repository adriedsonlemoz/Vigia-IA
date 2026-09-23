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

  test('padroes locais priorizam reacao rapida sem zerar confirmacao', () {
    const source = VideoSourceConfig(type: VideoSourceType.localCamera);
    const settings = MonitorSettings();

    expect(source.analysisInterval, const Duration(milliseconds: 400));
    expect(settings.absenceReset, const Duration(seconds: 1));
  });

  test('fonte antiga sem intervalo recebe o novo default de 400 ms', () {
    final restored = VideoSourceConfig.fromJson(<String, dynamic>{
      'type': VideoSourceType.localCamera.name,
    });
    expect(restored.analysisInterval, const Duration(milliseconds: 400));
  });

  test('fonte ESP32 usa endereço local e identificação do módulo', () {
    const source = VideoSourceConfig(
      type: VideoSourceType.esp32,
      remoteBaseUrl: 'http://192.168.4.1',
      remoteAccessKey: 'CHAVE',
      displayName: 'ESP32 Bike',
      cameraId: 'esp32-bike',
    );

    final restored = VideoSourceConfig.fromJson(
      source.toJson().cast<String, dynamic>(),
    );
    expect(restored.type, VideoSourceType.esp32);
    expect(restored.remoteBaseUrl, 'http://192.168.4.1');
    expect(restored.cameraId, 'esp32-bike');
  });

  test('teste temporario da frontal usa identificador dedicado', () {
    const source = VideoSourceConfig(
      type: VideoSourceType.localCamera,
      cameraId: frontCameraTestId,
      displayName: 'Frontal (teste)',
    );

    expect(source.isFrontCameraTest, isTrue);
    final restored = VideoSourceConfig.fromJson(
      source.toJson().cast<String, dynamic>(),
    );
    expect(restored.isFrontCameraTest, isTrue);
  });

}
