import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/map_route_point.dart';
import 'package:vigiaia/services/map_route_service.dart';

void main() {
  test('ponto de rota preserva coordenadas e telemetria no JSON', () {
    final point = MapRoutePoint(
      latitude: -20.123456,
      longitude: -45.654321,
      recordedAt: DateTime.utc(2026, 9, 23, 15, 30),
      accuracyMeters: 4.5,
      speedMetersPerSecond: 6.25,
      altitudeMeters: 712.4,
      headingDegrees: 182.0,
    );

    final restored = MapRoutePoint.fromJson(point.toJson());

    expect(restored.latitude, point.latitude);
    expect(restored.longitude, point.longitude);
    expect(restored.recordedAt, point.recordedAt);
    expect(restored.accuracyMeters, point.accuracyMeters);
    expect(restored.speedMetersPerSecond, point.speedMetersPerSecond);
    expect(restored.altitudeMeters, point.altitudeMeters);
    expect(restored.headingDegrees, point.headingDegrees);
  });

  test('mapa do Monitor mantém as três políticas de visibilidade', () {
    expect(
      MonitorMapVisibilityMode.values.map((value) => value.name),
      containsAll(<String>['automatic', 'always', 'hidden']),
    );
  });
}
