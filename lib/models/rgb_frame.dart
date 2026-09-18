import 'dart:typed_data';

class RgbFrame {
  const RgbFrame({
    required this.width,
    required this.height,
    required this.rgbBytes,
    required this.capturedAt,
  });

  final int width;
  final int height;
  final Uint8List rgbBytes;
  final DateTime capturedAt;
}
