import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/camera_endpoint.dart';
import 'package:vigiaia/models/camera_source_selector.dart';
import 'package:vigiaia/models/video_source_config.dart';

void main() {
  test('Minha Câmera privada é fonte remotePhone, nunca RTSP', () {
    final source = sourceForRegisteredCamera(const CameraEndpoint(
      id: 'minha', name: 'Retrovisor', type: CameraEndpointType.remotePhone,
      address: 'http://192.168.43.1:8765/live/0123456789abcdef0123456789abcdef',
      accessKey: '0123456789abcdef0123456789abcdef',
    ), const Duration(milliseconds: 800));
    expect(source.type, VideoSourceType.remotePhone);
    expect(source.rtspUrl, isNull);
    expect(source.remoteBaseUrl, contains('/live/'));
    expect(source.cameraId, 'minha');
    expect(source.analysisInterval.inMilliseconds, 800);
  });
  test('câmera RTSP mantém o protocolo RTSP', () {
    final source = sourceForRegisteredCamera(const CameraEndpoint(
      id: 'rtsp', name: 'RTSP', type: CameraEndpointType.rtsp,
      address: 'rtsp://192.168.1.8/stream',
    ), const Duration(milliseconds: 500));
    expect(source.type, VideoSourceType.rtsp);
    expect(source.rtspUrl, startsWith('rtsp://'));
  });
  test('câmera local preserva seleção sem pedir URL remota', () {
    final source = sourceForRegisteredCamera(const CameraEndpoint(
      id: '__local__', name: 'Celular', type: CameraEndpointType.local,
    ), const Duration(milliseconds: 400));
    expect(source.type, VideoSourceType.localCamera);
    expect(source.remoteBaseUrl, isNull);
  });
}
