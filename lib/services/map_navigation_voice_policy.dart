import 'map_navigation_guidance.dart';

class MapNavigationVoiceAnnouncement {
  const MapNavigationVoiceAnnouncement(this.text, {this.highPriority = false});

  final String text;
  final bool highPriority;
}

/// Política pura para instruções faladas. Mantém deduplicação e marcos de
/// distância fora da tela e fora do mecanismo de TTS.
class MapNavigationVoicePolicy {
  static const List<int> maneuverThresholdsMeters = <int>[80, 200, 500, 1000];
  static const Duration minimumManeuverGap = Duration(seconds: 10);

  String? _maneuverInstruction;
  double? _lastManeuverDistanceMeters;
  final Set<int> _announcedThresholds = <int>{};
  DateTime? _lastManeuverAnnouncementAt;
  bool _arrivalAnnounced = false;

  void reset() {
    _maneuverInstruction = null;
    _lastManeuverDistanceMeters = null;
    _announcedThresholds.clear();
    _lastManeuverAnnouncementAt = null;
    _arrivalAnnounced = false;
  }

  void resetManeuver() {
    _maneuverInstruction = null;
    _lastManeuverDistanceMeters = null;
    _announcedThresholds.clear();
    _lastManeuverAnnouncementAt = null;
  }

  MapNavigationVoiceAnnouncement? evaluate(
    MapNavigationProgress? progress, {
    DateTime? now,
  }) {
    if (progress == null) return null;
    final currentTime = now ?? DateTime.now();

    if (progress.arrived) {
      if (_arrivalAnnounced) return null;
      _arrivalAnnounced = true;
      return const MapNavigationVoiceAnnouncement(
        'Você chegou ao destino.',
        highPriority: true,
      );
    }

    final instruction = progress.nextInstruction?.trim();
    final distance = progress.distanceToNextManeuverMeters;
    if (instruction == null || instruction.isEmpty || distance == null) {
      return null;
    }

    final changedInstruction = _maneuverInstruction != instruction;
    final distanceJumped = _lastManeuverDistanceMeters != null &&
        distance > _lastManeuverDistanceMeters! + 150;
    if (changedInstruction || distanceJumped) {
      _maneuverInstruction = instruction;
      _announcedThresholds.clear();
      _lastManeuverAnnouncementAt = null;
    }
    _lastManeuverDistanceMeters = distance;

    int? threshold;
    for (final candidate in maneuverThresholdsMeters) {
      if (distance <= candidate && !_announcedThresholds.contains(candidate)) {
        threshold = candidate;
        break;
      }
    }
    if (threshold == null) return null;

    final lastAt = _lastManeuverAnnouncementAt;
    final urgent = threshold <= 80;
    if (!urgent &&
        lastAt != null &&
        currentTime.difference(lastAt) < minimumManeuverGap) {
      return null;
    }

    _announcedThresholds.addAll(
      maneuverThresholdsMeters.where((candidate) => candidate >= threshold),
    );
    _lastManeuverAnnouncementAt = currentTime;
    return MapNavigationVoiceAnnouncement(
      'Em ${formatDistanceForSpeech(distance)}, $instruction.',
      highPriority: urgent,
    );
  }

  static String formatDistanceForSpeech(double meters) {
    if (meters < 100) {
      final rounded = (meters / 10).round() * 10;
      return '${rounded.clamp(10, 90)} metros';
    }
    if (meters < 1000) {
      final rounded = (meters / 50).round() * 50;
      return '${rounded.clamp(100, 950)} metros';
    }
    final km = meters / 1000;
    final rounded = (km * 10).round() / 10;
    final text = rounded == rounded.roundToDouble()
        ? rounded.toInt().toString()
        : rounded.toStringAsFixed(1).replaceAll('.', ',');
    return '$text ${rounded == 1 ? 'quilômetro' : 'quilômetros'}';
  }
}
