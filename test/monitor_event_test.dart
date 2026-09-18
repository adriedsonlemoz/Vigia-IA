import 'package:vigiaia/models/detection.dart';
import 'package:vigiaia/models/monitor_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MonitorEvent preserva dados e bounding box no JSON', () {
    final original = MonitorEvent(
      id: 'evento-1',
      createdAt: DateTime.utc(2026, 9, 15, 22, 30, 10),
      label: 'person',
      displayLabel: 'Pessoa',
      confidence: 0.87,
      source: 'Câmera do dispositivo',
      snapshotPath: '/tmp/evento-1.jpg',
      clipPath: '/tmp/evento-1.gif',
      type: MonitorEventType.entered,
      trackId: 3,
      zoneId: 'portao',
      zoneName: 'Portão',
      cameraId: 'cam-portao',
      box: const NormalizedBox(
        yMin: 0.1,
        xMin: 0.2,
        yMax: 0.8,
        xMax: 0.7,
      ),
    );

    final restored = MonitorEvent.fromJson(original.toJson());

    expect(restored.id, original.id);
    expect(restored.createdAt, original.createdAt);
    expect(restored.label, 'person');
    expect(restored.displayLabel, 'Pessoa');
    expect(restored.confidence, closeTo(0.87, 0.0001));
    expect(restored.source, 'Câmera do dispositivo');
    expect(restored.snapshotPath, '/tmp/evento-1.jpg');
    expect(restored.clipPath, '/tmp/evento-1.gif');
    expect(restored.type, MonitorEventType.entered);
    expect(restored.trackId, 3);
    expect(restored.zoneId, 'portao');
    expect(restored.zoneName, 'Portão');
    expect(restored.cameraId, 'cam-portao');
    expect(restored.box.yMin, closeTo(0.1, 0.0001));
    expect(restored.box.xMin, closeTo(0.2, 0.0001));
    expect(restored.box.yMax, closeTo(0.8, 0.0001));
    expect(restored.box.xMax, closeTo(0.7, 0.0001));
  });
}
