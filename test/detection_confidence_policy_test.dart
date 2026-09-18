import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/detection_confidence_policy.dart';

void main() {
  test('animais recebem margem maior que pessoas e veiculos', () {
    const base = 0.55;
    expect(DetectionConfidencePolicy.acceptedThreshold('dog', base), closeTo(0.45, 0.0001));
    expect(DetectionConfidencePolicy.acceptedThreshold('person', base), closeTo(0.49, 0.0001));
    expect(DetectionConfidencePolicy.acceptedThreshold('car', base), closeTo(0.51, 0.0001));
  });

  test('limiar candidato nunca cai abaixo de 30 por cento', () {
    expect(DetectionConfidencePolicy.candidateThreshold(0.35), 0.30);
  });
}
