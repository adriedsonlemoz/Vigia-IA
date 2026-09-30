import 'dart:math' as math;

import '../models/detection.dart';
import '../models/object_filter_catalog.dart';

/// Mantem o limiar escolhido pelo usuario como referencia, mas deixa objetos
/// pequenos/distantes entrarem como candidatos com validacao temporal mais
/// rigorosa. Assim ganhamos alcance sem transformar um unico frame ruidoso em
/// alerta.
class DetectionConfidencePolicy {
  const DetectionConfidencePolicy._();

  /// O detector precisa devolver resultados abaixo dos limites finais para que
  /// o filtro temporal possa confirmar objetos pequenos em varios frames.
  static double candidateThreshold(double baseThreshold) =>
      math.max(0.25, baseThreshold - 0.18).toDouble();

  static double acceptedThreshold(String label, double baseThreshold) {
    final offset = ObjectFilterCatalog.people.contains(label)
        ? 0.08
        : ObjectFilterCatalog.animals.contains(label)
            ? 0.12
            : ObjectFilterCatalog.vehicles.contains(label)
                ? 0.06
                : 0.0;
    return (baseThreshold - offset).clamp(0.28, 0.95).toDouble();
  }

  static double acceptedThresholdForDetection(
    Detection detection,
    double baseThreshold,
  ) {
    final area = boxArea(detection);
    final sizeBonus = area <= 0.015
        ? 0.05
        : area <= 0.04
            ? 0.03
            : area <= 0.08
                ? 0.015
                : 0.0;
    return (acceptedThreshold(detection.label, baseThreshold) - sizeBonus)
        .clamp(0.25, 0.95)
        .toDouble();
  }

  static bool isCandidate(Detection detection, double baseThreshold) =>
      detection.confidence >= acceptedThresholdForDetection(detection, baseThreshold);

  static bool isStrong(Detection detection, double baseThreshold) =>
      detection.confidence >= baseThreshold;

  static int confirmationHits(Detection detection, double baseThreshold) {
    if (isStrong(detection, baseThreshold)) return 1;
    final area = boxArea(detection);
    if (area <= 0.018) return 3;
    if (ObjectFilterCatalog.animals.contains(detection.label) && area <= 0.06) {
      return 3;
    }
    return 2;
  }

  static Duration holdDuration(Detection detection) {
    final area = boxArea(detection);
    if (area <= 0.018) return const Duration(milliseconds: 1500);
    if (ObjectFilterCatalog.people.contains(detection.label)) {
      return const Duration(milliseconds: 1350);
    }
    if (ObjectFilterCatalog.vehicles.contains(detection.label)) {
      return const Duration(milliseconds: 1400);
    }
    return const Duration(milliseconds: 1200);
  }

  static double boxArea(Detection detection) {
    final width = math.max(0.0, detection.box.xMax - detection.box.xMin);
    final height = math.max(0.0, detection.box.yMax - detection.box.yMin);
    return width * height;
  }
}
