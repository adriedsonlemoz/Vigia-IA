import 'dart:typed_data';

import 'package:vigiaia/models/detection.dart';
import 'package:vigiaia/models/monitoring_zone.dart';
import 'package:vigiaia/models/rgb_frame.dart';
import 'package:vigiaia/services/monitoring_zone_service.dart';
import 'package:vigiaia/services/motion_detection_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RgbFrame indexedFrame(int width, int height) {
    final bytes = Uint8List(width * height * 3);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final offset = (y * width + x) * 3;
        bytes[offset] = x;
        bytes[offset + 1] = y;
        bytes[offset + 2] = x + y;
      }
    }
    return RgbFrame(
      width: width,
      height: height,
      rgbBytes: bytes,
      capturedAt: DateTime(2026, 1, 1),
    );
  }

  test('recorta somente a area normalizada selecionada', () {
    final frame = indexedFrame(4, 4);
    const zone = MonitoringZone(
      xMin: 0.25,
      yMin: 0.25,
      xMax: 0.75,
      yMax: 0.75,
    );

    final cropped = MonitoringZoneService.crop(frame, zone);

    expect(cropped.width, 2);
    expect(cropped.height, 2);
    expect(cropped.rgbBytes, <int>[
      1, 1, 2,
      2, 1, 3,
      1, 2, 3,
      2, 2, 4,
    ]);
  });

  test('tela inteira reutiliza o mesmo frame', () {
    final frame = indexedFrame(4, 4);
    final cropped = MonitoringZoneService.crop(
      frame,
      const MonitoringZone.fullFrame(),
    );

    expect(identical(cropped, frame), isTrue);
  });

  test('remapeia caixa detectada no recorte para coordenadas globais', () {
    const detection = Detection(
      label: 'person',
      displayLabel: 'pessoa',
      confidence: 0.9,
      box: NormalizedBox(
        xMin: 0.25,
        yMin: 0.25,
        xMax: 0.75,
        yMax: 0.75,
      ),
    );
    const zone = MonitoringZone(
      xMin: 0.2,
      yMin: 0.4,
      xMax: 0.6,
      yMax: 0.8,
    );

    final mapped = MonitoringZoneService.remapDetection(detection, zone);

    expect(mapped.box.xMin, closeTo(0.3, 0.0001));
    expect(mapped.box.yMin, closeTo(0.5, 0.0001));
    expect(mapped.box.xMax, closeTo(0.5, 0.0001));
    expect(mapped.box.yMax, closeTo(0.7, 0.0001));
  });


  test('movimento fora da zona nao chega ao filtro de movimento', () {
    RgbFrame frameWithSquare(bool visible) {
      const width = 100;
      const height = 100;
      final bytes = Uint8List(width * height * 3);
      if (visible) {
        for (var y = 70; y < 95; y++) {
          for (var x = 70; x < 95; x++) {
            final offset = (y * width + x) * 3;
            bytes[offset] = 255;
            bytes[offset + 1] = 255;
            bytes[offset + 2] = 255;
          }
        }
      }
      return RgbFrame(
        width: width,
        height: height,
        rgbBytes: bytes,
        capturedAt: DateTime(2026, 1, 1),
      );
    }

    const topLeftZone = MonitoringZone(
      xMin: 0,
      yMin: 0,
      xMax: 0.5,
      yMax: 0.5,
    );
    final motion = MotionDetectionService();
    motion.analyze(MonitoringZoneService.crop(frameWithSquare(false), topLeftZone));
    final result = motion.analyze(
      MonitoringZoneService.crop(frameWithSquare(true), topLeftZone),
    );

    expect(result.hasMotion, isFalse);
  });

  test('zona invertida e pequena e normalizada com tamanho minimo', () {
    const zone = MonitoringZone(
      xMin: 0.9,
      yMin: 0.9,
      xMax: 0.89,
      yMax: 0.88,
    );

    final normalized = zone.normalized();

    expect(normalized.xMin, greaterThanOrEqualTo(0));
    expect(normalized.yMin, greaterThanOrEqualTo(0));
    expect(normalized.xMax, lessThanOrEqualTo(1));
    expect(normalized.yMax, lessThanOrEqualTo(1));
    expect(normalized.width, greaterThanOrEqualTo(0.0799));
    expect(normalized.height, greaterThanOrEqualTo(0.0799));
  });
  test('calcula retangulo de uniao para varias areas', () {
    final union = MonitoringZoneService.boundingZone(const <MonitoringZone>[
      MonitoringZone(xMin: 0.1, yMin: 0.2, xMax: 0.4, yMax: 0.5),
      MonitoringZone(xMin: 0.6, yMin: 0.1, xMax: 0.9, yMax: 0.8),
    ]);

    expect(union.xMin, closeTo(0.1, 0.0001));
    expect(union.yMin, closeTo(0.1, 0.0001));
    expect(union.xMax, closeTo(0.9, 0.0001));
    expect(union.yMax, closeTo(0.8, 0.0001));
  });

  test('descarta deteccao fora de todas as areas ativas', () {
    const inside = Detection(
      label: 'person',
      displayLabel: 'Pessoa',
      confidence: 0.9,
      box: NormalizedBox(xMin: 0.1, yMin: 0.1, xMax: 0.2, yMax: 0.2),
    );
    const outside = Detection(
      label: 'dog',
      displayLabel: 'Cachorro',
      confidence: 0.8,
      box: NormalizedBox(xMin: 0.8, yMin: 0.8, xMax: 0.9, yMax: 0.9),
    );
    final filtered = MonitoringZoneService.filterToZones(
      const <Detection>[inside, outside],
      const <MonitoringZone>[
        MonitoringZone(xMin: 0, yMin: 0, xMax: 0.5, yMax: 0.5),
      ],
    );

    expect(filtered, <Detection>[inside]);
  });

}
