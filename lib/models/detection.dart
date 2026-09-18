class NormalizedBox {
  const NormalizedBox({
    required this.yMin,
    required this.xMin,
    required this.yMax,
    required this.xMax,
  });

  final double yMin;
  final double xMin;
  final double yMax;
  final double xMax;
}

class Detection {
  const Detection({
    required this.label,
    required this.displayLabel,
    required this.confidence,
    required this.box,
  });

  final String label;
  final String displayLabel;
  final double confidence;
  final NormalizedBox box;
}
