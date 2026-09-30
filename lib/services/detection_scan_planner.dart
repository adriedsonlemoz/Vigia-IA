import 'dart:math' as math;

import '../models/detection.dart';
import '../models/monitoring_zone.dart';
import '../models/object_filter_catalog.dart';
import 'detection_confidence_policy.dart';

/// Planeja passagens auxiliares do detector sem transformar todo frame em
/// multi-inferencia. O objetivo e recuperar objetos pequenos/distantes ou
/// brevemente ocultos com no maximo um recorte extra por ciclo normal.
class DetectionScanPlanner {
  const DetectionScanPlanner._();

  static bool needsDetailScan(
    Iterable<Detection> candidates,
    double baseThreshold,
  ) {
    final list = candidates.toList(growable: false);
    if (list.isEmpty) return true;
    return list.any((item) {
      final area = DetectionConfidencePolicy.boxArea(item);
      final weak = item.confidence < baseThreshold + 0.06;
      return area <= 0.055 && weak;
    });
  }

  /// Retorna uma deteccao anterior que sumiu da passagem atual e merece uma
  /// tentativa localizada. Pessoas tem prioridade; em seguida objetos menores.
  static Detection? missingPriorityDetection(
    Iterable<Detection> previous,
    Iterable<Detection> current,
  ) {
    final currentList = current.toList(growable: false);
    final missing = previous.where((old) {
      return !currentList.any((now) => _samePhysicalObject(old, now));
    }).toList(growable: false);
    if (missing.isEmpty) return null;

    final sorted = [...missing]
      ..sort((a, b) {
        final priority = _classPriority(b.label).compareTo(_classPriority(a.label));
        if (priority != 0) return priority;
        final areaA = DetectionConfidencePolicy.boxArea(a);
        final areaB = DetectionConfidencePolicy.boxArea(b);
        final areaOrder = areaA.compareTo(areaB);
        if (areaOrder != 0) return areaOrder;
        return a.confidence.compareTo(b.confidence);
      });
    return sorted.first;
  }

  static MonitoringZone recoveryZone(
    Detection detection, {
    double padding = 0.18,
    double minimumSpan = 0.42,
    double maximumSpan = 0.78,
  }) {
    final box = detection.box;
    final width = box.xMax - box.xMin;
    final height = box.yMax - box.yMin;
    final centerX = (box.xMin + box.xMax) / 2;
    final centerY = (box.yMin + box.yMax) / 2;
    final targetWidth = math.max(minimumSpan, width + padding * 2)
        .clamp(minimumSpan, maximumSpan)
        .toDouble();
    final targetHeight = math.max(minimumSpan, height + padding * 2)
        .clamp(minimumSpan, maximumSpan)
        .toDouble();
    return _centeredZone(centerX, centerY, targetWidth, targetHeight);
  }

  /// Dois recortes sobrepostos. Em paisagem eles dividem esquerda/direita;
  /// em retrato, topo/base. Alternar entre eles aumenta a resolucao efetiva de
  /// objetos pequenos sem pagar duas inferencias adicionais em todo frame.
  static List<MonitoringZone> detailTiles({
    required int width,
    required int height,
  }) {
    if (width >= height) {
      return const <MonitoringZone>[
        MonitoringZone(xMin: 0.0, yMin: 0.0, xMax: 0.64, yMax: 1.0),
        MonitoringZone(xMin: 0.36, yMin: 0.0, xMax: 1.0, yMax: 1.0),
      ];
    }
    return const <MonitoringZone>[
      MonitoringZone(xMin: 0.0, yMin: 0.0, xMax: 1.0, yMax: 0.64),
      MonitoringZone(xMin: 0.0, yMin: 0.36, xMax: 1.0, yMax: 1.0),
    ];
  }

  static bool _samePhysicalObject(Detection a, Detection b) {
    final groupA = ObjectFilterCatalog.groupKeyForLabel(a.label);
    final groupB = ObjectFilterCatalog.groupKeyForLabel(b.label);
    if (a.label != b.label && (groupA == null || groupA != groupB)) return false;
    final iou = _iou(a.box, b.box);
    if (iou >= 0.12) return true;
    return _centerDistance(a.box, b.box) <= 0.13;
  }

  static int _classPriority(String label) {
    if (ObjectFilterCatalog.people.contains(label)) return 3;
    if (ObjectFilterCatalog.animals.contains(label)) return 2;
    if (ObjectFilterCatalog.vehicles.contains(label)) return 1;
    return 0;
  }

  static MonitoringZone _centeredZone(
    double centerX,
    double centerY,
    double width,
    double height,
  ) {
    var xMin = centerX - width / 2;
    var xMax = centerX + width / 2;
    var yMin = centerY - height / 2;
    var yMax = centerY + height / 2;
    if (xMin < 0) {
      xMax -= xMin;
      xMin = 0;
    }
    if (xMax > 1) {
      xMin -= xMax - 1;
      xMax = 1;
    }
    if (yMin < 0) {
      yMax -= yMin;
      yMin = 0;
    }
    if (yMax > 1) {
      yMin -= yMax - 1;
      yMax = 1;
    }
    return MonitoringZone(
      xMin: xMin.clamp(0.0, 1.0).toDouble(),
      yMin: yMin.clamp(0.0, 1.0).toDouble(),
      xMax: xMax.clamp(0.0, 1.0).toDouble(),
      yMax: yMax.clamp(0.0, 1.0).toDouble(),
    );
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
    final intersection = math.max(0.0, right - left) * math.max(0.0, bottom - top);
    final areaA = math.max(0.0, a.xMax - a.xMin) * math.max(0.0, a.yMax - a.yMin);
    final areaB = math.max(0.0, b.xMax - b.xMin) * math.max(0.0, b.yMax - b.yMin);
    final union = areaA + areaB - intersection;
    return union <= 0 ? 0.0 : intersection / union;
  }
}
