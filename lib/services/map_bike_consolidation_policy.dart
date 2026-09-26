import '../models/bike_approach_status.dart';
import '../models/monitor_ai_pip_status.dart';
import '../models/offline_poi_package.dart';

/// Regras puras que unem estados do mapa e do Modo Bike sem duplicar
/// detecção, roteamento ou persistência.
class MapBikeConsolidationPolicy {
  const MapBikeConsolidationPolicy._();

  static const Duration approachOverlayFreshness = Duration(seconds: 3);
  static const double offlinePoiCoverageMargin = 1.25;

  static bool shouldShowAutomaticMonitorMap({
    required bool bikeConnected,
    required bool recording,
    required bool navigating,
    required bool recentMovement,
  }) =>
      bikeConnected || recording || navigating || recentMovement;

  static bool shouldShowApproachOverlay({
    required BikeApproachStatus status,
    MonitorAiPipStatus? aiStatus,
    DateTime? now,
  }) {
    if (status.updatedAt.millisecondsSinceEpoch <= 0) return false;
    final age = (now ?? DateTime.now()).difference(status.updatedAt);
    if (age.isNegative || age > approachOverlayFreshness) return false;

    final state = aiStatus?.state;
    if (state == MonitorAiPipState.disabled ||
        state == MonitorAiPipState.waitingFrames ||
        state == MonitorAiPipState.noFrames ||
        state == MonitorAiPipState.cameraUnavailable ||
        state == MonitorAiPipState.connectionLost ||
        state == MonitorAiPipState.possibleError) {
      return false;
    }
    return true;
  }

  static bool canUseOfflinePoiPackageFallback({
    required OfflinePoiPackage package,
    required double distanceMeters,
  }) {
    if (!distanceMeters.isFinite || distanceMeters < 0) return false;
    final radiusMeters = package.searchRadiusKm.clamp(1, 500).toDouble() * 1000.0;
    return distanceMeters <= radiusMeters * offlinePoiCoverageMargin;
  }
}
