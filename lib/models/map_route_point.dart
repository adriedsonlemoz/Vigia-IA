class MapRoutePoint {
  const MapRoutePoint({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    required this.accuracyMeters,
    required this.speedMetersPerSecond,
    this.speedAvailable = true,
    this.speedAccuracyMetersPerSecond,
    this.altitudeMeters,
    this.altitudeAccuracyMeters,
    this.headingDegrees,
    this.headingAvailable = true,
    this.headingAccuracyDegrees,
  });

  final double latitude;
  final double longitude;
  final DateTime recordedAt;
  final double accuracyMeters;
  final double speedMetersPerSecond;
  final bool speedAvailable;
  final double? speedAccuracyMetersPerSecond;
  final double? altitudeMeters;
  final double? altitudeAccuracyMeters;
  final double? headingDegrees;
  final bool headingAvailable;
  final double? headingAccuracyDegrees;

  double get speedKilometersPerHour => speedMetersPerSecond * 3.6;

  Map<String, Object?> toJson() => <String, Object?>{
        'latitude': latitude,
        'longitude': longitude,
        'recordedAt': recordedAt.toIso8601String(),
        'accuracyMeters': accuracyMeters,
        'speedMetersPerSecond': speedMetersPerSecond,
        'speedAvailable': speedAvailable,
        'speedAccuracyMetersPerSecond': speedAccuracyMetersPerSecond,
        'altitudeMeters': altitudeMeters,
        'altitudeAccuracyMeters': altitudeAccuracyMeters,
        'headingDegrees': headingDegrees,
        'headingAvailable': headingAvailable,
        'headingAccuracyDegrees': headingAccuracyDegrees,
      };

  factory MapRoutePoint.fromJson(Map<String, dynamic> json) => MapRoutePoint(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        recordedAt: DateTime.parse(json['recordedAt'] as String),
        accuracyMeters: (json['accuracyMeters'] as num?)?.toDouble() ?? 0,
        speedMetersPerSecond:
            (json['speedMetersPerSecond'] as num?)?.toDouble() ?? 0,
        speedAvailable: json['speedAvailable'] as bool? ?? true,
        speedAccuracyMetersPerSecond:
            (json['speedAccuracyMetersPerSecond'] as num?)?.toDouble(),
        altitudeMeters: (json['altitudeMeters'] as num?)?.toDouble(),
        altitudeAccuracyMeters:
            (json['altitudeAccuracyMeters'] as num?)?.toDouble(),
        headingDegrees: (json['headingDegrees'] as num?)?.toDouble(),
        headingAvailable: json['headingAvailable'] as bool? ?? true,
        headingAccuracyDegrees:
            (json['headingAccuracyDegrees'] as num?)?.toDouble(),
      );
}
