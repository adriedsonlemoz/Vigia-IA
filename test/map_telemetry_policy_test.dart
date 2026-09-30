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
  double accuracyMeters = 5,
  double? altitudeMeters,
  double? altitudeAccuracyMeters,
}) =>
    MapRoutePoint(
      latitude: -20.0,
      longitude: -45.0,
      recordedAt: at,
      accuracyMeters: accuracyMeters,
      speedMetersPerSecond: speedMps,
      speedAvailable: speedAvailable,
      speedAccuracyMetersPerSecond: speedAccuracyMps,
      headingDegrees: heading,
      headingAvailable: headingAvailable,
      altitudeMeters: altitudeMeters,
      altitudeAccuracyMeters: altitudeAccuracyMeters,
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

  test('qualidade GPS combina precisao e idade sem fabricar sinal', () {
    final at = DateTime.utc(2026, 9, 26, 12);
    expect(
      MapTelemetryPolicy.gpsQuality(
        point(at: at, accuracyMeters: 4),
        now: at.add(const Duration(seconds: 2)),
      ),
      MapGpsQuality.excellent,
    );
    expect(
      MapTelemetryPolicy.gpsQuality(
        point(at: at, accuracyMeters: 24),
        now: at.add(const Duration(seconds: 2)),
      ),
      MapGpsQuality.fair,
    );

    expect(
      MapTelemetryPolicy.gpsQuality(
        point(at: at, accuracyMeters: 0),
        now: at.add(const Duration(seconds: 2)),
      ),
      MapGpsQuality.unknown,
    );
    expect(
      MapTelemetryPolicy.gpsQuality(
        point(at: at, accuracyMeters: 4),
        now: at.add(const Duration(seconds: 25)),
      ),
      MapGpsQuality.stale,
    );
  });

  test('perfil de altitude ignora amostra vertical muito ruim', () {
    final at = DateTime.utc(2026, 9, 26, 12);
    final summary = MapTelemetryPolicy.elevationSummary(<MapRoutePoint>[
      point(
        at: at,
        altitudeMeters: 700,
        altitudeAccuracyMeters: 8,
      ),
      point(
        at: at.add(const Duration(seconds: 5)),
        altitudeMeters: 900,
        altitudeAccuracyMeters: 120,
      ),
      point(
        at: at.add(const Duration(seconds: 10)),
        altitudeMeters: 715,
        altitudeAccuracyMeters: 10,
      ),
    ]);

    expect(summary.samples, 2);
    expect(summary.minimumMeters, 700);
    expect(summary.maximumMeters, 715);
    expect(summary.rangeMeters, 15);
    expect(summary.recentDeltaMeters, 15);
  });

}
