import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/detector_input_buffer.dart';

void main() {
  test('letterbox uint8 mantém cores, zera margens e reusa o buffer', () {
    final input = DetectorInputBuffer(2, 2, floatingPoint: false);
    final original = input.bytes;
    final transform = input.fill(Uint8List.fromList([255, 0, 0, 0, 255, 0]), 2, 1);
    expect(transform.resizedHeight, 1);
    expect(input.bytes, [255, 0, 0, 0, 255, 0, 0, 0, 0, 0, 0, 0]);
    input.fill(Uint8List.fromList([0, 0, 255, 255, 255, 255]), 2, 1);
    expect(identical(input.bytes, original), isTrue);
    expect(input.bytes.sublist(6), everyElement(0));
  });

  test('bilinear amostra o centro e normaliza float32 sem listas aninhadas', () {
    final input = DetectorInputBuffer(1, 1, floatingPoint: true);
    input.fill(Uint8List.fromList([0, 0, 0, 255, 255, 255]), 2, 1);
    expect(input.bytes.buffer.asFloat32List(), everyElement(closeTo(0, 0.00001)));
    input.fill(Uint8List.fromList([0, 255, 0]), 1, 1);
    expect(input.bytes.buffer.asFloat32List(), [-1, 1, -1]);
  });

  test('YOLO26 usa entrada RGB 0..1, padding 114 e suporte NCHW', () {
    final input = DetectorInputBuffer(2, 2,
      floatingPoint: true,
      normalization: DetectorPixelNormalization.zeroToOne,
      channelFirst: true,
      padding: 114,
    );
    input.fill(Uint8List.fromList([255, 0, 128, 0, 255, 255]), 2, 1);
    final values = input.bytes.buffer.asFloat32List();
    expect(values[0], closeTo(1, 0.001));
    expect(values[4], closeTo(0, 0.001));
    expect(values[8], closeTo(128 / 255, 0.001));
    expect(values[2], closeTo(114 / 255, 0.001));
  });

  test('rejeita quantidade inválida de bytes', () {
    final input = DetectorInputBuffer(2, 2, floatingPoint: false);
    expect(() => input.fill(Uint8List(2), 2, 2), throwsArgumentError);
  });
}
