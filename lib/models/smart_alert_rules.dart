import 'object_filter_catalog.dart';

class SmartAlertRules {
  const SmartAlertRules({
    this.enabled = true,
    this.personMinimumPresence = Duration.zero,
    this.vehicleMinimumPresence = const Duration(seconds: 1),
    this.animalMinimumPresence = const Duration(seconds: 3),
    this.otherMinimumPresence = const Duration(seconds: 2),
    this.ignoreStationaryVehicles = true,
  });

  final bool enabled;
  final Duration personMinimumPresence;
  final Duration vehicleMinimumPresence;
  final Duration animalMinimumPresence;
  final Duration otherMinimumPresence;
  final bool ignoreStationaryVehicles;

  Duration minimumPresenceFor(String label) {
    if (ObjectFilterCatalog.people.contains(label)) {
      return personMinimumPresence;
    }
    if (ObjectFilterCatalog.vehicles.contains(label)) {
      return vehicleMinimumPresence;
    }
    if (ObjectFilterCatalog.animals.contains(label)) {
      return animalMinimumPresence;
    }
    return otherMinimumPresence;
  }

  SmartAlertRules copyWith({
    bool? enabled,
    Duration? personMinimumPresence,
    Duration? vehicleMinimumPresence,
    Duration? animalMinimumPresence,
    Duration? otherMinimumPresence,
    bool? ignoreStationaryVehicles,
  }) {
    return SmartAlertRules(
      enabled: enabled ?? this.enabled,
      personMinimumPresence:
          personMinimumPresence ?? this.personMinimumPresence,
      vehicleMinimumPresence:
          vehicleMinimumPresence ?? this.vehicleMinimumPresence,
      animalMinimumPresence:
          animalMinimumPresence ?? this.animalMinimumPresence,
      otherMinimumPresence:
          otherMinimumPresence ?? this.otherMinimumPresence,
      ignoreStationaryVehicles:
          ignoreStationaryVehicles ?? this.ignoreStationaryVehicles,
    );
  }
}
