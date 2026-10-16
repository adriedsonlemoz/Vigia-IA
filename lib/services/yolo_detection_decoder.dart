import 'dart:math' as math;

import '../models/detection.dart';
import 'detector_image_transform.dart';

/// YOLO26 TFLite: saída end-to-end [1,N,6] (xyxy,score,class) ou
/// predições brutas [1,84,N] / [1,N,84] (xywh,80 probabilidades).
/// Coordinates are in pixels of the letterboxed tensor, not normalized.
class YoloDetectionDecoder {
  static List<List<Object>> decode({
    required List<List<double>> output,
    required int tensorWidth,
    required int tensorHeight,
    required DetectorImageTransform transform,
    required List<String> labels,
    required double threshold,
    required int maxResults,
    Set<String>? allowedLabels,
  }) {
    if (output.isEmpty || output.first.isEmpty || labels.length != 80) {
      return const <List<Object>>[];
    }
    final rows = output.length;
    final columns = output.first.length;
    final isEndToEnd = columns == 6;
    final channelFirst = !isEndToEnd && rows == labels.length + 4;
    final candidateFirst = !isEndToEnd && columns == labels.length + 4;
    if (!isEndToEnd && !channelFirst && !candidateFirst) {
      throw StateError('Saída YOLO26 não reconhecida: [$rows,$columns]');
    }

    final candidateCount = channelFirst ? columns : rows;
    final candidates = <List<Object>>[];
    for (var i = 0; i < candidateCount; i++) {
      double value(int field) => channelFirst ? output[field][i] : output[i][field];
      double score;
      int classIndex;
      double x1, y1, x2, y2;
      if (isEndToEnd) {
        score = value(4);
        classIndex = value(5).round();
        x1 = value(0);
        y1 = value(1);
        x2 = value(2);
        y2 = value(3);
      } else {
        classIndex = -1;
        score = threshold;
        for (var c = 0; c < labels.length; c++) {
          final probability = value(4 + c);
          if (probability.isFinite && probability >= score) {
            score = probability;
            classIndex = c;
          }
        }
        if (classIndex < 0) continue;
        final cx = value(0);
        final cy = value(1);
        final w = value(2);
        final h = value(3);
        x1 = cx - w / 2;
        y1 = cy - h / 2;
        x2 = cx + w / 2;
        y2 = cy + h / 2;
      }
      if (!score.isFinite || score < threshold || score > 1 ||
          classIndex < 0 || classIndex >= labels.length ||
          !x1.isFinite || !y1.isFinite || !x2.isFinite || !y2.isFinite) {
        continue;
      }
      final label = labels[classIndex];
      if (allowedLabels != null && !allowedLabels.contains(label)) continue;
      final mapped = transform.mapBoxFromInput(NormalizedBox(
        xMin: (x1 / tensorWidth).clamp(0.0, 1.0).toDouble(),
        yMin: (y1 / tensorHeight).clamp(0.0, 1.0).toDouble(),
        xMax: (x2 / tensorWidth).clamp(0.0, 1.0).toDouble(),
        yMax: (y2 / tensorHeight).clamp(0.0, 1.0).toDouble(),
      ));
      if (mapped == null) continue;
      candidates.add(<Object>[label, score, mapped.yMin, mapped.xMin,
        mapped.yMax, mapped.xMax]);
    }
    candidates.sort((a, b) => (b[1] as double).compareTo(a[1] as double));
    if (isEndToEnd) {
      return candidates.take(maxResults).toList(growable: false);
    }
    // Para cabeças raw, a supressão por classe evita várias caixas no mesmo
    // objeto. Não suprime pessoas e bicicletas sobrepostas entre si.
    final kept = <List<Object>>[];
    for (final item in candidates) {
      if (kept.length >= maxResults) break;
      if (kept.any((other) => other[0] == item[0] && _iou(item, other) > 0.45)) {
        continue;
      }
      kept.add(item);
    }
    return kept;
  }

  static double _iou(List<Object> a, List<Object> b) {
    final y1 = math.max(a[2] as double, b[2] as double);
    final x1 = math.max(a[3] as double, b[3] as double);
    final y2 = math.min(a[4] as double, b[4] as double);
    final x2 = math.min(a[5] as double, b[5] as double);
    final intersection = math.max(0.0, y2 - y1) * math.max(0.0, x2 - x1);
    final areaA = ((a[4] as double) - (a[2] as double)) *
        ((a[5] as double) - (a[3] as double));
    final areaB = ((b[4] as double) - (b[2] as double)) *
        ((b[5] as double) - (b[3] as double));
    final union = areaA + areaB - intersection;
    return union > 0 ? intersection / union : 0;
  }
}
