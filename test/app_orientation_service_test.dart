import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/app_orientation_service.dart';

void main() {
  test('telas normais ficam somente em retrato', () {
    expect(AppOrientationService.portraitOnly, <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  });

  test('transmissao acompanha todas as orientacoes do aparelho', () {
    expect(AppOrientationService.transmissionAuto, containsAll(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]));
    expect(AppOrientationService.transmissionAuto, hasLength(4));
  });
}
