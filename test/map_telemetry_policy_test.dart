import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/map_route_point.dart';
import 'package:vigiaia/services/map_telemetry_policy.dart';

MapRoutePoint point({
  required DateTime at,
  double speedMps = 0,
  bool speedAvailable = true,
  double? speedAccuracyMps,
  double? heading,
  bool headingAvailable = true,
}) =>
    MapRoutePoint(
      latitude: -20.0,
      longitude: -45.0,
      recordedAt: at,
      accuracyMeters: 5,
      speedMetersPerSecond: speedMps,
      speedAvailable: speedAvailable,
      speedAccuracyMetersPerSecond: speedAccuracyMps,
      headingDegrees: heading,
      headingAvailable: headingAvailable,
    );

void main() {
  test('sessao usa somente velocidades realmente fornecidas pela plataforma', () {
    final tracker = MapTelemetrySessionTracker();
    final start = DateTime.utc(2026, 9, 26, 12);

    tracker.add(point(at: start, speedMps: 2));
    tracker.add(point(at: start, speedMps: 2)); // mesma leitura nao duplica
    tracker.add(
      point(
        at: start.add(const Duration(seconds: 5)),
        speedMps: 99,
        speedAvailable: false,
      ),
    );
    tracker.add(
      point(
        at: start.add(const Duration(seconds: 10)),
        speedMps: 4,
      ),
    );

    expect(tracker.speedSamples, 2);
    expect(tracker.averageSpeedKmh, closeTo(10.8, 0.001));
    expect(tracker.maximumSpeedKmh, closeTo(14.4, 0.001));
  });

  test('precisoes e heading indisponiveis nao viram zero sintetico', () {
    final sample = point(
      at: DateTime.utc(2026, 9, 26, 12),
      speedMps: 0,
      speedAvailable: false,
      speedAccuracyMps: 0,
      heading: 180,
      headingAvailable: false,
    );

    expect(MapTelemetryPolicy.currentSpeedKmh(sample), isNull);
    expect(MapTelemetryPolicy.speedAccuracyKmh(sample), isNull);
    expect(MapTelemetryPolicy.gpsHeadingDegrees(sample), isNull);
    expect(MapTelemetryPolicy.validAccuracyMeters(0), isNull);
  });

  test('leitura fica antiga somente depois da janela real configurada', () {
    final at = DateTime.utc(2026, 9, 26, 12);
    final sample = point(at: at);

    expect(
      MapTelemetryPolicy.isFresh(
        sample,
        now: at.add(const Duration(seconds: 20)),
      ),
      isTrue,
    );
    expect(
      MapTelemetryPolicy.isFresh(
        sample,
        now: at.add(const Duration(seconds: 21)),
      ),
      isFalse,
    );
  });
}
