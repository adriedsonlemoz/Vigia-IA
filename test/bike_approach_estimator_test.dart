import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/bike_approach_status.dart';
import 'package:vigiaia/models/detection.dart';
import 'package:vigiaia/services/bike_approach_estimator.dart';

void main() {
  Detection vehicle(double size, {double confidence = 0.78}) {
    final half = size / 2;
    return Detection(
      label: 'car',
      displayLabel: 'Automóvel',
      confidence: confidence,
      box: NormalizedBox(
        xMin: 0.5 - half,
        xMax: 0.5 + half,
        yMin: 0.5 - half,
        yMax: 0.5 + half,
      ),
    );
  }

  test('caixa crescendo gera aviso de aproximacao com TTC visual', () {
    final estimator = BikeApproachEstimator();
    final t0 = DateTime(2026, 9, 20, 12);

    expect(
      estimator.update(
        detections: [vehicle(0.10)],
        now: t0,
        baseConfidenceThreshold: 0.55,
      ).level,
      BikeApproachLevel.clear,
    );

    final warning = estimator.update(
      detections: [vehicle(0.12)],
      now: t0.add(const Duration(milliseconds: 500)),
      baseConfidenceThreshold: 0.55,
      warningTtcSeconds: 4,
    );
    expect(warning.level, BikeApproachLevel.warning);
    expect(warning.estimatedTtcSeconds, isNotNull);
    expect(warning.estimatedTtcSeconds!, lessThan(4));

    final critical = estimator.update(
      detections: [vehicle(0.18)],
      now: t0.add(const Duration(seconds: 1)),
      baseConfidenceThreshold: 0.55,
      warningTtcSeconds: 4,
    );
    expect(critical.level, BikeApproachLevel.critical);
    expect(critical.shouldAlert, isTrue);
  });

  test('veiculo afastando nao produz aviso de aproximacao', () {
    final estimator = BikeApproachEstimator();
    final t0 = DateTime(2026, 9, 20, 12);
    estimator.update(
      detections: [vehicle(0.16)],
      now: t0,
      baseConfidenceThreshold: 0.55,
    );
    final status = estimator.update(
      detections: [vehicle(0.13)],
      now: t0.add(const Duration(milliseconds: 500)),
      baseConfidenceThreshold: 0.55,
    );
    expect(status.level, BikeApproachLevel.clear);
  });

  test('objeto nao veicular e ignorado pelo caminho rapido', () {
    final estimator = BikeApproachEstimator();
    final t0 = DateTime(2026, 9, 20, 12);
    const person = Detection(
      label: 'person',
      displayLabel: 'Pessoa',
      confidence: 0.9,
      box: NormalizedBox(xMin: 0.3, xMax: 0.5, yMin: 0.3, yMax: 0.7),
    );
    final status = estimator.update(
      detections: const [person],
      now: t0,
      baseConfidenceThreshold: 0.55,
    );
    expect(status.level, BikeApproachLevel.clear);
  });

  test('reset remove memoria temporal de aproximacao', () {
    final estimator = BikeApproachEstimator();
    final t0 = DateTime(2026, 9, 20, 12);
    estimator.update(
      detections: [vehicle(0.10)],
      now: t0,
      baseConfidenceThreshold: 0.55,
    );
    estimator.reset();
    final status = estimator.update(
      detections: [vehicle(0.16)],
      now: t0.add(const Duration(milliseconds: 500)),
      baseConfidenceThreshold: 0.55,
    );
    expect(status.level, BikeApproachLevel.clear);
  });
}
