import 'dart:math' as math;

import '../models/bike_approach_status.dart';
import '../models/detection.dart';
import '../models/object_filter_catalog.dart';

/// Estimativa visual de aproximacao para o Modo Bike.
///
/// Usa somente a variacao temporal da caixa do veiculo na inferencia principal.
/// Isso permite avisar antes das varreduras auxiliares, historico e gravacao.
/// Nao estima distancia em metros e nao substitui radar/FMCW.
class BikeApproachEstimator {
  BikeApproachEstimator({
    this.trackRetention = const Duration(milliseconds: 2800),
    this.minimumArea = 0.0025,
    this.minimumGrowthRate = 0.10,
  });

  final Duration trackRetention;
  final double minimumArea;
  final double minimumGrowthRate;

  final Map<int, _ApproachTrack> _tracks = <int, _ApproachTrack>{};
  int _nextTrackId = 1;

  BikeApproachStatus update({
    required List<Detection> detections,
    required DateTime now,
    required double baseConfidenceThreshold,
    double warningTtcSeconds = 4.0,
  }) {
    final vehicles = detections
        .where((item) => ObjectFilterCatalog.vehicles.contains(item.label))
        .where((item) => item.confidence >= math.max(0.34, baseConfidenceThreshold - 0.16))
        .toList(growable: false);

    final assignments = _associate(vehicles, now);
    final usedDetections = <int>{};
    final usedTracks = <int>{};

    for (final assignment in assignments) {
      final track = _tracks[assignment.trackId];
      if (track == null) continue;
      usedDetections.add(assignment.detectionIndex);
      usedTracks.add(track.id);
      track.update(vehicles[assignment.detectionIndex], now);
    }

    for (var i = 0; i < vehicles.length; i++) {
      if (usedDetections.contains(i)) continue;
      final track = _ApproachTrack(
        id: _nextTrackId++,
        detection: vehicles[i],
        lastSeen: now,
      );
      _tracks[track.id] = track;
      usedTracks.add(track.id);
    }

    _tracks.removeWhere(
      (_, track) => now.difference(track.lastSeen) > trackRetention,
    );

    final criticalTtc = math.max(1.4, warningTtcSeconds * 0.55).toDouble();
    BikeApproachStatus? best;
    for (final track in _tracks.values) {
      if (!usedTracks.contains(track.id)) continue;
      final status = track.status(
        now: now,
        minimumArea: minimumArea,
        minimumGrowthRate: minimumGrowthRate,
        warningTtcSeconds: warningTtcSeconds,
        criticalTtcSeconds: criticalTtc,
      );
      if (status == null) continue;
      if (best == null || _rank(status.level) > _rank(best.level)) {
        best = status;
      } else if (best.level == status.level) {
        final bestTtc = best.estimatedTtcSeconds ?? double.infinity;
        final candidateTtc = status.estimatedTtcSeconds ?? double.infinity;
        if (candidateTtc < bestTtc) best = status;
      }
    }

    return best ?? BikeApproachStatus.clear(now);
  }

  void reset() {
    _tracks.clear();
    _nextTrackId = 1;
  }

  List<_ApproachAssignment> _associate(List<Detection> detections, DateTime now) {
    final candidates = <_ApproachAssignment>[];
    for (final track in _tracks.values) {
      if (now.difference(track.lastSeen) > trackRetention) continue;
      for (var i = 0; i < detections.length; i++) {
        final detection = detections[i];
        if (!_compatibleLabels(track.detection.label, detection.label)) continue;
        final iou = _iou(track.detection.box, detection.box);
        final distance = _centerDistance(track.detection.box, detection.box);
        if (iou < 0.04 && distance > 0.20) continue;
        final sizeDelta = _sizeDelta(track.detection.box, detection.box);
        if (sizeDelta > 1.25) continue;
        candidates.add(
          _ApproachAssignment(
            trackId: track.id,
            detectionIndex: i,
            score: iou * 3.0 - distance * 1.7 - sizeDelta * 0.35,
          ),
        );
      }
    }
    candidates.sort((a, b) => b.score.compareTo(a.score));
    final usedTracks = <int>{};
    final usedDetections = <int>{};
    final result = <_ApproachAssignment>[];
    for (final candidate in candidates) {
      if (usedTracks.contains(candidate.trackId) ||
          usedDetections.contains(candidate.detectionIndex)) {
        continue;
      }
      usedTracks.add(candidate.trackId);
      usedDetections.add(candidate.detectionIndex);
      result.add(candidate);
    }
    return result;
  }

  bool _compatibleLabels(String a, String b) {
    if (a == b) return true;
    return ObjectFilterCatalog.vehicles.contains(a) &&
        ObjectFilterCatalog.vehicles.contains(b);
  }

