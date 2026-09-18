import 'dart:math' as math;

import '../models/detection.dart';
import '../models/monitoring_zone.dart';
import '../models/tracked_detection.dart';

class ObjectTracker {
  ObjectTracker({
    this.maxMissing = const Duration(seconds: 3),
    this.maxCenterDistance = 0.28,
    this.minimumIou = 0.02,
  });

  final Duration maxMissing;
  final double maxCenterDistance;
  final double minimumIou;

  final Map<int, _TrackState> _tracks = <int, _TrackState>{};
  int _nextId = 1;

  TrackingResult update({
    required List<Detection> detections,
    required List<MonitoringZoneProfile> zones,
    required DateTime now,
  }) {
    final transitions = <ZoneTransition>[];
    final active = <TrackedDetection>[];
    final assignments = _associateGlobally(detections, now);
    final assignedDetections = <int>{};
    final assignedTracks = <int>{};

    for (final assignment in assignments) {
      final detectionIndex = assignment.detectionIndex;
      final detection = detections[detectionIndex];
      final track = _tracks[assignment.trackId];
      if (track == null) continue;
      assignedDetections.add(detectionIndex);
      assignedTracks.add(track.id);
      _updateTrack(track, detection, zones, now, transitions);
      active.add(TrackedDetection(trackId: track.id, detection: detection));
    }

    for (var i = 0; i < detections.length; i++) {
      if (assignedDetections.contains(i)) continue;
      final detection = detections[i];
      final track = _createTrack(detection, now);
      assignedTracks.add(track.id);
      _updateTrack(track, detection, zones, now, transitions, isNew: true);
      active.add(TrackedDetection(trackId: track.id, detection: detection));
    }

    final expired = <int>[];
    for (final entry in _tracks.entries) {
      final track = entry.value;
      if (assignedTracks.contains(track.id)) continue;
      if (now.difference(track.lastSeen) <= maxMissing) continue;
      for (final zoneId in track.zoneIds) {
        transitions.add(
          ZoneTransition(
            type: ZoneTransitionType.exited,
            trackId: track.id,
            label: track.detection.label,
            displayLabel: track.detection.displayLabel,
            zoneId: zoneId,
            zoneName: track.zoneNames[zoneId] ?? 'Área',
            occurredAt: now,
            detection: track.detection,
          ),
        );
      }
      expired.add(entry.key);
    }
    for (final id in expired) {
      _tracks.remove(id);
    }

    active.sort((a, b) => a.trackId.compareTo(b.trackId));
    return TrackingResult(active: active, transitions: transitions);
  }

  List<_Assignment> _associateGlobally(List<Detection> detections, DateTime now) {
    final candidates = <_Assignment>[];
    for (final track in _tracks.values) {
      if (now.difference(track.lastSeen) > maxMissing) continue;
      for (var i = 0; i < detections.length; i++) {
        final detection = detections[i];
        if (track.detection.label != detection.label) continue;
        final predicted = track.predictedBox(now);
        final iou = _iou(predicted, detection.box);
        final distance = _centerDistance(predicted, detection.box);
        final sizeDelta = _sizeDelta(predicted, detection.box);
        if (iou < minimumIou && distance > maxCenterDistance) continue;
        if (sizeDelta > 1.25) continue;
        final agePenalty = math.min(now.difference(track.lastSeen).inMilliseconds / 4000.0, 1.0);
        final score = iou * 2.8 - distance * 2.1 - sizeDelta * 0.55 - agePenalty * 0.25;
        candidates.add(_Assignment(trackId: track.id, detectionIndex: i, score: score));
      }
    }
    candidates.sort((a, b) => b.score.compareTo(a.score));
    final usedTracks = <int>{};
    final usedDetections = <int>{};
    final result = <_Assignment>[];
    for (final candidate in candidates) {
      if (usedTracks.contains(candidate.trackId) || usedDetections.contains(candidate.detectionIndex)) continue;
      usedTracks.add(candidate.trackId);
      usedDetections.add(candidate.detectionIndex);
      result.add(candidate);
    }
    return result;
  }

  void _updateTrack(
    _TrackState track,
    Detection detection,
    List<MonitoringZoneProfile> zones,
    DateTime now,
    List<ZoneTransition> transitions, {
    bool isNew = false,
  }) {
    final previousDetection = track.detection;
    final previousSeen = track.lastSeen;
    final previousZoneIds = <String>{...track.zoneIds};
    final currentZones = zones.where((zone) => zone.enabled && _inside(detection, zone.zone)).toList(growable: false);
    final currentZoneIds = currentZones.map((zone) => zone.id).toSet();

    for (final zone in currentZones) {
      if (!previousZoneIds.contains(zone.id)) {
        transitions.add(
          ZoneTransition(
            type: ZoneTransitionType.entered,
            trackId: track.id,
            label: detection.label,
            displayLabel: detection.displayLabel,
            zoneId: zone.id,
            zoneName: zone.name,
            occurredAt: now,
            detection: detection,
          ),
        );
      }
    }
    for (final zoneId in previousZoneIds.difference(currentZoneIds)) {
      transitions.add(
        ZoneTransition(
          type: ZoneTransitionType.exited,
          trackId: track.id,
          label: previousDetection.label,
          displayLabel: previousDetection.displayLabel,
          zoneId: zoneId,
          zoneName: track.zoneNames[zoneId] ?? 'Área',
          occurredAt: now,
          detection: previousDetection,
        ),
      );
    }

    if (!isNew) track.updateVelocity(previousDetection.box, detection.box, now.difference(previousSeen));
    track
      ..detection = detection
      ..lastSeen = now
      ..zoneIds = currentZoneIds
      ..zoneNames = <String, String>{for (final zone in currentZones) zone.id: zone.name};
  }

