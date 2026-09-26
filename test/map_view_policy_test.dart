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
  // Regras 1.0.163: a orientação nunca fabrica heading e identifica a fonte real.
  test('Direção parado prioriza sensor físico', () {
    final decision = MapViewPolicy.orientationHeading(
      mode: MapOrientationMode.directionUp,
      speedKmh: 0.5,
      sensorHeadingDegrees: 42,
      gpsHeadingDegrees: 120,
      routeHeadingDegrees: 180,
    );
    expect(decision.headingDegrees, 42);
    expect(decision.source, MapHeadingSource.sensor);
  });

  test('Direção em movimento prioriza heading GPS', () {
    final decision = MapViewPolicy.orientationHeading(
      mode: MapOrientationMode.directionUp,
      speedKmh: 18,
      sensorHeadingDegrees: 42,
      gpsHeadingDegrees: 120,
      routeHeadingDegrees: 180,
    );
    expect(decision.headingDegrees, 120);
    expect(decision.source, MapHeadingSource.gps);
  });

  test('Rota usa geometria quando GPS não existe em movimento', () {
    final decision = MapViewPolicy.orientationHeading(
      mode: MapOrientationMode.routeUp,
      speedKmh: 18,
      sensorHeadingDegrees: 42,
      routeHeadingDegrees: 180,
    );
    expect(decision.headingDegrees, 180);
    expect(decision.source, MapHeadingSource.route);
  });

  test('sem sensor GPS ou rota o heading fica indisponível', () {
    final decision = MapViewPolicy.orientationHeading(
      mode: MapOrientationMode.directionUp,
      speedKmh: 0,
    );
    expect(decision.headingDegrees, isNull);
    expect(decision.source, MapHeadingSource.unavailable);
  });

  test('suavização cruza zero grau pelo caminho curto', () {
    final value = MapViewPolicy.smoothHeading(358, 2, alpha: 0.5);
    expect(value, closeTo(0, 0.001));
  });
}
