import '../models/bike_trip_plan.dart';
import '../models/map_cycling_route.dart';
import '../models/map_travel_mode.dart';

/// Comparação para a PRÉVIA; não altera navegação, gravação nem o roteamento.
/// O backend não entrega elevação ou qualidade/segurança das vias neste modelo.
class MapRoutePreviewMetrics {
  const MapRoutePreviewMetrics._({
    required this.distanceMeters,
    required this.durationMinutes,
    required this.durationSource,
  });

  final double distanceMeters;
  final int? durationMinutes;
  final String durationSource;

  static MapRoutePreviewMetrics forRoute({
    required MapCyclingRoute route,
    required MapTravelMode mode,
    required BikeTravelPreferences bikePreferences,
  }) {
    final meters = route.distanceMeters;
    final distance = meters.isFinite && meters >= 0 ? meters : 0.0;
    if (mode == MapTravelMode.bicycle) {
      final speed = bikePreferences.averageSpeedKmh;
      if (!speed.isFinite || speed <= 0 || !meters.isFinite || meters < 0) {
        return MapRoutePreviewMetrics._(
          distanceMeters: distance,
          durationMinutes: null,
          durationSource: 'Ritmo da bicicleta indisponível',
        );
      }
      return MapRoutePreviewMetrics._(
        distanceMeters: distance,
        durationMinutes: (distance / 1000 / speed * 60).round(),
        durationSource: 'Tempo estimado pelo ritmo configurado (${speed.toStringAsFixed(1)} km/h), sem pausas',
      );
    }
    final seconds = route.durationSeconds;
    return MapRoutePreviewMetrics._(
      distanceMeters: distance,
      durationMinutes: seconds.isFinite && seconds > 0
          ? (seconds / 60).round() : null,
      durationSource: 'Tempo informado pelo serviço de rotas; pode variar no deslocamento',
    );
  }

  String get distanceLabel => '${(distanceMeters / 1000).toStringAsFixed(1)} km';

  String get durationLabel {
    final minutes = durationMinutes;
    if (minutes == null) return 'tempo indisponível';
    return '${minutes ~/ 60}h${(minutes % 60).toString().padLeft(2, '0')}';
  }

  /// A distância geométrica não diz qual via é mais segura ou fácil.
  String distanceDifference(MapRoutePreviewMetrics other) {
    final difference = distanceMeters - other.distanceMeters;
    if (difference.abs() < 100) return 'distância semelhante';
    final label = (difference.abs() / 1000).toStringAsFixed(1);
    return difference > 0 ? '+$label km em relação à rota 1' : '-$label km em relação à rota 1';
  }
}
