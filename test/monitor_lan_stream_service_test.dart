import 'package:vigiaia/services/monitor_lan_stream_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('URL do visualizador inclui chave e normaliza barra final', () {
    expect(
      MonitorLanStreamService.buildViewerUrl(
        'http://192.168.0.20:8766/',
        'A B+C',
      ),
      'http://192.168.0.20:8766/?key=A%20B%2BC',
    );
  });

  test('URL do visualizador preserva base sem barra final', () {
    expect(
      MonitorLanStreamService.buildViewerUrl(
        'http://10.0.0.8:8766',
        'CHAVE123',
      ),
      'http://10.0.0.8:8766/?key=CHAVE123',
    );
  });

  test('URL do visualizador codifica caracteres reservados sem perder a chave', () {
    const key = 'A&B=? /+#';
    final url = MonitorLanStreamService.buildViewerUrl(
      'http://192.168.0.20:8766',
      key,
    );

    expect(url, 'http://192.168.0.20:8766/?key=A%26B%3D%3F%20%2F%2B%23');
    expect(Uri.parse(url).queryParameters['key'], key);
  });
}
