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
}

class MotionDetectionService {
  MotionDetectionService({
    this.pixelDifferenceThreshold = 26,
    this.minimumSceneChangeRatio = 0.012,
    this.cameraMotionRatio = 0.48,
  });

  final int pixelDifferenceThreshold;
  final double minimumSceneChangeRatio;
  final double cameraMotionRatio;

  Uint8List? _previousGray;
  int _previousGridWidth = 0;
  int _previousGridHeight = 0;

  MotionDetectionResult analyze(RgbFrame frame) {
    final landscape = frame.width >= frame.height;
    final gridWidth = landscape ? 96 : 64;
    final gridHeight = math.max(
      1,
      (gridWidth * frame.height / frame.width).round(),
    );
    final currentGray = Uint8List(gridWidth * gridHeight);

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
        final offset = (sourceY * frame.width + sourceX) * 3;
        if (offset + 2 >= frame.rgbBytes.length) continue;
        final r = frame.rgbBytes[offset];
        final g = frame.rgbBytes[offset + 1];
        final b = frame.rgbBytes[offset + 2];
        currentGray[gy * gridWidth + gx] =
            ((77 * r + 150 * g + 29 * b) >> 8).clamp(0, 255).toInt();
      }
    }

    final previous = _previousGray;
    final sameGrid = previous != null &&
        _previousGridWidth == gridWidth &&
        _previousGridHeight == gridHeight;
    _previousGray = currentGray;
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

    final previousGray = previous;
    final mask = Uint8List(currentGray.length);
    var changed = 0;
    for (var i = 0; i < currentGray.length; i++) {
      if ((currentGray[i] - previousGray[i]).abs() >= pixelDifferenceThreshold) {
        mask[i] = 1;
        changed++;
      }
    }

    final changedRatio = changed / currentGray.length;
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
    _previousGray = null;
    _previousGridWidth = 0;
    _previousGridHeight = 0;
  }
}
