import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/mcrp_client.dart';

void main() {
  const token = '0123456789abcdef0123456789abcdef';
  test('aceita URL privada do Minha Câmera sem alterar vigiaia://pair', () {
    final address = McrpAddress.parse('http://192.168.43.1:8765/live/$token');
    expect(address.token, token);
    expect(address.status.path, '/control/$token/status');
    expect(address.info.path, '/control/$token/mcrp/info');
    expect(address.media.path, '/control/$token/mcrp/media');
    expect(address.h264.path, '/h264/$token');
    expect(address.mediaFile('v_12').path, '/control/$token/mcrp/media/v_12');
  });
  test('aceita QR opcional mcrp://pair quando emitido em versão futura', () {
    final address = McrpAddress.parse(Uri(scheme: 'mcrp', host: 'pair',
      queryParameters: {'url': 'http://10.0.0.2:8765/live/$token'}).toString());
    expect(address.liveUrl.host, '10.0.0.2');
  });
  test('rejeita redes públicas, nomes DNS, URL malformada e credenciais', () {
    final cases = <String>[
      'http://8.8.8.8:8765/live/$token', 'http://example.com:8765/live/$token',
      'http://127.0.0.1:8765/live/$token', 'http://192.168.1.2:8080/live/$token',
      'https://192.168.1.2:8765/live/$token', 'http://192.168.1.2:8765/live/abc',
      'http://192.168.1.2:8765/live/$token?x=1',
      'http://user:pass@192.168.1.2:8765/live/$token',
      'vigiaia://pair?v=1&type=phone',
    ];
    for (final value in cases) {
      expect(() => McrpAddress.parse(value), throwsFormatException, reason: value);
    }
  });
  test('rejeita caminho de arquivo em lugar de ID opaco', () {
    final address = McrpAddress.parse('http://172.20.10.1:8765/live/$token');
    expect(() => address.mediaFile('../../secret'), throwsFormatException);
    expect(() => address.mediaFile('%2Fetc'), throwsFormatException);
  });
  test('interpreta metadados estruturados', () {
    final item = McrpMediaItem.fromJson({
      'id': 'p_1', 'name': 'foto.jpg', 'mime': 'image/jpeg', 'size': 4048, 'modified': 1200,
    });
    expect(item.mime, 'image/jpeg');
    expect(item.size, 4048);
  });
}