  static int _rank(BikeApproachLevel level) => switch (level) {
        BikeApproachLevel.clear => 0,
        BikeApproachLevel.watch => 1,
        BikeApproachLevel.warning => 2,
        BikeApproachLevel.critical => 3,
      };

  static double _area(NormalizedBox box) {
    final width = math.max(0.0, box.xMax - box.xMin);
    final height = math.max(0.0, box.yMax - box.yMin);
    return math.max(0.000001, width * height).toDouble();
  }

  static double _centerDistance(NormalizedBox a, NormalizedBox b) {
    final ax = (a.xMin + a.xMax) / 2;
    final ay = (a.yMin + a.yMax) / 2;
    final bx = (b.xMin + b.xMax) / 2;
    final by = (b.yMin + b.yMax) / 2;
    final dx = ax - bx;
    final dy = ay - by;
    return math.sqrt(dx * dx + dy * dy);
  }

  static double _sizeDelta(NormalizedBox a, NormalizedBox b) =>
      (math.log(_area(a) / _area(b))).abs();

  static double _iou(NormalizedBox a, NormalizedBox b) {
    final left = math.max(a.xMin, b.xMin);
    final top = math.max(a.yMin, b.yMin);
    final right = math.min(a.xMax, b.xMax);
    final bottom = math.min(a.yMax, b.yMax);
    final width = math.max(0.0, right - left).toDouble();
    final height = math.max(0.0, bottom - top).toDouble();
    final intersection = width * height;
    final areaA = _area(a);
    final areaB = _area(b);
    final union = areaA + areaB - intersection;
    return union <= 0 ? 0 : intersection / union;
  }
}

class _ApproachTrack {
  _ApproachTrack({
    required this.id,
    required this.detection,
    required this.lastSeen,
  }) : lastArea = BikeApproachEstimator._area(detection.box);

  final int id;
  Detection detection;
  DateTime lastSeen;
  double lastArea;
  double smoothedScaleGrowth = 0;
  int hits = 1;

  void update(Detection next, DateTime now) {
    final elapsedSeconds = now.difference(lastSeen).inMicroseconds / 1000000.0;
    final nextArea = BikeApproachEstimator._area(next.box);
    if (elapsedSeconds > 0.04 && elapsedSeconds <= 2.5) {
      // Escala linear ~= sqrt(area). Para aproximacao a velocidade relativa
      // aproximadamente constante, d(log(escala))/dt ~= 1 / TTC.
      final previousScale = math.sqrt(lastArea);
      final nextScale = math.sqrt(nextArea);
      final instantGrowth = math.log(nextScale / previousScale) / elapsedSeconds;
      if (instantGrowth.isFinite) {
        final bounded = instantGrowth.clamp(-1.5, 2.5).toDouble();
        smoothedScaleGrowth = hits <= 1
            ? bounded
            : smoothedScaleGrowth * 0.58 + bounded * 0.42;
      }
    }
    detection = next;
    lastSeen = now;
    lastArea = nextArea;
    hits++;
  }

  BikeApproachStatus? status({
    required DateTime now,
    required double minimumArea,
    required double minimumGrowthRate,
    required double warningTtcSeconds,
    required double criticalTtcSeconds,
  }) {
    if (hits < 2 || lastArea < minimumArea) return null;
    if (smoothedScaleGrowth < minimumGrowthRate) return null;
    final ttc = 1 / smoothedScaleGrowth;
    if (!ttc.isFinite || ttc <= 0 || ttc > warningTtcSeconds * 1.7) {
      return null;
    }

    final level = ttc <= criticalTtcSeconds
        ? BikeApproachLevel.critical
        : ttc <= warningTtcSeconds
            ? BikeApproachLevel.warning
            : BikeApproachLevel.watch;
    final temporalConfidence = (hits / 4).clamp(0.0, 1.0).toDouble();
    final growthConfidence =
        ((smoothedScaleGrowth - minimumGrowthRate) / 0.55).clamp(0.0, 1.0).toDouble();
    final confidence = (detection.confidence * 0.55 +
            temporalConfidence * 0.25 +
            growthConfidence * 0.20)
        .clamp(0.0, 1.0)
        .toDouble();

    // Avisos fortes exigem ao menos duas observacoes e confianca combinada.
    // Um candidato fraco pode aparecer como observacao visual, mas nao fala.
    final safeLevel = confidence < 0.52 && level != BikeApproachLevel.watch
        ? BikeApproachLevel.watch
        : level;
    return BikeApproachStatus(
      level: safeLevel,
      updatedAt: now,
      trackId: id,
      label: detection.label,
      estimatedTtcSeconds: ttc,
      growthRatePerSecond: smoothedScaleGrowth,
      confidence: confidence,
    );
  }
}

class _ApproachAssignment {
  const _ApproachAssignment({
    required this.trackId,
    required this.detectionIndex,
    required this.score,
  });

  final int trackId;
  final int detectionIndex;
  final double score;
}
