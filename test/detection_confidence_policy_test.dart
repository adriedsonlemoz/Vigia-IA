import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/detection.dart';
import 'package:vigiaia/services/detection_confidence_policy.dart';

Detection detection(String label, double confidence, double size) => Detection(
      label: label,
      displayLabel: label,
      confidence: confidence,
      box: NormalizedBox(
        xMin: 0.2,
        yMin: 0.2,
        xMax: 0.2 + size,
        yMax: 0.2 + size,
      ),
    );

void main() {
  test('animais recebem margem maior que pessoas e veiculos', () {
    const base = 0.55;
    expect(DetectionConfidencePolicy.acceptedThreshold('dog', base), closeTo(0.43, 0.0001));
    expect(DetectionConfidencePolicy.acceptedThreshold('person', base), closeTo(0.47, 0.0001));
    expect(DetectionConfidencePolicy.acceptedThreshold('car', base), closeTo(0.49, 0.0001));
  });

  test('limiar bruto deixa margem para confirmar objetos pequenos', () {
    expect(DetectionConfidencePolicy.candidateThreshold(0.55), closeTo(0.37, 0.0001));
    expect(DetectionConfidencePolicy.candidateThreshold(0.35), 0.25);
  });

  test('objeto pequeno pode entrar mais baixo mas exige mais confirmacoes', () {
    const base = 0.55;
    final tinyDog = detection('dog', 0.39, 0.10);
    expect(DetectionConfidencePolicy.isCandidate(tinyDog, base), isTrue);
    expect(DetectionConfidencePolicy.confirmationHits(tinyDog, base), 3);
  });
}
