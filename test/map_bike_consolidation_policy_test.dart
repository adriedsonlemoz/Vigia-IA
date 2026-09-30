import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/bike_approach_status.dart';
import 'package:vigiaia/models/monitor_ai_pip_status.dart';
import 'package:vigiaia/models/offline_poi_package.dart';
import 'package:vigiaia/services/map_bike_consolidation_policy.dart';

void main() {
  final now = DateTime.utc(2026, 9, 25, 21);

  test('mini mapa automatico permanece visivel durante navegacao parada', () {
    expect(
      MapBikeConsolidationPolicy.shouldShowAutomaticMonitorMap(
        bikeConnected: false,
        recording: false,
        navigating: true,
        recentMovement: false,
      ),
      isTrue,
    );
  });

  test('TTC antigo ou com camera perdida nao permanece no PiP', () {
    final fresh = BikeApproachStatus(
      level: BikeApproachLevel.warning,
      updatedAt: now.subtract(const Duration(seconds: 1)),
      estimatedTtcSeconds: 3.0,
      vehicleDetected: true,
    );
    final stale = BikeApproachStatus(
      level: BikeApproachLevel.warning,
      updatedAt: now.subtract(const Duration(seconds: 5)),
      estimatedTtcSeconds: 3.0,
      vehicleDetected: true,
    );

    expect(
      MapBikeConsolidationPolicy.shouldShowApproachOverlay(
        status: fresh,
        aiStatus: const MonitorAiPipStatus(state: MonitorAiPipState.active),
        now: now,
      ),
      isTrue,
    );
    expect(
      MapBikeConsolidationPolicy.shouldShowApproachOverlay(
        status: stale,
        aiStatus: const MonitorAiPipStatus(state: MonitorAiPipState.active),
        now: now,
      ),
      isFalse,
    );
    expect(
      MapBikeConsolidationPolicy.shouldShowApproachOverlay(
        status: fresh,
        aiStatus: const MonitorAiPipStatus(
          state: MonitorAiPipState.connectionLost,
        ),
        now: now,
      ),
      isFalse,
    );
    expect(
      MapBikeConsolidationPolicy.shouldShowApproachOverlay(
        status: fresh,
        aiStatus: const MonitorAiPipStatus(
          state: MonitorAiPipState.waitingFrames,
        ),
        now: now,
      ),
      isFalse,
    );
  });

  test('pacote offline distante nao vira fonte de POIs da regiao errada', () {
    final package = OfflinePoiPackage(
      id: 'p1',
      name: 'Regiao',
      createdAt: now,
      updatedAt: now,
      west: -44,
      south: -20,
      east: -43,
      north: -19,
      originLatitude: -19.9,
      originLongitude: -43.9,
      searchRadiusKm: 20,
      items: const [],
    );

    expect(
      MapBikeConsolidationPolicy.canUseOfflinePoiPackageFallback(
        package: package,
        distanceMeters: 24000,
      ),
      isTrue,
    );
    expect(
      MapBikeConsolidationPolicy.canUseOfflinePoiPackageFallback(
        package: package,
        distanceMeters: 40000,
      ),
      isFalse,
    );
  });
}
