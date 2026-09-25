import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/map_ux_policy.dart';

void main() {
  test('detecta HUD compacto em paisagem baixa ou tela estreita', () {
    expect(MapUxPolicy.compactLandscape(width: 900, height: 480), isTrue);
    expect(MapUxPolicy.compactLandscape(width: 360, height: 800), isFalse);
    expect(MapUxPolicy.compactHud(width: 360, height: 800), isTrue);
    expect(MapUxPolicy.compactHud(width: 420, height: 800), isFalse);
  });

  test('reserva PiP abaixo do HUD e acima dos paineis inferiores', () {
    expect(
      MapUxPolicy.cameraMinY(safeTop: 24, compactLandscape: false),
      166,
    );
    expect(
      MapUxPolicy.cameraMinY(safeTop: 24, compactLandscape: true),
      174,
    );
    expect(
      MapUxPolicy.cameraBottomReserve(
        safeBottom: 20,
        hasSelectedPoi: true,
        hasNavigation: true,
      ),
      194,
    );
  });

  test('normalizacao de posicao respeita minimo diferente de zero', () {
    final fraction = MapUxPolicy.fractionForPosition(
      position: 58,
      min: 8,
      max: 108,
    );
    expect(fraction, closeTo(0.5, 0.0001));
    expect(
      MapUxPolicy.positionForFraction(fraction: fraction, min: 8, max: 108),
      closeTo(58, 0.0001),
    );
  });
}
