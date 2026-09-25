import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/map_view_policy.dart';

void main() {
  test('zoom rapido diferencia Perto e Regiao', () {
    expect(MapViewPolicy.zoomFor(MapFollowViewPreset.near), greaterThan(14));
    expect(MapViewPolicy.zoomFor(MapFollowViewPreset.region), lessThan(14));
  });

  test('heading vira rotacao oposta para manter deslocamento no topo', () {
    expect(MapViewPolicy.mapRotationForHeading(0), 0);
    expect(MapViewPolicy.mapRotationForHeading(90), 270);
    expect(MapViewPolicy.mapRotationForHeading(180), 180);
    expect(MapViewPolicy.mapRotationForHeading(270), 90);
  });

  test('delta angular usa caminho curto ao cruzar zero grau', () {
    expect(MapViewPolicy.shortestAngularDelta(359, 1), closeTo(2, 0.001));
    expect(MapViewPolicy.shortestAngularDelta(1, 359), closeTo(-2, 0.001));
  });

  test('rotacao por rumo ignora jitter parado e pequenas variacoes', () {
    expect(
      MapViewPolicy.shouldApplyHeadingRotation(
        headingDegrees: 90,
        speedKmh: 1,
        currentMapRotationDegrees: 0,
      ),
      isFalse,
    );
    expect(
      MapViewPolicy.shouldApplyHeadingRotation(
        headingDegrees: 90,
        speedKmh: 18,
        currentMapRotationDegrees: 271,
      ),
      isFalse,
    );
    expect(
      MapViewPolicy.shouldApplyHeadingRotation(
        headingDegrees: 90,
        speedKmh: 18,
        currentMapRotationDegrees: 300,
      ),
      isTrue,
    );
  });

  test('offset de acompanhamento mantem usuario abaixo do centro', () {
    expect(
      MapViewPolicy.followOffsetPixels(
        viewportHeight: 800,
        compactLandscape: false,
      ),
      closeTo(144, 0.001),
    );
    expect(
      MapViewPolicy.followOffsetPixels(
        viewportHeight: 400,
        compactLandscape: true,
      ),
      closeTo(48, 0.001),
    );
  });
}
