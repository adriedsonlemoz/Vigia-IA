import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/google_maps_key_service.dart';

void main() {
  group('GoogleMapsKeyService.validate', () {
    test('rejeita vazio, espacos e formato estranho', () {
      expect(GoogleMapsKeyService.validate(''), isNotNull);
      expect(GoogleMapsKeyService.validate('AIza com espaco 1234567890123456'), isNotNull);
      expect(GoogleMapsKeyService.validate('curta'), isNotNull);
      expect(GoogleMapsKeyService.validate('XXXX${'a' * 35}'), isNotNull);
    });

    test('aceita formato de chave do Google', () {
      expect(GoogleMapsKeyService.validate('AIza${'a' * 35}'), isNull);
    });
  });
}
