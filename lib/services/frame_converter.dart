import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../models/rgb_frame.dart';

class CameraPlaneData {
  const CameraPlaneData({
    required this.bytes,
    required this.bytesPerRow,
    required this.bytesPerPixel,
  });

  final Uint8List bytes;
  final int bytesPerRow;
  final int bytesPerPixel;

  Map<String, Object> toMap() => <String, Object>{
        'bytes': bytes,
        'bytesPerRow': bytesPerRow,
        'bytesPerPixel': bytesPerPixel,
      };
}

class CameraFrameData {
  const CameraFrameData({
    required this.width,
    required this.height,
    required this.planes,
    required this.rotationDegrees,
    required this.isBgra,
    required this.mirrorHorizontally,
  });

  final int width;
  final int height;
  final List<CameraPlaneData> planes;
  final int rotationDegrees;
  final bool isBgra;
  final bool mirrorHorizontally;

  Map<String, Object> toMap() => <String, Object>{
        'width': width,
        'height': height,
        'planes': planes.map((plane) => plane.toMap()).toList(),
        'rotationDegrees': rotationDegrees,
        'isBgra': isBgra,
        'mirrorHorizontally': mirrorHorizontally,
      };
}

class FrameConverter {
  static Future<RgbFrame> fromCamera(CameraFrameData data) async {
    final result = await compute(_convertCameraFrame, data.toMap());
    return RgbFrame(
      width: result['width']! as int,
      height: result['height']! as int,
      rgbBytes: result['bytes']! as Uint8List,
      capturedAt: DateTime.now(),
    );
  }

  static Future<RgbFrame> fromEncoded(Uint8List bytes) async {
    final result = await compute(_convertEncodedFrame, bytes);
    return RgbFrame(
      width: result['width']! as int,
      height: result['height']! as int,
      rgbBytes: result['bytes']! as Uint8List,
      capturedAt: DateTime.now(),
    );
  }
}

Map<String, Object> _convertEncodedFrame(Uint8List encoded) {
  final decoded = img.decodeImage(encoded);
  if (decoded == null) {
    throw StateError('Nao foi possivel decodificar o frame RTSP.');
  }
  final normalized = decoded.numChannels >= 3
      ? decoded
      : img.copyResize(decoded, width: decoded.width, height: decoded.height);
  return <String, Object>{
    'width': normalized.width,
    'height': normalized.height,
    'bytes': _rgbBytes(normalized),
  };
}

Map<String, Object> _convertCameraFrame(Map<String, Object?> data) {
  final width = data['width']! as int;
  final height = data['height']! as int;
  final rotation = data['rotationDegrees']! as int;
  final isBgra = data['isBgra']! as bool;
  final mirror = data['mirrorHorizontally']! as bool;
  final planeMaps = (data['planes']! as List<Object?>)
      .cast<Map<Object?, Object?>>();

  var image = img.Image(width: width, height: height, numChannels: 3);

  if (isBgra) {
    final plane = planeMaps.first;
    final bytes = plane['bytes']! as Uint8List;
    final rowStride = plane['bytesPerRow']! as int;
    final pixelStride = math.max(4, plane['bytesPerPixel']! as int);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final offset = y * rowStride + x * pixelStride;
        if (offset + 2 >= bytes.length) continue;
        final b = bytes[offset];
        final g = bytes[offset + 1];
        final r = bytes[offset + 2];
        image.setPixelRgb(x, y, r, g, b);
      }
    }
  } else {
    if (planeMaps.length < 3) {
      throw StateError('Formato YUV inesperado: ${planeMaps.length} planos.');
    }
    final yPlane = planeMaps[0];
    final uPlane = planeMaps[1];
    final vPlane = planeMaps[2];
    final yBytes = yPlane['bytes']! as Uint8List;
    final uBytes = uPlane['bytes']! as Uint8List;
    final vBytes = vPlane['bytes']! as Uint8List;
    final yRowStride = yPlane['bytesPerRow']! as int;
    final uRowStride = uPlane['bytesPerRow']! as int;
    final vRowStride = vPlane['bytesPerRow']! as int;
    final uPixelStride = math.max(1, uPlane['bytesPerPixel']! as int);
    final vPixelStride = math.max(1, vPlane['bytesPerPixel']! as int);

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final yIndex = y * yRowStride + x;
        final uIndex = (y ~/ 2) * uRowStride + (x ~/ 2) * uPixelStride;
        final vIndex = (y ~/ 2) * vRowStride + (x ~/ 2) * vPixelStride;
        if (yIndex >= yBytes.length ||
            uIndex >= uBytes.length ||
            vIndex >= vBytes.length) {
          continue;
        }
        final yValue = yBytes[yIndex].toDouble();
        final uValue = uBytes[uIndex].toDouble() - 128.0;
        final vValue = vBytes[vIndex].toDouble() - 128.0;
        final r = (yValue + 1.402 * vValue).round().clamp(0, 255);
        final g = (yValue - 0.344136 * uValue - 0.714136 * vValue)
            .round()
            .clamp(0, 255);
        final b = (yValue + 1.772 * uValue).round().clamp(0, 255);
        image.setPixelRgb(x, y, r, g, b);
      }
    }
  }

  if (rotation != 0) {
    image = img.copyRotate(image, angle: rotation);
  }
  if (mirror) {
    image = img.flipHorizontal(image);
  }

  return <String, Object>{
    'width': image.width,
    'height': image.height,
    'bytes': _rgbBytes(image),
  };
}

Uint8List _rgbBytes(img.Image image) {
  final bytes = Uint8List(image.width * image.height * 3);
  var offset = 0;
  for (final pixel in image) {
    bytes[offset++] = pixel.r.toInt();
    bytes[offset++] = pixel.g.toInt();
    bytes[offset++] = pixel.b.toInt();
  }
  return bytes;
}
