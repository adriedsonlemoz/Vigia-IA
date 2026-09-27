import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/bike_sensor_snapshot.dart';
import 'package:vigiaia/models/map_route_point.dart';
import 'package:vigiaia/services/map_speed_policy.dart';

void main() {
  final now = DateTime(2026, 9, 27, 12);

  test('velocidade Hall recente prevalece sobre GPS e desconexão usa GPS', () {
    final bike = BikeSensorSnapshot(
      capturedAt: now,
      source: BikeSensorSource.esp32,
      connected: true,
      speedKmh: 26,
      frontTirePsi: 35,
      rearTirePsi: 35,
      sensorBatteryPercent: 80,
      tripDistanceKm: 1,
    );
    final gps = MapRoutePoint(
      latitude: -19.3,
      longitude: -42.0,
      recordedAt: now,
      accuracyMeters: 8,
      speedMetersPerSecond: 5,
      speedAvailable: true,
    );
    expect(MapSpeedPolicy.select(bike, gps, now: now)?.source, 'ESP32 · Hall');
    expect(MapSpeedPolicy.select(bike, gps, now: now)?.kmh, 26);
    expect(MapSpeedPolicy.select(bike, gps,
      now: now.add(const Duration(seconds: 11)))?.source, 'GPS');
    expect(MapSpeedPolicy.select(bike, gps,
      now: now.add(const Duration(seconds: 21))), isNull);
  });

  test('limite requer nova travessia e aguarda intervalo entre alertas', () {
    final policy = MapSpeedAlertPolicy();
    expect(policy.observe(19, <int>[20, 25], now: now), isNull);
    expect(policy.observe(21, <int>[20, 25], now: now), 20);
    expect(policy.observe(26, <int>[20, 25],
      now: now.add(const Duration(seconds: 1))), isNull);
    expect(policy.observe(26, <int>[20, 25],
      now: now.add(const Duration(seconds: 21))), 25);
    expect(policy.observe(17, <int>[20, 25],
      now: now.add(const Duration(seconds: 22))), isNull);
    expect(policy.observe(26, <int>[20, 25],
      now: now.add(const Duration(seconds: 45))), 20);
  });
}
