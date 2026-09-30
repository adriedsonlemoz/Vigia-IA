class BikeRideHistoryEntry {
  const BikeRideHistoryEntry({
    required this.startedAt,
    required this.endedAt,
    required this.distanceMeters,
    required this.movingDuration,
    required this.elapsedDuration,
    required this.movingAverageSpeedKmh,
    required this.overallAverageSpeedKmh,
  });

  final DateTime startedAt;
  final DateTime endedAt;
  final double distanceMeters;
  final Duration movingDuration;
  final Duration elapsedDuration;
  final double movingAverageSpeedKmh;
  final double overallAverageSpeedKmh;

  double get distanceKm => distanceMeters / 1000;

  Map<String, Object?> toJson() => <String, Object?>{
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt.toIso8601String(),
        'distanceMeters': distanceMeters,
        'movingDurationSeconds': movingDuration.inSeconds,
        'elapsedDurationSeconds': elapsedDuration.inSeconds,
        'movingAverageSpeedKmh': movingAverageSpeedKmh,
        'overallAverageSpeedKmh': overallAverageSpeedKmh,
      };

  factory BikeRideHistoryEntry.fromJson(Map<String, dynamic> json) =>
      BikeRideHistoryEntry(
        startedAt: DateTime.parse(json['startedAt'] as String),
        endedAt: DateTime.parse(json['endedAt'] as String),
        distanceMeters: (json['distanceMeters'] as num).toDouble(),
        movingDuration: Duration(
          seconds: (json['movingDurationSeconds'] as num).toInt(),
        ),
        elapsedDuration: Duration(
          seconds: (json['elapsedDurationSeconds'] as num).toInt(),
        ),
        movingAverageSpeedKmh:
            (json['movingAverageSpeedKmh'] as num).toDouble(),
        overallAverageSpeedKmh:
            (json['overallAverageSpeedKmh'] as num).toDouble(),
      );
}

class BikeRideHistorySummary {
  const BikeRideHistorySummary({
    required this.rideCount,
    required this.totalDistanceMeters,
    required this.totalMovingDuration,
    required this.learnedMovingSpeedKmh,
    required this.learnedOverallSpeedKmh,
    required this.reliable,
  });

  static const empty = BikeRideHistorySummary(
    rideCount: 0,
    totalDistanceMeters: 0,
    totalMovingDuration: Duration.zero,
    learnedMovingSpeedKmh: null,
    learnedOverallSpeedKmh: null,
    reliable: false,
  );

  final int rideCount;
  final double totalDistanceMeters;
  final Duration totalMovingDuration;
  final double? learnedMovingSpeedKmh;
  final double? learnedOverallSpeedKmh;
  final bool reliable;

  double get totalDistanceKm => totalDistanceMeters / 1000;
}
