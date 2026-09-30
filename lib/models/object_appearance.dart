class ObjectAppearance {
  const ObjectAppearance({
    required this.histogram,
    required this.dominantColor,
    this.secondaryColor,
    this.upperColor,
    this.lowerColor,
    this.sampleCount = 0,
  });

  /// Histograma normalizado em uma paleta pequena e estável. Ele é usado
  /// somente como pista complementar de identidade; nunca como classificação
  /// principal do objeto.
  final List<double> histogram;
  final String dominantColor;
  final String? secondaryColor;

  /// Para pessoas, representam aproximadamente tronco e pernas. Em veículos e
  /// animais podem permanecer nulos.
  final String? upperColor;
  final String? lowerColor;
  final int sampleCount;

  String get compactDescription {
    if (upperColor != null && lowerColor != null && upperColor != lowerColor) {
      return '$upperColor/$lowerColor';
    }
    if (secondaryColor != null && secondaryColor != dominantColor) {
      return '$dominantColor/$secondaryColor';
    }
    return dominantColor;
  }
}
