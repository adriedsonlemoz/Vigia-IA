import 'package:latlong2/latlong.dart';

class MapCyclingRoute {
  const MapCyclingRoute({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
}
