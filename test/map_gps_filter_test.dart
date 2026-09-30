import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/map_route_point.dart';
import 'package:vigiaia/services/map_gps_filter.dart';

MapRoutePoint point({
  double latitude = -19.9167,
  double longitude = -43.9345,
  DateTime? recordedAt,
  double accuracy = 5,
  double speed = 4,
  double? heading = 90,
}) {
  return MapRoutePoint(
    latitude: latitude,
    longitude: longitude,
    recordedAt: recordedAt ?? DateTime.utc(2026, 9, 25, 12),
    accuracyMeters: accuracy,
    speedMetersPerSecond: speed,
    headingDegrees: heading,
  );
}

void main() {
  test('rejeita leitura com precisão insuficiente antes de contaminar posição', () {
    final filter = MapGpsFilter();

    final result = filter.evaluate(point(accuracy: 95));

    expect(result.accepted, isFalse);
    expect(result.rejectionReason, MapGpsRejectionReason.invalidAccuracy);
    expect(filter.lastAccepted, isNull);
  });

  test('rejeita velocidade terrestre implausível', () {
    final filter = MapGpsFilter();

    final result = filter.evaluate(
      point(speed: MapGpsFilter.maximumPlausibleSpeedMetersPerSecond + 1),
    );

    expect(result.accepted, isFalse);
    expect(result.rejectionReason, MapGpsRejectionReason.implausibleSpeed);
  });

  test('rejeita salto incompatível com o tempo entre leituras', () {
    final filter = MapGpsFilter();
    final first = point(recordedAt: DateTime.utc(2026, 9, 25, 12, 0, 0));
    final jumped = point(
      latitude: -19.9067,
      recordedAt: DateTime.utc(2026, 9, 25, 12, 0, 1),
    );

    expect(filter.evaluate(first).accepted, isTrue);
    final result = filter.evaluate(jumped);

    expect(result.accepted, isFalse);
    expect(
      result.rejectionReason,
      MapGpsRejectionReason.implausibleDisplacement,
    );
  });

  test('reinicia suavização depois de uma lacuna longa de GPS', () {
    final filter = MapGpsFilter();
    final first = point(recordedAt: DateTime.utc(2026, 9, 25, 12, 0, 0));
    final later = point(
      latitude: -19.9067,
      longitude: -43.9245,
      recordedAt: DateTime.utc(2026, 9, 25, 12, 1, 0),
    );

    expect(filter.evaluate(first).accepted, isTrue);
    final result = filter.evaluate(later);

    expect(result.accepted, isTrue);
    expect(result.point!.latitude, later.latitude);
    expect(result.point!.longitude, later.longitude);
  });

  test('lacuna longa ainda rejeita teleporte fisicamente impossível', () {
    final filter = MapGpsFilter();
    final first = point(recordedAt: DateTime.utc(2026, 9, 25, 12, 0, 0));
    final impossible = point(
      latitude: -18.9167,
      longitude: -42.9345,
      recordedAt: DateTime.utc(2026, 9, 25, 12, 1, 0),
    );

    expect(filter.evaluate(first).accepted, isTrue);
    final result = filter.evaluate(impossible);

    expect(result.accepted, isFalse);
    expect(
      result.rejectionReason,
      MapGpsRejectionReason.implausibleDisplacement,
    );
  });

  test('gravação exige precisão mais forte que a exibição no mapa', () {
    final filter = MapGpsFilter();
    final medium = point(accuracy: 45);

    final accepted = filter.evaluate(medium);

    expect(accepted.accepted, isTrue);
    expect(MapGpsFilter.isSuitableForRecording(accepted.point!), isFalse);
    expect(MapGpsFilter.maximumAcceptedAccuracyMeters, 60);
    expect(MapGpsFilter.maximumRecordingAccuracyMeters, 35);
  });

  test('limiar de movimento cresce com ruído do GPS e evita jitter', () {
    final previous = point(accuracy: 4);
    final noisy = point(
      accuracy: 30,
      recordedAt: DateTime.utc(2026, 9, 25, 12, 0, 2),
    );

    expect(MapGpsFilter.meaningfulMovementThresholdMeters(previous, noisy), 8.5);
  });

  test('suavização de rumo atravessa 360 graus pelo caminho curto', () {
    final filter = MapGpsFilter();
    final first = point(
      heading: 350,
      speed: 6,
      recordedAt: DateTime.utc(2026, 9, 25, 12, 0, 0),
    );
    final second = point(
      longitude: -43.9344,
      heading: 10,
      speed: 6,
      recordedAt: DateTime.utc(2026, 9, 25, 12, 0, 2),
    );

    expect(filter.evaluate(first).accepted, isTrue);
    final result = filter.evaluate(second);

    expect(result.accepted, isTrue);
    expect(result.point!.headingDegrees, closeTo(357, 0.01));
  });
}
