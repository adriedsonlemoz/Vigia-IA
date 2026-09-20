import 'dart:typed_data';

class RgbFrame {
  const RgbFrame({
    required this.width,
    required this.height,
    required this.rgbBytes,
    required this.capturedAt,
    this.sourceConversionMs,
    this.sourceTransportMs,
  });

  final int width;
  final int height;
  final Uint8List rgbBytes;
  final DateTime capturedAt;

  /// Tempo gasto antes do Monitor receber RGB utilizável. Na câmera local isso
  /// representa principalmente a conversão YUV/BGRA -> RGB; em fontes
  /// codificadas representa a decodificação JPEG/snapshot quando disponível.
  final double? sourceConversionMs;

  /// Tempo de transporte conhecido pela fonte até este aparelho. É preenchido
  /// apenas quando a fonte consegue medi-lo sem inferir dados inexistentes.
  final double? sourceTransportMs;
}
