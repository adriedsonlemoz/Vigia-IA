import 'dart:typed_data';

import 'detector_image_transform.dart';

/// Reuses a flat tensor and fuses RGB resize, letterbox and normalization.
/// ByteBuffer input keeps LiteRT's tensor shape fixed (no nested Dart lists).
enum DetectorPixelNormalization { minusOneToOne, zeroToOne }

class DetectorInputBuffer {
  DetectorInputBuffer(this.width, this.height, {
    required this.floatingPoint,
    this.normalization = DetectorPixelNormalization.minusOneToOne,
    this.channelFirst = false,
    this.padding = 0,
  })
      : bytes = Uint8List(width * height * 3 * (floatingPoint ? 4 : 1));

  final int width;
  final int height;
  final bool floatingPoint;
  final DetectorPixelNormalization normalization;
  final bool channelFirst;
  final int padding;
  final Uint8List bytes;

  DetectorImageTransform fill(Uint8List rgb, int sourceWidth, int sourceHeight) {
    if (rgb.length != sourceWidth * sourceHeight * 3) {
      throw ArgumentError('Tamanho RGB incompatível com o quadro.');
    }
    final transform = DetectorImageTransform.fit(
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      inputWidth: width,
      inputHeight: height,
    );
    final floats = floatingPoint ? bytes.buffer.asFloat32List() : null;
    if (floats != null) {
      floats.fillRange(0, floats.length, normalization == DetectorPixelNormalization.zeroToOne
          ? padding / 255.0 : (padding - 127.5) / 127.5);
    } else {
      bytes.fillRange(0, bytes.length, padding);
    }
    final scaleX = sourceWidth / transform.resizedWidth;
    final scaleY = sourceHeight / transform.resizedHeight;
    for (var y = 0; y < transform.resizedHeight; y++) {
      final sy = ((y + 0.5) * scaleY - 0.5)
          .clamp(0.0, sourceHeight - 1.0);
      final y0 = sy.floor();
      final y1 = y0 + 1 < sourceHeight ? y0 + 1 : y0;
      final fy = sy - y0;
      for (var x = 0; x < transform.resizedWidth; x++) {
        final sx = ((x + 0.5) * scaleX - 0.5)
            .clamp(0.0, sourceWidth - 1.0);
        final x0 = sx.floor();
        final x1 = x0 + 1 < sourceWidth ? x0 + 1 : x0;
        final fx = sx - x0;
        final a = (y0 * sourceWidth + x0) * 3;
        final b = (y0 * sourceWidth + x1) * 3;
        final c = (y1 * sourceWidth + x0) * 3;
        final d = (y1 * sourceWidth + x1) * 3;
        final pixelIndex = (y + transform.offsetY) * width + x + transform.offsetX;
        for (var channel = 0; channel < 3; channel++) {
          final top = rgb[a + channel] * (1 - fx) + rgb[b + channel] * fx;
          final bottom = rgb[c + channel] * (1 - fx) + rgb[d + channel] * fx;
          final value = top * (1 - fy) + bottom * fy;
          final index = channelFirst
              ? channel * width * height + pixelIndex
              : pixelIndex * 3 + channel;
          if (floats != null) {
            floats[index] = normalization == DetectorPixelNormalization.zeroToOne
                ? value / 255.0 : (value - 127.5) / 127.5;
          } else {
            bytes[index] = value.round().clamp(0, 255).toInt();
          }
        }
      }
    }
    return transform;
  }
}
