import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/detection.dart';
import 'package:vigiaia/models/smart_alert_rules.dart';
import 'package:vigiaia/services/alert_repeat_guard.dart';
import 'package:vigiaia/services/detection_cadence_policy.dart';
import 'package:vigiaia/services/detector_runtime_policy.dart';
import 'package:vigiaia/services/smart_alert_rule_engine.dart';
import 'package:vigiaia/services/temporal_detection_filter.dart';

void main() {
  final start = DateTime.utc(2026, 9, 21);
  const dog = Detection(label: 'dog', displayLabel: 'Cachorro', confidence: 0.48,
    box: NormalizedBox(xMin: 0.2, yMin: 0.2, xMax: 0.5, yMax: 0.7));

  test('dois frames lentos confirmam candidato sem perpetuar imagem ausente', () {
    final cadence = DetectionCadencePolicy();
    final filter = TemporalDetectionFilter();
    expect(filter.apply(candidates: [dog], baseThreshold: 0.55, now: start,
      observationWindow: cadence.observe(start)), isEmpty);
    final next = start.add(const Duration(seconds: 10));
    expect(filter.apply(candidates: [dog], baseThreshold: 0.55, now: next,
      observationWindow: cadence.observe(next)), hasLength(1));
    final absent = next.add(const Duration(seconds: 10));
    expect(filter.apply(candidates: [], baseThreshold: 0.55, now: absent,
      observationWindow: cadence.observe(absent)), isEmpty);
  });

  test('permanência e guarda usam a mesma janela sem ignorar regra de veículo parado', () {
    final rules = SmartAlertRuleEngine(const SmartAlertRules(), absenceReset: const Duration(seconds: 1));
    final guard = AlertRepeatGuard(repeatInterval: const Duration(seconds: 60),
        absenceReset: const Duration(seconds: 1), confirmationHits: 2, repeatWhilePresent: false);
    const window = Duration(seconds: 21);
    expect(rules.evaluate(visibleLabels: {'car'}, movingLabels: {}, now: start,
        observationWindow: window), isEmpty);
    final next = start.add(const Duration(seconds: 10));
    expect(rules.evaluate(visibleLabels: {'car'}, movingLabels: {'car'}, now: next,
        observationWindow: window), {'car'});
    expect(guard.evaluate({'car'}, start, observationWindow: window), isEmpty);
    expect(guard.evaluate({'car'}, next, observationWindow: window), ['car']);
    expect(guard.evaluate({'car'}, next.add(const Duration(seconds: 10)),
        observationWindow: window), isEmpty);
  });

  test('evidência forte evita só a confirmação genérica adicional', () {
    final guard = AlertRepeatGuard(repeatInterval: const Duration(seconds: 60),
        absenceReset: const Duration(seconds: 1), confirmationHits: 2);
    expect(guard.evaluate({'person'}, start, immediateKeys: {'person'}), ['person']);
    expect(guard.evaluate({'person'}, start.add(const Duration(milliseconds: 400)),
        immediateKeys: {'person'}), isEmpty);
  });

  test('quadro antigo não vira alerta urgente e janela tem limite', () {
    final cadence = DetectionCadencePolicy()..observe(start);
    expect(cadence.observe(start.add(const Duration(minutes: 1))).inSeconds, 30);
    expect(DetectionCadencePolicy.fresh(start, start.add(const Duration(seconds: 2)),
        DetectionCadencePolicy.urgentFrameMaxAge), isFalse);
    expect(DetectionCadencePolicy.fresh(start, start.add(const Duration(seconds: 6)),
        DetectionCadencePolicy.spokenFrameMaxAge), isFalse);
    cadence.reset();
    expect(cadence.observe(start).inMilliseconds, 1500);
  });

  test('troca de modelo ignora aquecimento e exige lentidão sustentada', () {
    final policy = DetectorRuntimePolicy();
    expect(policy.shouldUseLightModel(10000), isFalse);
    expect(policy.shouldUseLightModel(1500), isFalse);
    expect(policy.shouldUseLightModel(300), isFalse);
    expect(policy.shouldUseLightModel(1500), isFalse);
    expect(policy.shouldUseLightModel(1500), isFalse);
    expect(policy.shouldUseLightModel(1500), isTrue);
    expect(policy.shouldUseLightModel(1500), isFalse);
  });
}
