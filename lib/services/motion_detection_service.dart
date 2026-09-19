import 'dart:math' as math;
import 'dart:typed_data';

import '../models/detection.dart';
import '../models/rgb_frame.dart';

class MotionDetectionResult {
  const MotionDetectionResult({
    required this.hasMotion,
    required this.cameraMotion,
    required this.changedRatio,
    required this.gridWidth,
    required this.gridHeight,
    required this.mask,
  });

  final bool hasMotion;
  final bool cameraMotion;
  final double changedRatio;
  final int gridWidth;
  final int gridHeight;
  final Uint8List mask;

  bool isBoxMoving(
    NormalizedBox box, {
    double minimumRatio = 0.05,
    double strongLocalRatio = 0.18,
    double minimumEdgeRatio = 0.08,
    int minimumChangedCells = 3,
  }) {
    if (!hasMotion || cameraMotion || mask.isEmpty) return false;

    const expansion = 0.05;
    final xMin = (box.xMin - expansion).clamp(0.0, 1.0);
    final yMin = (box.yMin - expansion).clamp(0.0, 1.0);
    final xMax = (box.xMax + expansion).clamp(0.0, 1.0);
    final yMax = (box.yMax + expansion).clamp(0.0, 1.0);

    final startX =
        (xMin * gridWidth).floor().clamp(0, gridWidth - 1).toInt();
    final endX = math.max(
      startX,
      (xMax * gridWidth).ceil().clamp(1, gridWidth).toInt() - 1,
    );
    final startY =
        (yMin * gridHeight).floor().clamp(0, gridHeight - 1).toInt();
    final endY = math.max(
      startY,
      (yMax * gridHeight).ceil().clamp(1, gridHeight).toInt() - 1,
    );

    final boxWidth = endX - startX + 1;
    final boxHeight = endY - startY + 1;
    final edgeBandX = math.max(1, (boxWidth * 0.18).round());
    final edgeBandY = math.max(1, (boxHeight * 0.18).round());

    var changed = 0;
    var total = 0;
    var edgeChanged = 0;
    var edgeTotal = 0;
    for (var y = startY; y <= endY; y++) {
      final row = y * gridWidth;
      for (var x = startX; x <= endX; x++) {
        final value = mask[row + x];
        total++;
        changed += value;

        final nearHorizontalEdge =
            x - startX < edgeBandX || endX - x < edgeBandX;
        final nearVerticalEdge =
            y - startY < edgeBandY || endY - y < edgeBandY;
        if (nearHorizontalEdge || nearVerticalEdge) {
          edgeTotal++;
          edgeChanged += value;
        }
      }
    }
    if (total == 0) return false;

    final ratio = changed / total;
    final edgeRatio = edgeTotal == 0 ? 0.0 : edgeChanged / edgeTotal;
    final requiredCells = math.min(
      total,
      math.max(minimumChangedCells, (total * minimumRatio).ceil()),
    );
    if (changed < requiredCells || ratio < minimumRatio) return false;

    // Movimento real do objeto tende a alterar sua silhueta/bordas. Uma grande
    // caixa estatica com algo menor se movendo dentro dela (ex.: cama + pe)
    // tende a ter movimento interno, mas bordas estaveis.
    return ratio >= strongLocalRatio || edgeRatio >= minimumEdgeRatio;
  }

  /// Regioes de atencao derivadas das celulas que realmente mudaram. Componentes
  /// separados de movimento nao sao unidos em uma unica janela enorme; isso
  /// preserva o ganho de zoom da segunda passagem da IA.
  List<NormalizedBox> focusRegions({
    int maxRegions = 2,
    double padding = 0.10,
    double minimumSpan = 0.34,
    double maximumArea = 0.58,
    int minimumCells = 2,
  }) {
    if (!hasMotion ||
        cameraMotion ||
        mask.isEmpty ||
        gridWidth <= 0 ||
        gridHeight <= 0 ||
        maxRegions <= 0) {
      return const <NormalizedBox>[];
    }

    final visited = Uint8List(mask.length);
    final components = <_MotionComponent>[];
    const neighborX = <int>[-1, 0, 1, -1, 1, -1, 0, 1];
    const neighborY = <int>[-1, -1, -1, 0, 0, 1, 1, 1];

    for (var y = 0; y < gridHeight; y++) {
      for (var x = 0; x < gridWidth; x++) {
        final index = y * gridWidth + x;
        if (mask[index] == 0 || visited[index] != 0) continue;

        final queueX = <int>[x];
        final queueY = <int>[y];
        visited[index] = 1;
        var head = 0;
        var minX = x;
        var maxX = x;
        var minY = y;
        var maxY = y;
        var cells = 0;

        while (head < queueX.length) {
          final cx = queueX[head];
          final cy = queueY[head];
          head++;
          cells++;
          minX = math.min(minX, cx);
          maxX = math.max(maxX, cx);
          minY = math.min(minY, cy);
          maxY = math.max(maxY, cy);

          for (var i = 0; i < neighborX.length; i++) {
            final nx = cx + neighborX[i];
            final ny = cy + neighborY[i];
            if (nx < 0 || ny < 0 || nx >= gridWidth || ny >= gridHeight) {
              continue;
            }
            final neighborIndex = ny * gridWidth + nx;
            if (mask[neighborIndex] == 0 || visited[neighborIndex] != 0) {
              continue;
            }
            visited[neighborIndex] = 1;
            queueX.add(nx);
            queueY.add(ny);
          }
        }

        if (cells < minimumCells) continue;
        components.add(
          _MotionComponent(
            minX: minX,
            minY: minY,
            maxX: maxX,
            maxY: maxY,
            cells: cells,
          ),
        );
      }
    }

    components.sort((a, b) => b.cells.compareTo(a.cells));
    final result = <NormalizedBox>[];
    for (final component in components) {
      final box = _expandedFocusBox(
        component,
        padding: padding,
        minimumSpan: minimumSpan,
        maximumArea: maximumArea,
      );
      if (box == null) continue;
      final duplicate = result.any((existing) => _iou(existing, box) >= 0.70);
      if (!duplicate) result.add(box);
      if (result.length >= maxRegions) break;
    }
    return List<NormalizedBox>.unmodifiable(result);
  }

