class AnalysisBudgetPolicy {
  const AnalysisBudgetPolicy._();

  static bool allowOptionalDetailScan({
    required int intervalMs,
    required double elapsedMs,
    required double estimatedInferenceMs,
  }) {
    final budgetMs = intervalMs.clamp(250, 5000).toDouble();
    final reserveCandidate = budgetMs * 0.15;
    final reserveMs = reserveCandidate < 60 ? 60.0 : reserveCandidate;
    final inferenceEstimate = estimatedInferenceMs < 40
        ? 40.0
        : estimatedInferenceMs;
    return elapsedMs + inferenceEstimate + reserveMs <= budgetMs;
  }
}
