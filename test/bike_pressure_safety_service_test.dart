import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/bike_pressure_safety_service.dart';

void main() {
  test('queda rápida exige confirmação por leitura subsequente', () {
    final detector = BikeRapidPressureLossDetector();
    final start = DateTime(2026, 9, 26, 12);

    expect(
      detector.addSample(
        BikeTirePosition.front,
        at: start,
        psi: 42,
        minimumSafePsi: 30,
      ),
      isNull,
    );
    expect(
      detector.addSample(
        BikeTirePosition.front,
        at: start.add(const Duration(seconds: 3)),
        psi: 38.5,
        minimumSafePsi: 30,
      ),
      isNull,
    );
    final confirmed = detector.addSample(
      BikeTirePosition.front,
      at: start.add(const Duration(seconds: 5)),
      psi: 31,
      minimumSafePsi: 30,
    );

    expect(confirmed, isNotNull);
    expect(confirmed!.previousPsi, 42);
    expect(confirmed.currentPsi, 31);
    expect(detector.active, contains(BikeTirePosition.front));
  });

  test('leitura isolada fora da janela não confirma perda rápida', () {
    final detector = BikeRapidPressureLossDetector();
    final start = DateTime(2026, 9, 26, 12);
    detector.addSample(
      BikeTirePosition.rear,
      at: start,
      psi: 45,
      minimumSafePsi: 30,
    );
    final result = detector.addSample(
      BikeTirePosition.rear,
      at: start.add(const Duration(seconds: 12)),
      psi: 35,
      minimumSafePsi: 30,
    );
    expect(result, isNull);
    expect(detector.active, isEmpty);
  });

  test('pressão recuperada limpa o estado após leituras estáveis', () {
    final detector = BikeRapidPressureLossDetector();
    final start = DateTime(2026, 9, 26, 12);
    detector.addSample(BikeTirePosition.front, at: start, psi: 42, minimumSafePsi: 30);
    detector.addSample(BikeTirePosition.front, at: start.add(const Duration(seconds: 2)), psi: 38, minimumSafePsi: 30);
    detector.addSample(BikeTirePosition.front, at: start.add(const Duration(seconds: 4)), psi: 31, minimumSafePsi: 30);
    expect(detector.active, isNotEmpty);

    detector.addSample(BikeTirePosition.front, at: start.add(const Duration(seconds: 6)), psi: 42, minimumSafePsi: 30);
    detector.addSample(BikeTirePosition.front, at: start.add(const Duration(seconds: 8)), psi: 42, minimumSafePsi: 30);
    expect(detector.active, isEmpty);
  });
}
