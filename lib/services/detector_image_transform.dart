import '../models/detection.dart';

/// Descreve o letterbox usado antes da inferência. A imagem original é
/// redimensionada preservando proporção e centralizada no tensor quadrado do
/// detector; as caixas retornadas pelo modelo são então trazidas de volta para
/// as coordenadas normalizadas do frame original.
class DetectorImageTransform {
  const DetectorImageTransform({
    required this.sourceWidth,
    required this.sourceHeight,
    required this.inputWidth,
    required this.inputHeight,
    required this.resizedWidth,
    required this.resizedHeight,
    required this.offsetX,
    required this.offsetY,
  });

  final int sourceWidth;
  final int sourceHeight;
  final int inputWidth;
  final int inputHeight;
  final int resizedWidth;
  final int resizedHeight;
  final int offsetX;
  final int offsetY;

  factory DetectorImageTransform.fit({
    required int sourceWidth,
    required int sourceHeight,
    required int inputWidth,
    required int inputHeight,
  }) {
    if (sourceWidth <= 0 ||
        sourceHeight <= 0 ||
        inputWidth <= 0 ||
        inputHeight <= 0) {
      throw ArgumentError('Dimensões do detector precisam ser positivas.');
    }
    final widthScale = inputWidth / sourceWidth;
    final heightScale = inputHeight / sourceHeight;
    final scale = widthScale < heightScale ? widthScale : heightScale;
    final resizedWidth = (sourceWidth * scale).round().clamp(1, inputWidth).toInt();
    final resizedHeight = (sourceHeight * scale).round().clamp(1, inputHeight).toInt();
    return DetectorImageTransform(
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      inputWidth: inputWidth,
      inputHeight: inputHeight,
      resizedWidth: resizedWidth,
      resizedHeight: resizedHeight,
      offsetX: (inputWidth - resizedWidth) ~/ 2,
      offsetY: (inputHeight - resizedHeight) ~/ 2,
    );
  }

  NormalizedBox? mapBoxFromInput(NormalizedBox inputBox) {
    final inputXMin = inputBox.xMin * inputWidth;
    final inputYMin = inputBox.yMin * inputHeight;
    final inputXMax = inputBox.xMax * inputWidth;
    final inputYMax = inputBox.yMax * inputHeight;

    final xMin = ((inputXMin - offsetX) / resizedWidth).clamp(0.0, 1.0).toDouble();
    final yMin = ((inputYMin - offsetY) / resizedHeight).clamp(0.0, 1.0).toDouble();
    final xMax = ((inputXMax - offsetX) / resizedWidth).clamp(0.0, 1.0).toDouble();
    final yMax = ((inputYMax - offsetY) / resizedHeight).clamp(0.0, 1.0).toDouble();

    // Caixas inteiramente sobre a faixa de letterbox não representam conteúdo
    // real da câmera e devem ser descartadas.
    if (xMax - xMin <= 0.002 || yMax - yMin <= 0.002) return null;
    return NormalizedBox(xMin: xMin, yMin: yMin, xMax: xMax, yMax: yMax);
  }
}
