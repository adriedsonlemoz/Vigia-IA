import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/map_route_point.dart';

void main() {
  test('converts GPS speed from m/s to km/h', () {
    final point = MapRoutePoint(
      latitude: -20.0,
      longitude: -45.0,
      recordedAt: DateTime(2026, 9, 22),
      accuracyMeters: 4,
      speedMetersPerSecond: 5,
    );

    expect(point.speedKilometersPerHour, 18);
  });
}
