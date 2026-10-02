import 'dart:math' as math;

import '../models/detection.dart';

/// Confirma pistas indiretas de presença humana (movimento com cor de pele)
/// antes de elas aparecerem ou gerarem alerta.
///
/// Uma pista isolada, de um único quadro, é ignorada. Ela só vira "possível
/// pessoa" depois de reaparecer em [requiredHits] quadros seguidos, na mesma
/// região, e continua visível por [hold] depois de sumir.
class PersonHintConfirmer {
  PersonHintConfirmer({
    this.requiredHits = 3,
    this.memory = const Duration(milliseconds: 2500),
    this.hold = const Duration(milliseconds: 1500),
  }) : assert(requiredHits >= 2);

  final int requiredHits;
  final Duration memory;
  final Duration hold;

  final Map<int, _HintTrack> _tracks = <int, _HintTrack>{};
  int _nextId = 1;

  List<Detection> apply(
    Iterable<Detection> hints, {
    required DateTime now,
    Duration? observationWindow,
  }) {
    final window = observationWindow != null && observationWindow > memory
        ? observationWindow
        : memory;
    _tracks.removeWhere((_, track) => now.difference(track.lastSeen) > window);

    final used = <int>{};
    final visible = <Detection>[];
    for (final hint in hints) {
      final match = _bestMatch(hint, used);
      if (match == null) {
        final created = _HintTrack(
          id: _nextId++,
          detection: hint,
          hits: 1,
          lastSeen: now,
        );
        _tracks[created.id] = created;
        used.add(created.id);
        continue;
      }
      match.detection = hint;
      match.lastSeen = now;
      match.hits += 1;
      if (match.hits >= requiredHits) match.confirmed = true;
      used.add(match.id);
      if (match.confirmed) visible.add(hint);
    }

    for (final track in _tracks.values) {
      if (used.contains(track.id) || !track.confirmed) continue;
      if (now.difference(track.lastSeen) <= hold) visible.add(track.detection);
    }
    return List<Detection>.unmodifiable(visible);
  }

  void reset() {
    _tracks.clear();
    _nextId = 1;
  }

  _HintTrack? _bestMatch(Detection hint, Set<int> used) {
    _HintTrack? best;
    var bestScore = double.negativeInfinity;
    for (final track in _tracks.values) {
      if (used.contains(track.id)) continue;
      final iou = _iou(track.detection.box, hint.box);
      final distance = _centerDistance(track.detection.box, hint.box);
      if (iou < 0.12 && distance > 0.15) continue;
      final score = iou * 2.5 - distance;
      if (score > bestScore) {
        bestScore = score;
        best = track;
      }
    }
    return best;
  }

  static double _centerDistance(NormalizedBox a, NormalizedBox b) {
    final ax = (a.xMin + a.xMax) / 2;
    final ay = (a.yMin + a.yMax) / 2;
    final bx = (b.xMin + b.xMax) / 2;
    final by = (b.yMin + b.yMax) / 2;
    return math.sqrt(math.pow(ax - bx, 2) + math.pow(ay - by, 2));
  }

  static double _iou(NormalizedBox a, NormalizedBox b) {
    final left = math.max(a.xMin, b.xMin);
    final top = math.max(a.yMin, b.yMin);
    final right = math.min(a.xMax, b.xMax);
    final bottom = math.min(a.yMax, b.yMax);
    final intersection =
        math.max(0.0, right - left) * math.max(0.0, bottom - top);
    final areaA = math.max(0.0, a.xMax - a.xMin) * math.max(0.0, a.yMax - a.yMin);
    final areaB = math.max(0.0, b.xMax - b.xMin) * math.max(0.0, b.yMax - b.yMin);
    final union = areaA + areaB - intersection;
    return union <= 0 ? 0.0 : intersection / union;
  }
}

class _HintTrack {
  _HintTrack({
    required this.id,
    required this.detection,
    required this.hits,
    required this.lastSeen,
  });

  final int id;
  Detection detection;
  int hits;
  DateTime lastSeen;
  bool confirmed = false;
}
