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
      218,
    );
  });

  test('navegacao reduz apenas o tamanho efetivo do PiP', () {
    expect(
      MapUxPolicy.cameraEffectiveScale(
        savedScale: 1.25,
        hasNavigation: true,
        compactHud: false,
      ),
      1.0,
    );
    expect(
      MapUxPolicy.cameraEffectiveScale(
        savedScale: 1.25,
        hasNavigation: true,
        compactHud: true,
      ),
      0.82,
    );
    expect(
      MapUxPolicy.cameraEffectiveScale(
        savedScale: 1.25,
        hasNavigation: false,
        compactHud: true,
      ),
      1.25,
    );
  });

  test('encaixe evita duas cameras no mesmo canto', () {
    final portrait = MapUxPolicy.cameraSnapPoint(
      xFraction: 0.1,
      yFraction: 0.1,
      compactLandscape: false,
      otherXFraction: 0.2,
      otherYFraction: 0.2,
    );
    expect(portrait.xFraction, 0);
    expect(portrait.yFraction, 1);

    final landscape = MapUxPolicy.cameraSnapPoint(
      xFraction: 0.9,
      yFraction: 0.9,
      compactLandscape: true,
      otherXFraction: 0.8,
      otherYFraction: 0.7,
    );
    expect(landscape.xFraction, 0);
    expect(landscape.yFraction, 1);
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
