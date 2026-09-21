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
  static Future<RgbFrame> fromCamera(
    CameraFrameData data, {
    DateTime? capturedAt,
  }) async {
    final captured = capturedAt ?? DateTime.now();
    final watch = Stopwatch()..start();
    final result = await compute(_convertCameraFrame, data.toMap());
    watch.stop();
    return RgbFrame(
      width: result['width']! as int,
      height: result['height']! as int,
      rgbBytes: result['bytes']! as Uint8List,
      capturedAt: captured,
      sourceConversionMs: watch.elapsedMicroseconds / 1000.0,
    );
  }

  static Future<RgbFrame> fromEncoded(
    Uint8List bytes, {
    DateTime? capturedAt,
    double? sourceTransportMs,
  }) async {
    final captured = capturedAt ?? DateTime.now();
    final watch = Stopwatch()..start();
    final result = await compute(_convertEncodedFrame, bytes);
    watch.stop();
    return RgbFrame(
      width: result['width']! as int,
      height: result['height']! as int,
      rgbBytes: result['bytes']! as Uint8List,
      capturedAt: captured,
      sourceConversionMs: watch.elapsedMicroseconds / 1000.0,
      sourceTransportMs: sourceTransportMs,
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

  if (width <= 0 || height <= 0 || !const [0, 90, 180, 270].contains(rotation)) {
    throw ArgumentError('Dimensões/rotação inválidas na câmera.');
  }
  final rotated = rotation == 90 || rotation == 270;
  final outputWidth = rotated ? height : width;
  final outputHeight = rotated ? width : height;
  final rgb = Uint8List(outputWidth * outputHeight * 3);

  void writePixel(int x, int y, int r, int g, int b) {
    var ox = x;
    var oy = y;
    switch (rotation) {
      case 90:
        ox = height - 1 - y;
        oy = x;
      case 180:
        ox = width - 1 - x;
        oy = height - 1 - y;
      case 270:
        ox = y;
        oy = width - 1 - x;
    }
    if (mirror) ox = outputWidth - 1 - ox;
    final offset = (oy * outputWidth + ox) * 3;
    rgb[offset] = r;
    rgb[offset + 1] = g;
    rgb[offset + 2] = b;
  }

  if (isBgra) {
    final plane = planeMaps.first;
    final bytes = plane['bytes']! as Uint8List;
    final rowStride = plane['bytesPerRow']! as int;
    final pixelStride = math.max(4, plane['bytesPerPixel']! as int);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final offset = y * rowStride + x * pixelStride;
        if (offset + 2 >= bytes.length) continue;
        writePixel(x, y, bytes[offset + 2], bytes[offset + 1], bytes[offset]);
      }
    }
  } else {
    if (planeMaps.length < 3) {
      throw StateError('Formato YUV inesperado: ${planeMaps.length} planos.');
    }
    final yPlane = planeMaps[0];
    final uPlane = planeMaps[1];
    final vPlane = planeMaps[2];
    final ys = yPlane['bytes']! as Uint8List;
    final us = uPlane['bytes']! as Uint8List;
    final vs = vPlane['bytes']! as Uint8List;
    final yr = yPlane['bytesPerRow']! as int;
    final ur = uPlane['bytesPerRow']! as int;
    final vr = vPlane['bytesPerRow']! as int;
    final up = math.max(1, uPlane['bytesPerPixel']! as int);
    final vp = math.max(1, vPlane['bytesPerPixel']! as int);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final yi = y * yr + x;
        final ui = (y ~/ 2) * ur + (x ~/ 2) * up;
        final vi = (y ~/ 2) * vr + (x ~/ 2) * vp;
        if (yi >= ys.length || ui >= us.length || vi >= vs.length) continue;
        final yy = ys[yi];
        final u = us[ui] - 128;
        final v = vs[vi] - 128;
        writePixel(x, y,
            (yy + 1.402 * v).round().clamp(0, 255).toInt(),
            (yy - 0.344136 * u - 0.714136 * v).round().clamp(0, 255).toInt(),
            (yy + 1.772 * u).round().clamp(0, 255).toInt());
      }
    }
  }
  return <String, Object>{
    'width': outputWidth,
    'height': outputHeight,
    'bytes': rgb,
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
