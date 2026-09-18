import 'dart:typed_data';

import 'package:vigiaia/models/detection.dart';
import 'package:vigiaia/models/rgb_frame.dart';
import 'package:vigiaia/services/motion_detection_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RgbFrame frameWithSquare({
    required int width,
    required int height,
    int squareStart = -1,
    int squareEnd = -1,
  }) {
    final bytes = Uint8List(width * height * 3);
    if (squareStart >= 0) {
      for (var y = squareStart; y < squareEnd; y++) {
        for (var x = squareStart; x < squareEnd; x++) {
          final offset = (y * width + x) * 3;
          bytes[offset] = 255;
          bytes[offset + 1] = 255;
          bytes[offset + 2] = 255;
        }
      }
    }
    return RgbFrame(
      width: width,
      height: height,
      rgbBytes: bytes,
      capturedAt: DateTime(2026, 1, 1),
    );
  }

  test('primeiro frame cria referencia e cena parada nao gera movimento', () {
    final motion = MotionDetectionService();
    final first = motion.analyze(frameWithSquare(width: 100, height: 100));
    final second = motion.analyze(frameWithSquare(width: 100, height: 100));

    expect(first.hasMotion, isFalse);
    expect(second.hasMotion, isFalse);
  });

  test('movimento localizado ativa cena e caixa correspondente', () {
    final motion = MotionDetectionService();
    motion.analyze(frameWithSquare(width: 100, height: 100));
    final result = motion.analyze(
      frameWithSquare(
        width: 100,
        height: 100,
        squareStart: 30,
        squareEnd: 70,
      ),
    );

    const movingBox = NormalizedBox(
      yMin: 0.25,
      xMin: 0.25,
      yMax: 0.75,
      xMax: 0.75,
    );
    const staticBox = NormalizedBox(
      yMin: 0.0,
      xMin: 0.0,
      yMax: 0.2,
      xMax: 0.2,
    );

    expect(result.hasMotion, isTrue);
    expect(result.cameraMotion, isFalse);
    expect(result.isBoxMoving(movingBox), isTrue);
    expect(result.isBoxMoving(staticBox), isFalse);
  });

  test('objeto grande parado nao herda movimento pequeno no centro', () {
    final motion = MotionDetectionService();
    motion.analyze(frameWithSquare(width: 100, height: 100));
    final result = motion.analyze(
      frameWithSquare(
        width: 100,
        height: 100,
        squareStart: 40,
        squareEnd: 60,
      ),
    );

    const movingSmallObject = NormalizedBox(
      yMin: 0.35,
      xMin: 0.35,
      yMax: 0.65,
      xMax: 0.65,
    );
    const largeStaticObject = NormalizedBox(
      yMin: 0.05,
      xMin: 0.05,
      yMax: 0.95,
      xMax: 0.95,
    );

    expect(result.hasMotion, isTrue);
    expect(result.isBoxMoving(movingSmallObject), isTrue);
    expect(result.isBoxMoving(largeStaticObject), isFalse);
  });

  test('mudanca quase total e tratada como movimento da camera', () {
    final motion = MotionDetectionService();
    motion.analyze(frameWithSquare(width: 100, height: 100));
    final result = motion.analyze(
      frameWithSquare(
        width: 100,
        height: 100,
        squareStart: 0,
        squareEnd: 100,
      ),
    );

    expect(result.cameraMotion, isTrue);
    expect(result.hasMotion, isFalse);
  });

  test('regiao de foco amplia movimento localizado sem usar a tela inteira', () {
    final mask = Uint8List(100);
    for (var y = 4; y <= 5; y++) {
      for (var x = 4; x <= 5; x++) {
        mask[y * 10 + x] = 1;
      }
    }
    final result = MotionDetectionResult(
      hasMotion: true,
      cameraMotion: false,
      changedRatio: 0.04,
      gridWidth: 10,
      gridHeight: 10,
      mask: mask,
    );
    final focus = result.focusRegion();
    expect(focus, isNotNull);
    expect(focus!.xMax - focus.xMin, greaterThanOrEqualTo(0.35));
    expect(focus.yMax - focus.yMin, greaterThanOrEqualTo(0.35));
    expect(
      (focus.xMax - focus.xMin) * (focus.yMax - focus.yMin),
      lessThan(0.62),
    );
  });

}
