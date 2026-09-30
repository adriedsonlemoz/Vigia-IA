import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/detection.dart';
import 'package:vigiaia/models/rgb_frame.dart';
import 'package:vigiaia/services/object_appearance_service.dart';

void main() {
  RgbFrame personFrame({
    required List<int> upper,
    required List<int> lower,
  }) {
    const width = 100;
    const height = 100;
    final bytes = Uint8List(width * height * 3);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final offset = (y * width + x) * 3;
        final inside = x >= 20 && x < 80 && y >= 10 && y < 90;
        final color = !inside
            ? const <int>[120, 120, 120]
            : y < 52
                ? upper
                : lower;
        bytes[offset] = color[0];
        bytes[offset + 1] = color[1];
        bytes[offset + 2] = color[2];
      }
    }
    return RgbFrame(
      width: width,
      height: height,
      rgbBytes: bytes,
      capturedAt: DateTime(2026, 9, 19),
    );
  }

  const person = Detection(
    label: 'person',
    displayLabel: 'Pessoa',
    confidence: 0.9,
    box: NormalizedBox(xMin: 0.2, yMin: 0.1, xMax: 0.8, yMax: 0.9),
  );

  test('extrai cores aproximadas de roupa superior e inferior', () {
    final appearance = ObjectAppearanceService.describe(
      personFrame(
        upper: const <int>[20, 60, 220],
        lower: const <int>[18, 18, 18],
      ),
      person,
    );

    expect(appearance, isNotNull);
    expect(appearance!.upperColor, 'azul');
    expect(appearance.lowerColor, 'preto');
    expect(appearance.sampleCount, greaterThan(20));
  });

  test('aparencias com roupas parecidas tem similaridade maior', () {
    final blueBlack = ObjectAppearanceService.describe(
      personFrame(
        upper: const <int>[20, 60, 220],
        lower: const <int>[18, 18, 18],
      ),
      person,
    );
    final blueDark = ObjectAppearanceService.describe(
      personFrame(
        upper: const <int>[25, 70, 210],
        lower: const <int>[30, 30, 30],
      ),
      person,
    );
    final redWhite = ObjectAppearanceService.describe(
      personFrame(
        upper: const <int>[220, 30, 30],
        lower: const <int>[240, 240, 240],
      ),
      person,
    );

    final similar = ObjectAppearanceService.similarity(blueBlack, blueDark);
    final different = ObjectAppearanceService.similarity(blueBlack, redWhite);
    expect(similar, greaterThan(different));
    expect(similar, greaterThan(0.65));
  });
}
