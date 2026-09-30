import 'package:vigiaia/services/remote_camera_pairing_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RemoteCameraPairingService', () {
    test('gera e lê um QR versionado do Vigia IA', () {
      const input = RemoteCameraPairingData(
        address: 'http://192.168.1.25:8765/',
        accessKey: 'AB12CD34EF56',
        name: 'Celular do portão',
      );

      final encoded = RemoteCameraPairingService.encode(input);
      final decoded = RemoteCameraPairingService.decode(encoded);

      expect(encoded, startsWith('vigiaia://pair?'));
      expect(decoded.address, 'http://192.168.1.25:8765');
      expect(decoded.accessKey, 'AB12CD34EF56');
      expect(decoded.name, 'Celular do portão');
    });

    test('rejeita QR de outro aplicativo', () {
      expect(
        () => RemoteCameraPairingService.decode('https://example.com/qualquer'),
        throwsFormatException,
      );
    });

    test('rejeita versão de pareamento não suportada', () {
      const raw =
          'vigiaia://pair?v=99&type=phone&address=http%3A%2F%2F192.168.1.25%3A8765&key=AB12CD34EF56';
      expect(
        () => RemoteCameraPairingService.decode(raw),
        throwsFormatException,
      );
    });

    test('rejeita endereço com caminho inesperado', () {
      expect(
        () => RemoteCameraPairingService.encode(
          const RemoteCameraPairingData(
            address: 'http://192.168.1.25:8765/admin',
            accessKey: 'AB12CD34EF56',
          ),
        ),
        throwsFormatException,
      );
    });
  });
}
