import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/detection.dart';
import 'package:vigiaia/services/detection_merger.dart';

Detection item(
  String label,
  double confidence,
  double xMin, {
  double width = 0.3,
}) =>
    Detection(
      label: label,
      displayLabel: label,
      confidence: confidence,
      box: NormalizedBox(
        xMin: xMin,
        yMin: 0.2,
        xMax: xMin + width,
        yMax: 0.8,
      ),
    );

void main() {
  test('segunda passagem nao duplica a mesma pessoa', () {
    final merged = DetectionMerger.merge(
      [item('person', 0.62, 0.20)],
      [item('person', 0.81, 0.22)],
    );
    expect(merged, hasLength(1));
    expect(merged.single.confidence, 0.81);
  });

  test('rotulos de automovel muito sobrepostos nao viram dois objetos', () {
    final merged = DetectionMerger.merge(
      [item('car', 0.76, 0.20)],
      [item('truck', 0.69, 0.205)],
    );
    expect(merged, hasLength(1));
    expect(merged.single.label, 'car');
  });
}
