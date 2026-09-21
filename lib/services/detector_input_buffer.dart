import 'dart:typed_data';

import 'detector_image_transform.dart';

/// Reuses a flat tensor and fuses RGB resize, letterbox and normalization.
/// ByteBuffer input keeps LiteRT's tensor shape fixed (no nested Dart lists).
class DetectorInputBuffer {
  DetectorInputBuffer(this.width, this.height, {required this.floatingPoint})
      : bytes = Uint8List(width * height * 3 * (floatingPoint ? 4 : 1));

  final int width;
  final int height;
  final bool floatingPoint;
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
      floats.fillRange(0, floats.length, -1.0);
    } else {
      bytes.fillRange(0, bytes.length, 0);
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
        final target = ((y + transform.offsetY) * width +
                x + transform.offsetX) * 3;
        for (var channel = 0; channel < 3; channel++) {
          final top = rgb[a + channel] * (1 - fx) + rgb[b + channel] * fx;
          final bottom = rgb[c + channel] * (1 - fx) + rgb[d + channel] * fx;
          final value = top * (1 - fy) + bottom * fy;
          if (floats != null) {
            floats[target + channel] = (value - 127.5) / 127.5;
          } else {
            bytes[target + channel] = value.round().clamp(0, 255).toInt();
          }
        }
      }
    }
    return transform;
  }
}
