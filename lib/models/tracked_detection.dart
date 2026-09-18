import 'detection.dart';

class TrackedDetection {
  const TrackedDetection({
    required this.trackId,
    required this.detection,
  });

  final int trackId;
  final Detection detection;
}

enum ZoneTransitionType { entered, exited }

class ZoneTransition {
  const ZoneTransition({
    required this.type,
    required this.trackId,
    required this.label,
    required this.displayLabel,
    required this.zoneId,
    required this.zoneName,
    required this.occurredAt,
    this.detection,
  });

  final ZoneTransitionType type;
  final int trackId;
  final String label;
  final String displayLabel;
  final String zoneId;
  final String zoneName;
  final DateTime occurredAt;
  final Detection? detection;
}

class TrackingResult {
  const TrackingResult({
    required this.active,
    required this.transitions,
  });

  final List<TrackedDetection> active;
  final List<ZoneTransition> transitions;
}
