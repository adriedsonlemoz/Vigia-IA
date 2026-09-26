import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/map_route_point.dart';
import 'package:vigiaia/services/map_performance_policy.dart';

MapRoutePoint point(double latitude, DateTime at) => MapRoutePoint(
      latitude: latitude,
      longitude: -45,
      recordedAt: at,
      accuracyMeters: 5,
      speedMetersPerSecond: 5,
    );

void main() {
  test('GPS usa filtro de distancia mais economico sem perder navegacao', () {
    expect(MapPerformancePolicy.gpsDistanceFilterMeters, 8);
  });

  test('POIs nao forcam rebuild para deslocamento minimo em poucos segundos', () {
    final now = DateTime(2026, 9, 25, 20);
    final previous = point(-20, now);
    final current = point(-19.99996, now.add(const Duration(seconds: 1)));

    expect(
      MapPerformancePolicy.shouldRefreshPoiUi(
        current: current,
        lastPresented: previous,
        lastPresentedAt: now,
        now: now.add(const Duration(seconds: 1)),
      ),
      isFalse,
    );
  });

  test('POIs atualizam apos janela temporal mesmo sem grande deslocamento', () {
    final now = DateTime(2026, 9, 25, 20);
    final previous = point(-20, now);
    final current = point(-19.99999, now.add(const Duration(seconds: 5)));

    expect(
      MapPerformancePolicy.shouldRefreshPoiUi(
        current: current,
        lastPresented: previous,
        lastPresentedAt: now,
        now: now.add(const Duration(seconds: 5)),
      ),
      isTrue,
    );
  });

  test('busca automatica de POIs respeita cooldown entre tentativas', () {
    final now = DateTime(2026, 9, 25, 20);
    expect(
      MapPerformancePolicy.canAttemptAutomaticPoiRequest(
        lastAttemptAt: now,
        now: now.add(const Duration(seconds: 30)),
      ),
      isFalse,
    );
    expect(
      MapPerformancePolicy.canAttemptAutomaticPoiRequest(
        lastAttemptAt: now,
        now: now.add(const Duration(seconds: 91)),
      ),
      isTrue,
    );
  });
}
