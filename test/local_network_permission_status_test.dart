import 'package:vigiaia/services/native_platform_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('status de rede local interpreta resposta nativa', () {
    final status = LocalNetworkPermissionStatus.fromMap(<Object?, Object?>{
      'required': true,
      'granted': false,
      'canRequest': true,
    });

    expect(status.required, isTrue);
    expect(status.granted, isFalse);
    expect(status.canRequest, isTrue);
  });
}
