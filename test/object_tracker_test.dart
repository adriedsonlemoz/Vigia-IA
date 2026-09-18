import 'package:vigiaia/models/detection.dart';
import 'package:vigiaia/models/monitoring_zone.dart';
import 'package:vigiaia/models/tracked_detection.dart';
import 'package:vigiaia/services/object_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const zone = MonitoringZoneProfile(
    id: 'portao',
    name: 'Portão',
    zone: MonitoringZone(
      xMin: 0,
      yMin: 0,
      xMax: 0.5,
      yMax: 1,
    ),
  );

  Detection person(double xMin, double xMax) => Detection(
        label: 'person',
        displayLabel: 'Pessoa',
        confidence: 0.9,
        box: NormalizedBox(
          xMin: xMin,
          yMin: 0.2,
          xMax: xMax,
          yMax: 0.8,
        ),
      );

  test('mantem o mesmo ID para objeto proximo', () {
    final tracker = ObjectTracker(maxMissing: const Duration(seconds: 2));
    final first = tracker.update(
      detections: <Detection>[person(0.10, 0.30)],
      zones: const <MonitoringZoneProfile>[zone],
      now: DateTime(2026, 9, 15, 10),
    );
    final second = tracker.update(
      detections: <Detection>[person(0.13, 0.33)],
      zones: const <MonitoringZoneProfile>[zone],
      now: DateTime(2026, 9, 15, 10, 0, 1),
    );

    expect(first.active.single.trackId, second.active.single.trackId);
  });

  test('gera entrada e saida por zona', () {
    final tracker = ObjectTracker(maxMissing: const Duration(seconds: 1));
    final first = tracker.update(
      detections: <Detection>[person(0.30, 0.50)],
      zones: const <MonitoringZoneProfile>[zone],
      now: DateTime(2026, 9, 15, 10),
    );
    expect(first.transitions.single.type, ZoneTransitionType.entered);

    final second = tracker.update(
      detections: <Detection>[person(0.50, 0.60)],
      zones: const <MonitoringZoneProfile>[zone],
      now: DateTime(2026, 9, 15, 10, 0, 1),
    );
    expect(second.transitions.single.type, ZoneTransitionType.exited);
  });

  test('objeto ausente expira e gera saida', () {
    final tracker = ObjectTracker(maxMissing: const Duration(seconds: 1));
    tracker.update(
      detections: <Detection>[person(0.10, 0.30)],
      zones: const <MonitoringZoneProfile>[zone],
      now: DateTime(2026, 9, 15, 10),
    );
    final result = tracker.update(
      detections: const <Detection>[],
      zones: const <MonitoringZoneProfile>[zone],
      now: DateTime(2026, 9, 15, 10, 0, 2),
    );

    expect(result.active, isEmpty);
    expect(result.transitions.single.type, ZoneTransitionType.exited);
  });

  test('mantem IDs ao cruzar duas pessoas em sentidos opostos', () {
    final tracker = ObjectTracker(maxMissing: const Duration(seconds: 2));
    final t0 = DateTime(2026, 9, 16, 10);
    final first = tracker.update(
      detections: <Detection>[person(0.10, 0.24), person(0.72, 0.86)],
      zones: const <MonitoringZoneProfile>[zone],
      now: t0,
    );
    final leftId = first.active.first.trackId;
    final rightId = first.active.last.trackId;

    tracker.update(
      detections: <Detection>[person(0.28, 0.42), person(0.54, 0.68)],
      zones: const <MonitoringZoneProfile>[zone],
      now: t0.add(const Duration(milliseconds: 500)),
    );
    final crossing = tracker.update(
      detections: <Detection>[person(0.46, 0.60), person(0.36, 0.50)],
      zones: const <MonitoringZoneProfile>[zone],
      now: t0.add(const Duration(seconds: 1)),
    );

    final movingRight = crossing.active.reduce(
      (a, b) => a.detection.box.xMin > b.detection.box.xMin ? a : b,
    );
    final movingLeft = crossing.active.reduce(
      (a, b) => a.detection.box.xMin < b.detection.box.xMin ? a : b,
    );
    expect(movingRight.trackId, leftId);
    expect(movingLeft.trackId, rightId);
  });

}
