import 'package:vigiaia/services/native_platform_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CameraPermissionStatus converte estado concedido', () {
    final status = CameraPermissionStatus.fromMap(<Object?, Object?>{
      'granted': true,
      'prompted': true,
      'showRationale': false,
      'canRequest': false,
    });

    expect(status.granted, isTrue);
    expect(status.prompted, isTrue);
    expect(status.showRationale, isFalse);
    expect(status.canRequest, isFalse);
  });

  test('CameraPermissionStatus usa defaults seguros', () {
    final status = CameraPermissionStatus.fromMap(const <Object?, Object?>{});
    expect(status.granted, isFalse);
    expect(status.prompted, isFalse);
    expect(status.showRationale, isFalse);
    expect(status.canRequest, isFalse);
  });
}
