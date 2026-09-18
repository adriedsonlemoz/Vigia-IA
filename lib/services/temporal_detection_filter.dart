import 'dart:math' as math;

import '../models/detection.dart';
import 'detection_confidence_policy.dart';

/// Estabiliza detecções de baixa confiança sem atrasar detecções fortes.
/// Candidatas abaixo do limiar global precisam aparecer em dois frames
/// próximos e em uma posição compatível antes de serem expostas ao restante do
/// pipeline. Uma detecção confirmada também sobrevive a uma única queda curta.
class TemporalDetectionFilter {
  TemporalDetectionFilter({
    this.memory = const Duration(milliseconds: 1200),
    this.holdConfirmedFor = const Duration(milliseconds: 1100),
    this.weakConfirmationHits = 2,
  }) : assert(weakConfirmationHits >= 2);

  final Duration memory;
  final Duration holdConfirmedFor;
  final int weakConfirmationHits;

  final Map<int, _CandidateTrack> _tracks = <int, _CandidateTrack>{};
  int _nextId = 1;

  List<Detection> apply({
    required Iterable<Detection> candidates,
    required double baseThreshold,
    required DateTime now,
  }) {
    _expire(now);
    final accepted = <Detection>[];
    final usedTracks = <int>{};
    final ordered = candidates
        .where((item) => DetectionConfidencePolicy.isCandidate(item, baseThreshold))
        .toList(growable: false)
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    for (final detection in ordered) {
      final match = _bestMatch(detection, usedTracks, now);
      late final _CandidateTrack track;
      if (match == null) {
        track = _CandidateTrack(
          id: _nextId++,
          detection: detection,
          hits: 1,
          lastSeen: now,
          confirmed: DetectionConfidencePolicy.isStrong(
            detection,
            baseThreshold,
          ),
        );
        _tracks[track.id] = track;
      } else {
        track = match;
        final continuous = now.difference(track.lastSeen) <= memory;
        track
          ..detection = detection
          ..lastSeen = now
          ..hits = continuous ? track.hits + 1 : 1;
        if (DetectionConfidencePolicy.isStrong(detection, baseThreshold) ||
            track.hits >= weakConfirmationHits) {
          track.confirmed = true;
        }
      }
      usedTracks.add(track.id);
      if (track.confirmed) accepted.add(detection);
    }

    for (final track in _tracks.values) {
      if (usedTracks.contains(track.id) || !track.confirmed) continue;
      if (now.difference(track.lastSeen) <= holdConfirmedFor) {
        accepted.add(track.detection);
      }
    }

    return List<Detection>.unmodifiable(_deduplicate(accepted));
  }

  void reset() {
    _tracks.clear();
    _nextId = 1;
  }

  _CandidateTrack? _bestMatch(
    Detection detection,
    Set<int> usedTracks,
    DateTime now,
  ) {
    _CandidateTrack? best;
    var bestScore = double.negativeInfinity;
    for (final track in _tracks.values) {
      if (usedTracks.contains(track.id) || track.detection.label != detection.label) {
        continue;
      }
      if (now.difference(track.lastSeen) > memory) continue;
      final iou = _iou(track.detection.box, detection.box);
      final distance = _centerDistance(track.detection.box, detection.box);
      if (iou < 0.08 && distance > 0.18) continue;
      final score = iou * 2.5 - distance;
      if (score > bestScore) {
        bestScore = score;
        best = track;
      }
    }
    return best;
  }

  void _expire(DateTime now) {
    final expired = _tracks.entries
        .where((entry) => now.difference(entry.value.lastSeen) > memory)
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final id in expired) {
      _tracks.remove(id);
    }
  }

  List<Detection> _deduplicate(List<Detection> detections) {
    final result = <Detection>[];
    final sorted = [...detections]
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    for (final detection in sorted) {
      final duplicate = result.any(
        (existing) =>
            existing.label == detection.label &&
            _iou(existing.box, detection.box) >= 0.45,
      );
      if (!duplicate) result.add(detection);
    }
    return result;
  }

  double _centerDistance(NormalizedBox a, NormalizedBox b) {
    final ax = (a.xMin + a.xMax) / 2;
    final ay = (a.yMin + a.yMax) / 2;
    final bx = (b.xMin + b.xMax) / 2;
    final by = (b.yMin + b.yMax) / 2;
    return math.sqrt(math.pow(ax - bx, 2) + math.pow(ay - by, 2));
  }

  double _iou(NormalizedBox a, NormalizedBox b) {
    final left = math.max(a.xMin, b.xMin);
    final top = math.max(a.yMin, b.yMin);
    final right = math.min(a.xMax, b.xMax);
    final bottom = math.min(a.yMax, b.yMax);
    final intersection =
        math.max(0.0, right - left) * math.max(0.0, bottom - top);
    final areaA = math.max(0.0, a.xMax - a.xMin) *
        math.max(0.0, a.yMax - a.yMin);
    final areaB = math.max(0.0, b.xMax - b.xMin) *
        math.max(0.0, b.yMax - b.yMin);
    final union = areaA + areaB - intersection;
    return union <= 0 ? 0.0 : intersection / union;
  }
}

class _CandidateTrack {
  _CandidateTrack({
    required this.id,
    required this.detection,
    required this.hits,
    required this.lastSeen,
    required this.confirmed,
  });

  final int id;
  Detection detection;
  int hits;
  DateTime lastSeen;
  bool confirmed;
}