  /// Compatibilidade com a passagem focada anterior: retorna a principal
  /// regiao de movimento, agora sem englobar componentes distantes.
  NormalizedBox? focusRegion({
    double padding = 0.10,
    double minimumSpan = 0.34,
    double maximumArea = 0.58,
  }) {
    final regions = focusRegions(
      maxRegions: 1,
      padding: padding,
      minimumSpan: minimumSpan,
      maximumArea: maximumArea,
    );
    return regions.isEmpty ? null : regions.first;
  }

  NormalizedBox? _expandedFocusBox(
    _MotionComponent component, {
    required double padding,
    required double minimumSpan,
    required double maximumArea,
  }) {
    var xMin = component.minX / gridWidth;
    var yMin = component.minY / gridHeight;
    var xMax = (component.maxX + 1) / gridWidth;
    var yMax = (component.maxY + 1) / gridHeight;

    xMin = (xMin - padding).clamp(0.0, 1.0).toDouble();
    yMin = (yMin - padding).clamp(0.0, 1.0).toDouble();
    xMax = (xMax + padding).clamp(0.0, 1.0).toDouble();
    yMax = (yMax + padding).clamp(0.0, 1.0).toDouble();

    final centerX = (xMin + xMax) / 2;
    final centerY = (yMin + yMax) / 2;
    final width = math.max(minimumSpan, xMax - xMin).clamp(0.0, 1.0).toDouble();
    final height = math.max(minimumSpan, yMax - yMin).clamp(0.0, 1.0).toDouble();

    var expandedXMin = centerX - width / 2;
    var expandedXMax = centerX + width / 2;
    var expandedYMin = centerY - height / 2;
    var expandedYMax = centerY + height / 2;
    if (expandedXMin < 0) {
      expandedXMax -= expandedXMin;
      expandedXMin = 0;
    }
    if (expandedXMax > 1) {
      expandedXMin -= expandedXMax - 1;
      expandedXMax = 1;
    }
    if (expandedYMin < 0) {
      expandedYMax -= expandedYMin;
      expandedYMin = 0;
    }
    if (expandedYMax > 1) {
      expandedYMin -= expandedYMax - 1;
      expandedYMax = 1;
    }

    final area = (expandedXMax - expandedXMin) * (expandedYMax - expandedYMin);
    if (area <= 0 || area > maximumArea) return null;
    return NormalizedBox(
      xMin: expandedXMin.clamp(0.0, 1.0).toDouble(),
      yMin: expandedYMin.clamp(0.0, 1.0).toDouble(),
      xMax: expandedXMax.clamp(0.0, 1.0).toDouble(),
      yMax: expandedYMax.clamp(0.0, 1.0).toDouble(),
    );
  }

