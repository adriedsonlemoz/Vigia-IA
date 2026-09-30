import 'object_appearance.dart';

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
    this.appearance,
  });

  final String label;
  final String displayLabel;
  final double confidence;
  final NormalizedBox box;
  final ObjectAppearance? appearance;

  Detection copyWith({
    String? label,
    String? displayLabel,
    double? confidence,
    NormalizedBox? box,
    ObjectAppearance? appearance,
  }) =>
      Detection(
        label: label ?? this.label,
        displayLabel: displayLabel ?? this.displayLabel,
        confidence: confidence ?? this.confidence,
        box: box ?? this.box,
        appearance: appearance ?? this.appearance,
      );
}
