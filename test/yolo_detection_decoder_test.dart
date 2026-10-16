import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/detector_image_transform.dart';
import 'package:vigiaia/services/yolo_detection_decoder.dart';

void main() {
  final labels = <String>['person', 'bicycle',
    ...List.generate(78, (index) => 'class_${index + 2}')];
  final transform = DetectorImageTransform.fit(
    sourceWidth: 640,
    sourceHeight: 640,
    inputWidth: 640,
    inputHeight: 640,
  );

  test('saida YOLO26 end-to-end mapeia xyxy e classe COCO', () {
    final detections = YoloDetectionDecoder.decode(
      output: [<double>[64, 128, 320, 448, 0.92, 0]],
      tensorWidth: 640,
      tensorHeight: 640,
      transform: transform,
      labels: labels,
      threshold: 0.6,
      maxResults: 10,
    );
    expect(detections.length, 1);
    expect(detections.first[0], 'person');
    expect(detections.first[2], closeTo(0.2, 0.001));
    expect(detections.first[3], closeTo(0.1, 0.001));
    expect(detections.first[4], closeTo(0.7, 0.001));
    expect(detections.first[5], closeTo(0.5, 0.001));
  });

  test('saida raw channels-first aplica confiança e NMS por classe', () {
    final raw = List.generate(84, (_) => List<double>.filled(2, 0));
    for (var i = 0; i < 2; i++) {
      raw[0][i] = 320 + i;
      raw[1][i] = 320;
      raw[2][i] = 320;
      raw[3][i] = 320;
      raw[5][i] = i == 0 ? 0.95 : 0.89; // bicycle
    }
    final detections = YoloDetectionDecoder.decode(
      output: raw,
      tensorWidth: 640,
      tensorHeight: 640,
      transform: transform,
      labels: labels,
      threshold: 0.5,
      maxResults: 10,
    );
    expect(detections.length, 1);
    expect(detections.first[0], 'bicycle');
    expect(detections.first[1], closeTo(0.95, 0.001));
  });

  test('filtra classes não permitidas e remove score inválido', () {
    final detections = YoloDetectionDecoder.decode(
      output: [
        <double>[0, 0, 200, 200, 0.7, 1],
        <double>[0, 0, 200, 200, 0.9, 0],
        <double>[0, 0, 200, 200, double.nan, 0],
      ],
      tensorWidth: 640,
      tensorHeight: 640,
      transform: transform,
      labels: labels,
      threshold: 0.5,
      maxResults: 10,
      allowedLabels: <String>{'person'},
    );
    expect(detections.length, 1);
    expect(detections.single[0], 'person');
  });

  test('saida raw candidates-first aceita classe ao final dos canais', () {
    final row = List<double>.filled(84, 0);
    row[0] = 320;
    row[1] = 320;
    row[2] = 100;
    row[3] = 200;
    row[4] = 0.91;
    final detections = YoloDetectionDecoder.decode(
      output: [row],
      tensorWidth: 640,
      tensorHeight: 640,
      transform: transform,
      labels: labels,
      threshold: 0.8,
      maxResults: 10,
    );
    expect(detections.single[0], 'person');
  });
}
