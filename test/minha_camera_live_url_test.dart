import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/minha_camera_live_url.dart';
import 'package:vigiaia/services/remote_camera_pairing_service.dart';

void main() {
  const token = '0123456789abcdef0123456789abcdef';
  const valid = 'http://192.168.43.1:8765/live/$token';
  test('aceita QR real do Minha Câmera, extrai chave sem expor na UI', () {
    expect(MinhaCameraLiveUrl.isValid(valid), isTrue);
    expect(MinhaCameraLiveUrl.accessToken(valid), token);
    final pair = RemoteCameraPairingService.decode(valid);
    expect(pair.address, valid);
    expect(pair.accessKey, token);
    expect(pair.name, 'Minha Câmera');
  });
  test('faixas privadas compatíveis com PhoneCameraUrls 1.4.35', () {
    for (final ip in ['10.0.0.7','172.16.0.1','172.31.255.1',
      '192.168.0.9','169.254.0.1','100.64.0.1','100.127.0.1']) {
      expect(MinhaCameraLiveUrl.isValid('http://$ip:8765/live/$token'), isTrue, reason: ip);
    }
  });
  test('nega internet, DNS, spoof, QR modificado e rotas extras', () {
    for (final url in [
      'https://192.168.43.1:8765/live/$token',
      'http://8.8.8.8:8765/live/$token',
      'http://127.0.0.1:8765/live/$token',
      'http://192.168.001.2:8765/live/$token',
      'http://192.168.43.1:8765/live/$token?x=1',
      'http://192.168.43.1:8765/live/$token#x',
      'http://user@192.168.43.1:8765/live/$token',
      'http://192.168.43.1:8765/control/$token/status',
      'http://192.168.43.1:8765/live/zzzz',
      'http://192.168.43.1:8765/live/$token/extra',
      'http://evil.example:8765/live/$token',
      'http://192.168.43.1:0/live/$token',
    ]) {
      expect(MinhaCameraLiveUrl.isValid(url), isFalse, reason: url);
      expect(() => RemoteCameraPairingService.decode(url), throwsFormatException);
    }
  });
}