  _TrackState _createTrack(Detection detection, DateTime now) {
    final track = _TrackState(id: _nextId++, detection: detection, lastSeen: now);
    _tracks[track.id] = track;
    return track;
  }

  void reset() {
    _tracks.clear();
    _nextId = 1;
  }

  bool _inside(Detection detection, MonitoringZone zone) {
    final x = (detection.box.xMin + detection.box.xMax) / 2;
    final y = (detection.box.yMin + detection.box.yMax) / 2;
    return zone.contains(x, y);
  }

  double _centerDistance(NormalizedBox a, NormalizedBox b) {
    final ax = (a.xMin + a.xMax) / 2;
    final ay = (a.yMin + a.yMax) / 2;
    final bx = (b.xMin + b.xMax) / 2;
    final by = (b.yMin + b.yMax) / 2;
    return math.sqrt(math.pow(ax - bx, 2) + math.pow(ay - by, 2));
  }

  double _sizeDelta(NormalizedBox a, NormalizedBox b) {
    final areaA = math.max(0.0001, (a.xMax - a.xMin) * (a.yMax - a.yMin));
    final areaB = math.max(0.0001, (b.xMax - b.xMin) * (b.yMax - b.yMin));
    return (math.log(areaA / areaB)).abs();
  }

  double _iou(NormalizedBox a, NormalizedBox b) {
    final left = math.max(a.xMin, b.xMin);
    final top = math.max(a.yMin, b.yMin);
    final right = math.min(a.xMax, b.xMax);
    final bottom = math.min(a.yMax, b.yMax);
    final width = math.max(0.0, right - left).toDouble();
    final height = math.max(0.0, bottom - top).toDouble();
    final intersection = width * height;
    final areaA = math.max(0.0, a.xMax - a.xMin).toDouble() * math.max(0.0, a.yMax - a.yMin).toDouble();
    final areaB = math.max(0.0, b.xMax - b.xMin).toDouble() * math.max(0.0, b.yMax - b.yMin).toDouble();
    final union = areaA + areaB - intersection;
    return union <= 0 ? 0.0 : intersection / union;
  }
}

class _Assignment {
  const _Assignment({required this.trackId, required this.detectionIndex, required this.score});
  final int trackId;
  final int detectionIndex;
  final double score;
}

class _TrackState {
  _TrackState({required this.id, required this.detection, required this.lastSeen});

  final int id;
  Detection detection;
  DateTime lastSeen;
  Set<String> zoneIds = <String>{};
  Map<String, String> zoneNames = <String, String>{};
  double velocityX = 0;
  double velocityY = 0;
  bool hasVelocity = false;

  void updateVelocity(NormalizedBox previous, NormalizedBox current, Duration elapsed) {
    final seconds = elapsed.inMilliseconds / 1000.0;
    if (seconds <= 0 || seconds > 4) return;
    final previousX = (previous.xMin + previous.xMax) / 2;
    final previousY = (previous.yMin + previous.yMax) / 2;
    final currentX = (current.xMin + current.xMax) / 2;
    final currentY = (current.yMin + current.yMax) / 2;
    final instantX = (currentX - previousX) / seconds;
    final instantY = (currentY - previousY) / seconds;

    // A primeira observacao de movimento nao deve ser amortecida contra uma
    // velocidade zero ficticia. Isso atrasava a predicao justamente quando
    // dois objetos iniciavam um cruzamento e podia inverter seus IDs.
    if (!hasVelocity) {
      velocityX = instantX;
      velocityY = instantY;
      hasVelocity = true;
      return;
    }

    velocityX = velocityX * 0.65 + instantX * 0.35;
    velocityY = velocityY * 0.65 + instantY * 0.35;
  }

  NormalizedBox predictedBox(DateTime now) {
    final seconds = math.min(now.difference(lastSeen).inMilliseconds / 1000.0, 1.5);
    final dx = velocityX * seconds;
    final dy = velocityY * seconds;
    final width = detection.box.xMax - detection.box.xMin;
    final height = detection.box.yMax - detection.box.yMin;
    final centerX = ((detection.box.xMin + detection.box.xMax) / 2 + dx)
        .clamp(width / 2, 1 - width / 2)
        .toDouble();
    final centerY = ((detection.box.yMin + detection.box.yMax) / 2 + dy)
        .clamp(height / 2, 1 - height / 2)
        .toDouble();
    return NormalizedBox(
      xMin: (centerX - width / 2).clamp(0.0, 1.0).toDouble(),
      xMax: (centerX + width / 2).clamp(0.0, 1.0).toDouble(),
      yMin: (centerY - height / 2).clamp(0.0, 1.0).toDouble(),
      yMax: (centerY + height / 2).clamp(0.0, 1.0).toDouble(),
    );
  }
}