  double _iou(NormalizedBox a, NormalizedBox b) {
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

class _MotionComponent {
  const _MotionComponent({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
    required this.cells,
  });

  final int minX;
  final int minY;
  final int maxX;
  final int maxY;
  final int cells;
}

class MotionDetectionService {
  MotionDetectionService({
    this.pixelDifferenceThreshold = 26,
    this.colorDifferenceThreshold = 42,
    this.minimumSceneChangeRatio = 0.012,
    this.cameraMotionRatio = 0.48,
  });

  /// Limiar de luminância preservado para compatibilidade com o detector
  /// anterior. A diferença RGB abaixo complementa esse sinal para movimentos
  /// cuja cor muda bastante sem alterar muito o brilho.
  final int pixelDifferenceThreshold;
  final int colorDifferenceThreshold;
  final double minimumSceneChangeRatio;
  final double cameraMotionRatio;

  Uint8List? _previousRgb;
  int _previousGridWidth = 0;
  int _previousGridHeight = 0;

  MotionDetectionResult analyze(RgbFrame frame) {
    final landscape = frame.width >= frame.height;
    final gridWidth = landscape ? 96 : 64;
    final gridHeight = math.max(
      1,
      (gridWidth * frame.height / frame.width).round(),
    );
    final currentRgb = Uint8List(gridWidth * gridHeight * 3);

    for (var gy = 0; gy < gridHeight; gy++) {
      final sourceY = math.min(
        frame.height - 1,
        ((gy + 0.5) * frame.height / gridHeight).floor(),
      );
      for (var gx = 0; gx < gridWidth; gx++) {
        final sourceX = math.min(
          frame.width - 1,
          ((gx + 0.5) * frame.width / gridWidth).floor(),
        );
        final sourceOffset = (sourceY * frame.width + sourceX) * 3;
        if (sourceOffset + 2 >= frame.rgbBytes.length) continue;
        final targetOffset = (gy * gridWidth + gx) * 3;
        currentRgb[targetOffset] = frame.rgbBytes[sourceOffset];
        currentRgb[targetOffset + 1] = frame.rgbBytes[sourceOffset + 1];
        currentRgb[targetOffset + 2] = frame.rgbBytes[sourceOffset + 2];
      }
    }

    final previous = _previousRgb;
    final sameGrid = previous != null &&
        _previousGridWidth == gridWidth &&
        _previousGridHeight == gridHeight;
    _previousRgb = currentRgb;
    _previousGridWidth = gridWidth;
    _previousGridHeight = gridHeight;

    if (!sameGrid) {
      return MotionDetectionResult(
        hasMotion: false,
        cameraMotion: false,
        changedRatio: 0,
        gridWidth: gridWidth,
        gridHeight: gridHeight,
        mask: Uint8List(gridWidth * gridHeight),
      );
    }

    final previousRgb = previous;
    final mask = Uint8List(gridWidth * gridHeight);
    final colorThresholdSquared = colorDifferenceThreshold * colorDifferenceThreshold;
    var changed = 0;
    for (var i = 0; i < mask.length; i++) {
      final offset = i * 3;
      final r = currentRgb[offset];
      final g = currentRgb[offset + 1];
      final b = currentRgb[offset + 2];
      final previousR = previousRgb[offset];
      final previousG = previousRgb[offset + 1];
      final previousB = previousRgb[offset + 2];

      final currentLuma = (77 * r + 150 * g + 29 * b) >> 8;
      final previousLuma =
          (77 * previousR + 150 * previousG + 29 * previousB) >> 8;
      final luminanceChanged =
          (currentLuma - previousLuma).abs() >= pixelDifferenceThreshold;
      final dr = r - previousR;
      final dg = g - previousG;
      final db = b - previousB;
      final colorDistanceSquared = dr * dr + dg * dg + db * db;
      final chromaChanged = colorDistanceSquared >= colorThresholdSquared;

      if (luminanceChanged || chromaChanged) {
        mask[i] = 1;
        changed++;
      }
    }

    final changedRatio = changed / mask.length;
    final spreadBlocks = _changedMacroBlocks(mask, gridWidth, gridHeight);
    final cameraMotion = changedRatio >= cameraMotionRatio ||
        (changedRatio >= 0.12 && spreadBlocks >= 12);
    return MotionDetectionResult(
      hasMotion: !cameraMotion && changedRatio >= minimumSceneChangeRatio,
      cameraMotion: cameraMotion,
      changedRatio: changedRatio,
      gridWidth: gridWidth,
      gridHeight: gridHeight,
      mask: mask,
    );
  }

  int _changedMacroBlocks(Uint8List mask, int width, int height) {
    const blocksX = 4;
    const blocksY = 4;
    var active = 0;

    for (var by = 0; by < blocksY; by++) {
      final y0 = by * height ~/ blocksY;
      final y1 = (by + 1) * height ~/ blocksY;
      for (var bx = 0; bx < blocksX; bx++) {
        final x0 = bx * width ~/ blocksX;
        final x1 = (bx + 1) * width ~/ blocksX;
        var changed = 0;
        var total = 0;
        for (var y = y0; y < y1; y++) {
          final row = y * width;
          for (var x = x0; x < x1; x++) {
            total++;
            changed += mask[row + x];
          }
        }
        if (total > 0 && changed / total >= 0.05) active++;
      }
    }
    return active;
  }

  void reset() {
    _previousRgb = null;
    _previousGridWidth = 0;
    _previousGridHeight = 0;
  }
}
