import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/frame_converter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('BGRA com padding gira e espelha pixels nas posições corretas', () async {
    final bytes = Uint8List.fromList([
      0, 0, 10, 255, 0, 0, 20, 255, 99, 99, 99, 99,
      0, 0, 30, 255, 0, 0, 40, 255, 99, 99, 99, 99,
    ]);
    for (final entry in <int, List<int>>{
      0: [10, 20, 30, 40], 90: [30, 10, 40, 20],
      180: [40, 30, 20, 10], 270: [20, 40, 10, 30],
    }.entries) {
      final result = await FrameConverter.fromCamera(CameraFrameData(
        width: 2, height: 2, rotationDegrees: entry.key,
        isBgra: true, mirrorHorizontally: false,
        planes: [CameraPlaneData(bytes: bytes, bytesPerRow: 12, bytesPerPixel: 4)],
      ));
      expect([for (var i = 0; i < result.rgbBytes.length; i += 3) result.rgbBytes[i]], entry.value);
    }
    final mirrored = await FrameConverter.fromCamera(CameraFrameData(
      width: 2, height: 2, rotationDegrees: 90, isBgra: true, mirrorHorizontally: true,
      planes: [CameraPlaneData(bytes: bytes, bytesPerRow: 12, bytesPerPixel: 4)],
    ));
    expect([for (var i = 0; i < 12; i += 3) mirrored.rgbBytes[i]], [10, 30, 20, 40]);
  });

  test('YUV respeita strides independentes e preserva timestamp', () async {
    final captured = DateTime.utc(2026, 9, 21);
    final result = await FrameConverter.fromCamera(CameraFrameData(
      width: 2, height: 4, rotationDegrees: 90, isBgra: false, mirrorHorizontally: false,
      planes: [
        CameraPlaneData(bytes: Uint8List.fromList([64, 64, 0, 64, 64, 0, 64, 64, 0, 64, 64]), bytesPerRow: 3, bytesPerPixel: 1),
        CameraPlaneData(bytes: Uint8List.fromList([128, 0, 0, 0, 128]), bytesPerRow: 4, bytesPerPixel: 2),
        CameraPlaneData(bytes: Uint8List.fromList([128, 0, 0, 128]), bytesPerRow: 3, bytesPerPixel: 1),
      ],
    ), capturedAt: captured);
    expect((result.width, result.height), (4, 2));
    expect(result.rgbBytes, everyElement(64));
    expect(result.capturedAt, captured);
  });
}
