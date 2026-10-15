#!/usr/bin/env python3
"""Regressão estrutural (não substitui flutter test e testes físicos)."""
from pathlib import Path
R=Path(__file__).resolve().parents[1]

def file(p): return (R/p).read_text(encoding='utf-8')

def check():
    for path in (
      'lib/services/minha_camera_live_url.dart',
      'lib/services/minha_camera_mjpeg_parser.dart',
      'lib/sources/minha_camera_mjpeg_source.dart',
      'test/minha_camera_live_url_test.dart',
      'test/minha_camera_mjpeg_parser_test.dart',
      'test/minha_camera_source_settings_test.dart'):
      assert (R/path).is_file(), path
    qr=file('lib/services/remote_camera_pairing_service.dart')
    assert 'MinhaCameraLiveUrl.parse(raw)' in qr
    assert "name: 'Minha Câmera'" in qr
    scanner=file('lib/screens/phone_pairing_scanner_screen.dart')
    assert 'RemoteCameraPairingService.decode(raw)' in scanner
    source=file('lib/sources/minha_camera_mjpeg_source.dart')
    for code in ('Multipart', 'multipart/x-mixed-replace', 'MinhaCameraMjpegParser()',
       'compute<Uint8List, Map<String, Object>?>', 'DataUsageService.instance.record',
       'VideoSourceState.reconnecting', 'emitFrames && !_decoding', 'stop()',
       'client.getUrl(MinhaCameraLiveUrl.parse(liveUrl)!)'):
      if code == 'Multipart': continue
      assert code in source,code
    assert 'codecStatus' not in source
    factory=file('lib/sources/remote_phone_source_factory.dart')
    assert 'MinhaCameraMjpegSource(' in factory and 'MinhaCameraLiveUrl.isValid(' in factory
    for p in ('lib/controllers/monitor_controller.dart', 'lib/controllers/secondary_camera_controller.dart'):
       assert 'createRemotePhoneVideoSource(' in file(p),p
    config=file('lib/models/video_source_config.dart')
    assert "'analysisEnabled': analysisEnabled" in config
    assert 'includeSensitive || !MinhaCameraLiveUrl.isValid(remoteBaseUrl)' in config
    assert 'analysisEnabled: json' in config
    connect=file('lib/screens/monitor_connect_screen.dart')
    assert 'RemoteCameraPairingService.decode(raw)' in connect
    assert 'SwitchListTile.adaptive(' in connect
    assert 'analysisEnabled: _analyze' in connect
    assert 'MinhaCameraLiveUrl.accessToken(address)' in connect
    registry=file('lib/services/camera_registry_service.dart')
    assert "replaceFirst('/live/', '/control/') + '/status'" in registry
    assert "'Minha Câmera online (stream não verificado)'" in registry
    assert 'version: 1.0.242+242' in file('pubspec.yaml')
    print('Integração 242: QR 1.4.35, streaming MJPEG, IA local e modo sem IA validados estruturalmente.')

if __name__=='__main__':check()
