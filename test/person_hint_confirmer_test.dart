import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/detection.dart';
import 'package:vigiaia/services/person_hint_confirmer.dart';

Detection hint({double x = 0.3}) => Detection(
      label: 'person',
      displayLabel: 'Possível pessoa',
      confidence: 0.5,
      box: NormalizedBox(xMin: x, yMin: 0.3, xMax: x + 0.3, yMax: 0.7),
      inferred: true,
    );

void main() {
  final start = DateTime(2026, 10, 2, 12);

  test('pista de um único quadro nunca aparece', () {
    final confirmer = PersonHintConfirmer();
    expect(confirmer.apply([hint()], now: start), isEmpty);
    expect(
      confirmer.apply(const <Detection>[], now: start.add(const Duration(milliseconds: 300))),
      isEmpty,
    );
  });

  test('só aparece depois de reaparecer na mesma região em quadros seguidos', () {
    final confirmer = PersonHintConfirmer(requiredHits: 3);
    expect(confirmer.apply([hint()], now: start), isEmpty);
    expect(
      confirmer.apply([hint(x: 0.31)], now: start.add(const Duration(milliseconds: 300))),
      isEmpty,
    );
    final result = confirmer.apply(
      [hint(x: 0.32)],
      now: start.add(const Duration(milliseconds: 600)),
    );
    expect(result, hasLength(1));
    expect(result.single.inferred, isTrue);
    expect(result.single.displayLabel, 'Possível pessoa');
  });

  test('pistas em regiões diferentes não se confirmam entre si', () {
    final confirmer = PersonHintConfirmer(requiredHits: 3);
    confirmer.apply([hint(x: 0.0)], now: start);
    confirmer.apply([hint(x: 0.65)], now: start.add(const Duration(milliseconds: 300)));
    final result = confirmer.apply(
      [hint(x: 0.0)],
      now: start.add(const Duration(milliseconds: 600)),
    );
    expect(result, isEmpty);
  });

  test('pista confirmada some depois do tempo de retenção', () {
    final confirmer = PersonHintConfirmer(
      requiredHits: 2,
      hold: const Duration(milliseconds: 1000),
    );
    confirmer.apply([hint()], now: start);
    expect(
      confirmer.apply([hint()], now: start.add(const Duration(milliseconds: 300))),
      hasLength(1),
    );
    expect(
      confirmer.apply(const <Detection>[], now: start.add(const Duration(milliseconds: 900))),
      hasLength(1),
    );
    expect(
      confirmer.apply(const <Detection>[], now: start.add(const Duration(seconds: 3))),
      isEmpty,
    );
  });

  test('reset descarta o que já estava em confirmação', () {
    final confirmer = PersonHintConfirmer(requiredHits: 2);
    confirmer.apply([hint()], now: start);
    confirmer.reset();
    expect(
      confirmer.apply([hint()], now: start.add(const Duration(milliseconds: 300))),
      isEmpty,
    );
  });
}
