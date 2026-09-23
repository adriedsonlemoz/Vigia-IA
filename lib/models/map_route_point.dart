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

  Map<String, Object?> toJson() => <String, Object?>{
        'latitude': latitude,
        'longitude': longitude,
        'recordedAt': recordedAt.toIso8601String(),
        'accuracyMeters': accuracyMeters,
        'speedMetersPerSecond': speedMetersPerSecond,
        'altitudeMeters': altitudeMeters,
        'headingDegrees': headingDegrees,
      };

  factory MapRoutePoint.fromJson(Map<String, dynamic> json) => MapRoutePoint(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        recordedAt: DateTime.parse(json['recordedAt'] as String),
        accuracyMeters: (json['accuracyMeters'] as num?)?.toDouble() ?? 0,
        speedMetersPerSecond:
            (json['speedMetersPerSecond'] as num?)?.toDouble() ?? 0,
        altitudeMeters: (json['altitudeMeters'] as num?)?.toDouble(),
        headingDegrees: (json['headingDegrees'] as num?)?.toDouble(),
      );
}
