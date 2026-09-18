import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/detection.dart';
import 'package:vigiaia/services/detector_image_transform.dart';

void main() {
  test('letterbox preserva proporcao e remove padding vertical', () {
    final transform = DetectorImageTransform.fit(
      sourceWidth: 720,
      sourceHeight: 480,
      inputWidth: 320,
      inputHeight: 320,
    );

    expect(transform.resizedWidth, 320);
    expect(transform.resizedHeight, 213);
    expect(transform.offsetX, 0);
    expect(transform.offsetY, 53);

    final mapped = transform.mapBoxFromInput(
      NormalizedBox(
        xMin: 0,
        xMax: 1,
        yMin: transform.offsetY / transform.inputHeight,
        yMax: (transform.offsetY + transform.resizedHeight) /
            transform.inputHeight,
      ),
    );
    expect(mapped, isNotNull);
    expect(mapped!.xMin, closeTo(0, 0.001));
    expect(mapped.xMax, closeTo(1, 0.001));
    expect(mapped.yMin, closeTo(0, 0.001));
    expect(mapped.yMax, closeTo(1, 0.001));
  });

  test('caixa inteiramente no padding e descartada', () {
    final transform = DetectorImageTransform.fit(
      sourceWidth: 720,
      sourceHeight: 480,
      inputWidth: 320,
      inputHeight: 320,
    );
    final mapped = transform.mapBoxFromInput(
      const NormalizedBox(xMin: 0.1, xMax: 0.2, yMin: 0.01, yMax: 0.10),
    );
    expect(mapped, isNull);
  });
}
