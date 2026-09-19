import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/detection.dart';
import 'package:vigiaia/services/detection_scan_planner.dart';

Detection item(String label, double xMin, double size, {double confidence = 0.48}) =>
    Detection(
      label: label,
      displayLabel: label,
      confidence: confidence,
      box: NormalizedBox(
        xMin: xMin,
        yMin: 0.3,
        xMax: xMin + size,
        yMax: 0.3 + size,
      ),
    );

void main() {
  test('tiles paisagem cobrem a cena com sobreposicao', () {
    final tiles = DetectionScanPlanner.detailTiles(width: 720, height: 480);
    expect(tiles, hasLength(2));
    expect(tiles.first.xMin, 0.0);
    expect(tiles.first.xMax, 0.64);
    expect(tiles.last.xMin, 0.36);
    expect(tiles.last.xMax, 1.0);
  });

  test('reaquisicao prioriza pessoa que sumiu', () {
    final missing = DetectionScanPlanner.missingPriorityDetection(
      [item('car', 0.6, 0.2), item('person', 0.1, 0.12)],
      [item('car', 0.61, 0.2)],
    );
    expect(missing, isNotNull);
    expect(missing!.label, 'person');
  });

  test('candidato pequeno e fraco solicita varredura detalhada', () {
    expect(
      DetectionScanPlanner.needsDetailScan(
        [item('dog', 0.3, 0.10, confidence: 0.50)],
        0.55,
      ),
      isTrue,
    );
  });
}
