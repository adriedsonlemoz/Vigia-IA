class BikeTravelPreferences {
  const BikeTravelPreferences({
    this.averageSpeedKmh = 15,
    this.ridingHoursPerDay = 5,
    this.balanceDays = true,
  });

  final double averageSpeedKmh;
  final double ridingHoursPerDay;
  final bool balanceDays;

  BikeTravelPreferences copyWith({
    double? averageSpeedKmh,
    double? ridingHoursPerDay,
    bool? balanceDays,
  }) {
    return BikeTravelPreferences(
      averageSpeedKmh: averageSpeedKmh ?? this.averageSpeedKmh,
      ridingHoursPerDay: ridingHoursPerDay ?? this.ridingHoursPerDay,
      balanceDays: balanceDays ?? this.balanceDays,
    );
  }
}

class BikeTripEstimate {
  const BikeTripEstimate({
    required this.distanceMeters,
    required this.ridingDuration,
    required this.dayCount,
    required this.preferences,
  });

  final double distanceMeters;
  final Duration ridingDuration;
  final int dayCount;
  final BikeTravelPreferences preferences;

  double get distanceKm => distanceMeters / 1000;
  double get ridingHours => ridingDuration.inSeconds / 3600;
  double get targetHoursPerDay => dayCount <= 0 ? 0 : ridingHours / dayCount;
}

class BikeTripDayPlan {
  const BikeTripDayPlan({
    required this.day,
    required this.startDistanceMeters,
    required this.endDistanceMeters,
    required this.ridingDuration,
    required this.stopLabel,
    required this.stopLatitude,
    required this.stopLongitude,
    required this.stopKind,
    required this.usesKnownPlace,
  });

  final int day;
  final double startDistanceMeters;
  final double endDistanceMeters;
  final Duration ridingDuration;
  final String stopLabel;
  final double stopLatitude;
  final double stopLongitude;
  final String stopKind;
  final bool usesKnownPlace;

  double get distanceMeters => endDistanceMeters - startDistanceMeters;
}

class BikeTripPlan {
  const BikeTripPlan({
    required this.estimate,
    required this.days,
  });

  final BikeTripEstimate estimate;
  final List<BikeTripDayPlan> days;
}
