import 'package:vigiaia/models/smart_alert_rules.dart';
import 'package:vigiaia/services/smart_alert_rule_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SmartAlertRuleEngine engine(SmartAlertRules rules) => SmartAlertRuleEngine(
        rules,
        absenceReset: const Duration(seconds: 2),
      );

  test('pessoa pode ser liberada imediatamente', () {
    final rules = const SmartAlertRules(
      personMinimumPresence: Duration.zero,
    );
    final subject = engine(rules);
    final now = DateTime(2026, 1, 1, 12);

    expect(
      subject.evaluate(
        visibleLabels: {'person'},
        movingLabels: {'person'},
        now: now,
      ),
      {'person'},
    );
  });

  test('animal respeita tempo minimo de permanencia', () {
    final rules = const SmartAlertRules(
      animalMinimumPresence: Duration(seconds: 3),
    );
    final subject = engine(rules);
    final now = DateTime(2026, 1, 1, 12);

    expect(
      subject.evaluate(
        visibleLabels: {'dog'},
        movingLabels: {'dog'},
        now: now,
      ),
      isEmpty,
    );
    expect(
      subject.evaluate(
        visibleLabels: {'dog'},
        movingLabels: {'dog'},
        now: now.add(const Duration(seconds: 2)),
      ),
      isEmpty,
    );
    expect(
      subject.evaluate(
        visibleLabels: {'dog'},
        movingLabels: {'dog'},
        now: now.add(const Duration(seconds: 3)),
      ),
      {'dog'},
    );
  });

  test('veiculo parado e ignorado quando a regra esta ativa', () {
    final rules = const SmartAlertRules(
      vehicleMinimumPresence: Duration.zero,
      ignoreStationaryVehicles: true,
    );
    final subject = engine(rules);
    final now = DateTime(2026, 1, 1, 12);

    expect(
      subject.evaluate(
        visibleLabels: {'car'},
        movingLabels: const <String>{},
        now: now,
      ),
      isEmpty,
    );
    expect(
      subject.evaluate(
        visibleLabels: {'car'},
        movingLabels: {'car'},
        now: now.add(const Duration(seconds: 1)),
      ),
      {'car'},
    );
  });

  test('ausencia longa reinicia o tempo de permanencia', () {
    final rules = const SmartAlertRules(
      animalMinimumPresence: Duration(seconds: 3),
    );
    final subject = engine(rules);
    final now = DateTime(2026, 1, 1, 12);

    subject.evaluate(
      visibleLabels: {'dog'},
      movingLabels: {'dog'},
      now: now,
    );
    subject.evaluate(
      visibleLabels: const <String>{},
      movingLabels: const <String>{},
      now: now.add(const Duration(seconds: 3)),
    );

    expect(
      subject.evaluate(
        visibleLabels: {'dog'},
        movingLabels: {'dog'},
        now: now.add(const Duration(seconds: 4)),
      ),
      isEmpty,
    );
  });

  test('desativar regras libera objetos sem atraso inteligente', () {
    final subject = engine(
      const SmartAlertRules(
        enabled: false,
        animalMinimumPresence: Duration(seconds: 10),
      ),
    );
    final now = DateTime(2026, 1, 1, 12);

    expect(
      subject.evaluate(
        visibleLabels: {'dog'},
        movingLabels: const <String>{},
        now: now,
      ),
      {'dog'},
    );
  });

  test('limite exato de ausencia preserva a mesma presenca', () {
    final subject = engine(
      const SmartAlertRules(
        animalMinimumPresence: Duration(seconds: 3),
      ),
    );
    final now = DateTime(2026, 1, 1, 12);

    expect(
      subject.evaluate(
        visibleLabels: {'dog'},
        movingLabels: {'dog'},
        now: now,
      ),
      isEmpty,
    );
    expect(
      subject.evaluate(
        visibleLabels: {'dog'},
        movingLabels: {'dog'},
        now: now.add(const Duration(seconds: 2)),
      ),
      isEmpty,
    );
    expect(
      subject.evaluate(
        visibleLabels: {'dog'},
        movingLabels: {'dog'},
        now: now.add(const Duration(seconds: 3)),
      ),
      {'dog'},
    );
  });

}
