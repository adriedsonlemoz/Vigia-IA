class MapRoutePoint {
  const MapRoutePoint({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    required this.accuracyMeters,
    required this.speedMetersPerSecond,
    this.altitudeMeters,
    this.headingDegrees,
  });

  final double latitude;
  final double longitude;
  final DateTime recordedAt;
  final double accuracyMeters;
  final double speedMetersPerSecond;
  final double? altitudeMeters;
  final double? headingDegrees;

  double get speedKilometersPerHour => speedMetersPerSecond * 3.6;
}
