import 'package:vigiaia/services/alert_repeat_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('alerta na primeira aparicao e nao repete continuamente', () {
    final guard = AlertRepeatGuard(
      repeatInterval: const Duration(seconds: 60),
      absenceReset: const Duration(seconds: 2),
    );
    final t0 = DateTime(2026, 1, 1, 12);

    expect(guard.evaluate({'person'}, t0), ['person']);
    expect(
      guard.evaluate({'person'}, t0.add(const Duration(seconds: 1))),
      isEmpty,
    );
  });

  test('repete apos o intervalo configurado se ainda estiver visivel', () {
    final guard = AlertRepeatGuard(
      repeatInterval: const Duration(seconds: 10),
      absenceReset: const Duration(seconds: 2),
    );
    final t0 = DateTime(2026, 1, 1, 12);

    guard.evaluate({'car'}, t0);
    expect(
      guard.evaluate({'car'}, t0.add(const Duration(seconds: 10))),
      ['car'],
    );
  });

  test('reaparecimento apos ausencia gera novo alerta', () {
    final guard = AlertRepeatGuard(
      repeatInterval: const Duration(minutes: 5),
      absenceReset: const Duration(seconds: 2),
    );
    final t0 = DateTime(2026, 1, 1, 12);

    expect(guard.evaluate({'dog'}, t0), ['dog']);
    expect(guard.evaluate({}, t0.add(const Duration(seconds: 1))), isEmpty);
    expect(
      guard.evaluate({'dog'}, t0.add(const Duration(seconds: 3))),
      ['dog'],
    );
  });

  test('queda curta de um frame nao reinicia presenca', () {
    final guard = AlertRepeatGuard(
      repeatInterval: const Duration(minutes: 5),
      absenceReset: const Duration(seconds: 2),
    );
    final t0 = DateTime(2026, 1, 1, 12);

    guard.evaluate({'cat'}, t0);
    guard.evaluate({}, t0.add(const Duration(milliseconds: 800)));
    expect(
      guard.evaluate({'cat'}, t0.add(const Duration(milliseconds: 1200))),
      isEmpty,
    );
  });

  test('classes diferentes sao controladas independentemente', () {
    final guard = AlertRepeatGuard(
      repeatInterval: const Duration(minutes: 1),
      absenceReset: const Duration(seconds: 2),
    );
    final t0 = DateTime(2026, 1, 1, 12);

    expect(guard.evaluate({'person', 'car'}, t0).toSet(), {'person', 'car'});
    expect(
      guard.evaluate({'person', 'car'}, t0.add(const Duration(seconds: 1))),
      isEmpty,
    );
  });

  test('reset permite novo alerta imediato', () {
    final guard = AlertRepeatGuard(
      repeatInterval: const Duration(minutes: 5),
      absenceReset: const Duration(seconds: 2),
    );
    final t0 = DateTime(2026, 1, 1, 12);

    guard.evaluate({'person'}, t0);
    guard.reset();
    expect(guard.evaluate({'person'}, t0), ['person']);
  });

  test('modo evento exige confirmacao e nao repete enquanto presente', () {
    final guard = AlertRepeatGuard(
      repeatInterval: const Duration(seconds: 60),
      absenceReset: const Duration(seconds: 3),
      confirmationHits: 2,
      repeatWhilePresent: false,
    );
    final t0 = DateTime(2026, 1, 1, 12);

    expect(guard.evaluate({'person'}, t0), isEmpty);
    expect(
      guard.evaluate({'person'}, t0.add(const Duration(milliseconds: 800))),
      ['person'],
    );
    for (var seconds = 2; seconds <= 70; seconds += 2) {
      expect(
        guard.evaluate({'person'}, t0.add(Duration(seconds: seconds))),
        isEmpty,
      );
    }
  });

  test('modo evento respeita intervalo minimo mesmo apos reaparecer', () {
    final guard = AlertRepeatGuard(
      repeatInterval: const Duration(seconds: 60),
      absenceReset: const Duration(seconds: 3),
      confirmationHits: 2,
      repeatWhilePresent: false,
    );
    final t0 = DateTime(2026, 1, 1, 12);

    guard.evaluate({'bed'}, t0);
    expect(
      guard.evaluate({'bed'}, t0.add(const Duration(milliseconds: 800))),
      ['bed'],
    );
    guard.evaluate({}, t0.add(const Duration(seconds: 4)));
    expect(guard.evaluate({'bed'}, t0.add(const Duration(seconds: 5))), isEmpty);
    expect(
      guard.evaluate({'bed'}, t0.add(const Duration(seconds: 6))),
      isEmpty,
    );
  });
}
