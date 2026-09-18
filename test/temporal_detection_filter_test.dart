import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/detection.dart';
import 'package:vigiaia/services/temporal_detection_filter.dart';

Detection detection(String label, double confidence, double x) => Detection(
      label: label,
      displayLabel: label,
      confidence: confidence,
      box: NormalizedBox(xMin: x, yMin: 0.2, xMax: x + 0.2, yMax: 0.7),
    );

void main() {
  test('deteccao forte entra imediatamente', () {
    final filter = TemporalDetectionFilter();
    final now = DateTime(2026, 9, 18, 10);
    final result = filter.apply(
      candidates: [detection('person', 0.70, 0.2)],
      baseThreshold: 0.55,
      now: now,
    );
    expect(result, hasLength(1));
  });

  test('candidata fraca precisa de dois frames coerentes', () {
    final filter = TemporalDetectionFilter();
    final now = DateTime(2026, 9, 18, 10);
    expect(
      filter.apply(
        candidates: [detection('dog', 0.48, 0.2)],
        baseThreshold: 0.55,
        now: now,
      ),
      isEmpty,
    );
    final confirmed = filter.apply(
      candidates: [detection('dog', 0.49, 0.22)],
      baseThreshold: 0.55,
      now: now.add(const Duration(milliseconds: 400)),
    );
    expect(confirmed, hasLength(1));
  });

  test('queda curta de um frame mantem deteccao confirmada', () {
    final filter = TemporalDetectionFilter();
    final now = DateTime(2026, 9, 18, 10);
    filter.apply(
      candidates: [detection('car', 0.75, 0.3)],
      baseThreshold: 0.55,
      now: now,
    );
    final held = filter.apply(
      candidates: const <Detection>[],
      baseThreshold: 0.55,
      now: now.add(const Duration(milliseconds: 900)),
    );
    expect(held, hasLength(1));
  });
}
