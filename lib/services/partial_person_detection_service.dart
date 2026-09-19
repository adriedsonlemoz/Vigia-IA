import 'dart:math' as math;

import '../models/detection.dart';
import '../models/object_filter_catalog.dart';
import '../models/rgb_frame.dart';
import 'motion_detection_service.dart';

/// Gera uma pista complementar de presença humana quando o modelo principal não
/// consegue fechar um corpo inteiro, mas existe uma região móvel grande com cor
/// de pele típica (ex.: mão ou braço muito próximo da câmera).
class PartialPersonDetectionService {
  const PartialPersonDetectionService._();

  static List<Detection> infer(
    RgbFrame frame,
    MotionDetectionResult motion,
    List<Detection> detections,
  ) {
    if (!motion.hasMotion || motion.cameraMotion) {
      return const <Detection>[];
    }
    if (detections.any((item) => ObjectFilterCatalog.people.contains(item.label))) {
      return const <Detection>[];
    }

    final results = <Detection>[];
    final regions = motion.focusRegions(
      maxRegions: 2,
      minimumSpan: 0.16,
      maximumArea: 0.42,
      padding: 0.04,
      minimumCells: 2,
    );
    for (final region in regions) {
      final area = _boxArea(region);
      if (area < 0.025 || area > 0.50) continue;
      if (detections.any((item) => _iou(item.box, region) >= 0.42)) continue;

      final sample = _sampleSkin(frame, region);
      if (sample.count < 90) continue;
      if (sample.skinRatio < 0.16 || sample.skinRatio > 0.88) continue;
      final aspect = _aspectRatio(region);
      if (aspect < 0.18 || aspect > 4.2) continue;

      final confidence = (0.44 + sample.skinRatio * 0.38 + area * 0.28)
          .clamp(0.46, 0.77)
          .toDouble();
      results.add(
        Detection(
          label: 'person',
          displayLabel: 'Pessoa',
          confidence: confidence,
          box: region,
        ),
      );
    }

    return List<Detection>.unmodifiable(results);
  }

  static _SkinSample _sampleSkin(RgbFrame frame, NormalizedBox box) {
    if (frame.width <= 1 || frame.height <= 1) {
      return const _SkinSample(count: 0, skinCount: 0);
    }

    final startX = (box.xMin * frame.width).floor().clamp(0, frame.width - 1).toInt();
    final endX = (box.xMax * frame.width).ceil().clamp(startX + 1, frame.width).toInt();
    final startY = (box.yMin * frame.height).floor().clamp(0, frame.height - 1).toInt();
    final endY = (box.yMax * frame.height).ceil().clamp(startY + 1, frame.height).toInt();
    final spanX = endX - startX;
    final spanY = endY - startY;
    final targetSamples = math.min(1200, math.max(120, spanX * spanY));
    final step = math.max(1, math.sqrt((spanX * spanY) / targetSamples).floor());

    var count = 0;
    var skinCount = 0;
    for (var y = startY; y < endY; y += step) {
      for (var x = startX; x < endX; x += step) {
        final offset = (y * frame.width + x) * 3;
        if (offset + 2 >= frame.rgbBytes.length) continue;
        final r = frame.rgbBytes[offset];
        final g = frame.rgbBytes[offset + 1];
        final b = frame.rgbBytes[offset + 2];
        if (_looksLikeSkin(r, g, b)) skinCount++;
        count++;
      }
    }
    return _SkinSample(count: count, skinCount: skinCount);
  }

  static bool _looksLikeSkin(int r, int g, int b) {
    final maxChannel = math.max(r, math.max(g, b));
    final minChannel = math.min(r, math.min(g, b));
    final classicRule =
        r > 88 && g > 38 && b > 18 && (maxChannel - minChannel) > 12 && r > g && r > b;

    final sum = r + g + b;
    if (sum == 0) return false;
    final nr = r / sum;
    final ng = g / sum;
    final nb = b / sum;
    final normalizedRule = nr > 0.36 && ng > 0.25 && nb > 0.10 && nr > ng && (nr - nb) > 0.08;

    return classicRule || normalizedRule;
  }

  static double _boxArea(NormalizedBox box) =>
      math.max(0.0, box.xMax - box.xMin) * math.max(0.0, box.yMax - box.yMin);

  static double _aspectRatio(NormalizedBox box) {
    final width = math.max(0.0001, box.xMax - box.xMin);
    final height = math.max(0.0001, box.yMax - box.yMin);
    return width / height;
  }

  static double _iou(NormalizedBox a, NormalizedBox b) {
    final left = math.max(a.xMin, b.xMin);
    final top = math.max(a.yMin, b.yMin);
    final right = math.min(a.xMax, b.xMax);
    final bottom = math.min(a.yMax, b.yMax);
    final intersection = math.max(0.0, right - left) * math.max(0.0, bottom - top);
    final union = _boxArea(a) + _boxArea(b) - intersection;
    return union <= 0 ? 0.0 : intersection / union;
  }
}

class _SkinSample {
  const _SkinSample({required this.count, required this.skinCount});

  final int count;
  final int skinCount;

  double get skinRatio => count == 0 ? 0.0 : skinCount / count;
}
