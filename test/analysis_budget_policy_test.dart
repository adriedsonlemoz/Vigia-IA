import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/analysis_budget_policy.dart';

void main() {
  test('permite detalhe opcional quando há folga suficiente', () {
    final allowed = AnalysisBudgetPolicy.allowOptionalDetailScan(
      intervalMs: 400,
      elapsedMs: 90,
      estimatedInferenceMs: 80,
    );

    expect(allowed, isTrue);
  });

  test('bloqueia detalhe opcional quando projetaria ultrapassar orçamento', () {
    final allowed = AnalysisBudgetPolicy.allowOptionalDetailScan(
      intervalMs: 400,
      elapsedMs: 280,
      estimatedInferenceMs: 120,
    );

    expect(allowed, isFalse);
  });

  test('reserva margem mínima mesmo em intervalos curtos', () {
    final allowed = AnalysisBudgetPolicy.allowOptionalDetailScan(
      intervalMs: 250,
      elapsedMs: 160,
      estimatedInferenceMs: 40,
    );

    expect(allowed, isFalse);
  });
}
