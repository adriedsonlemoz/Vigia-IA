import 'dart:math' as math;

import '../models/detection.dart';

class DetectionMerger {
  const DetectionMerger._();

  static List<Detection> merge(
    Iterable<Detection> first,
    Iterable<Detection> second, {
    double duplicateIou = 0.45,
  }) {
    final ordered = <Detection>[...first, ...second]
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    final result = <Detection>[];
    for (final detection in ordered) {
      final duplicate = result.any(
        (existing) =>
            existing.label == detection.label &&
            _iou(existing.box, detection.box) >= duplicateIou,
      );
      if (!duplicate) result.add(detection);
    }
    return List<Detection>.unmodifiable(result);
  }

  static double _iou(NormalizedBox a, NormalizedBox b) {
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
