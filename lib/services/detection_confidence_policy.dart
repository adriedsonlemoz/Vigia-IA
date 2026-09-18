import 'dart:math' as math;

import '../models/detection.dart';
import '../models/object_filter_catalog.dart';

/// Mantém o ajuste de confiança do usuário como referência, mas permite que
/// classes conhecidamente difíceis (principalmente animais pequenos) entrem
/// como candidatas alguns pontos abaixo do limiar global. Essas candidatas só
/// são promovidas após confirmação temporal.
class DetectionConfidencePolicy {
  const DetectionConfidencePolicy._();

  static double candidateThreshold(double baseThreshold) =>
      math.max(0.30, baseThreshold - 0.10).toDouble();

  static double acceptedThreshold(String label, double baseThreshold) {
    final offset = ObjectFilterCatalog.people.contains(label)
        ? 0.06
        : ObjectFilterCatalog.animals.contains(label)
            ? 0.10
            : ObjectFilterCatalog.vehicles.contains(label)
                ? 0.04
                : 0.0;
    return (baseThreshold - offset).clamp(0.30, 0.95).toDouble();
  }

  static bool isCandidate(Detection detection, double baseThreshold) =>
      detection.confidence >= acceptedThreshold(detection.label, baseThreshold);

  static bool isStrong(Detection detection, double baseThreshold) =>
      detection.confidence >= baseThreshold;
}
