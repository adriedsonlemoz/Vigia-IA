import 'location_tracking_service.dart';
import 'map_route_service.dart';
import 'offline_map_service.dart';

/// Fotografia de baixo custo: não solicita posição nem inicializa mapas/câmeras.
/// Nunca inclui latitude, longitude, trajetos ou caminhos dos arquivos MBTiles.
class MapDiagnosticsService {
  MapDiagnosticsService._();

  static final MapDiagnosticsService instance = MapDiagnosticsService._();

  int _offlineOpenErrors = 0;
  DateTime? _lastOfflineOpenErrorAt;

  void recordOfflineOpenFailure() {
    _offlineOpenErrors++;
    _lastOfflineOpenErrorAt = DateTime.now();
  }

  Future<Map<String, Object?>> capture() async {
    final route = MapRouteService.instance;
    final maps = OfflineMapService.instance;
    String gpsAvailability;
    try {
      // checkPermission + isLocationServiceEnabled; sem prompt e sem GPS.
      gpsAvailability = (await LocationTrackingService.instance
              .ensureAvailable(requestPermission: false))
          .name;
    } catch (_) {
      gpsAvailability = 'indisponivel';
    }
    final last = route.lastGpsSampleReceivedAt;
    final age = last == null ? null : DateTime.now().difference(last).inSeconds;
    return <String, Object?>{
      'gpsAvailability': gpsAvailability,
      'gpsStreamActive': route.gpsStreamActive,
      'gpsConsumers': route.locationConsumers,
      'gpsUpdatesPerMinute': route.gpsUpdatesInLastMinute(),
      'gpsStreamStarts': route.gpsStreamStarts,
      'gpsStreamErrors': route.gpsStreamErrors,
      'gpsSampleAgeSeconds': age == null || age < 0 ? null : age,
      'accuracyMeters': route.current?.accuracyMeters,
      'rejectedGpsPoints': route.rejectedGpsPoints,
      'lastRejectionReason': route.lastGpsRejectionReason?.name,
      'recording': route.recording,
      'paused': route.paused,
      'navigating': route.navigating,
      'recordedPoints': route.routePointCount,
      'offlineMode': maps.mode.name,
      'offlinePackages': maps.packages.length,
      'offlinePackageSelected': maps.activePackage != null,
      'offlineBusy': maps.busy,
      'offlineOpenErrors': _offlineOpenErrors,
      'lastOfflineOpenErrorAt': _lastOfflineOpenErrorAt?.toIso8601String(),
    };
  }
}
