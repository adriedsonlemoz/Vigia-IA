import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/detection.dart';
import 'package:vigiaia/services/detection_merger.dart';

Detection item(double confidence, double xMin) => Detection(
      label: 'person',
      displayLabel: 'Pessoa',
      confidence: confidence,
      box: NormalizedBox(xMin: xMin, yMin: 0.2, xMax: xMin + 0.3, yMax: 0.8),
    );

void main() {
  test('segunda passagem nao duplica a mesma pessoa', () {
    final merged = DetectionMerger.merge(
      [item(0.62, 0.20)],
      [item(0.81, 0.22)],
    );
    expect(merged, hasLength(1));
    expect(merged.single.confidence, 0.81);
  });
}
