import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/detection.dart';
import 'package:vigiaia/models/monitoring_zone.dart';
import 'package:vigiaia/models/tracked_detection.dart';
import 'package:vigiaia/services/object_tracker.dart';

void main() {
  const customZone = MonitoringZoneProfile(
    id: 'corredor',
    name: 'Corredor',
    zone: MonitoringZone(xMin: 0.5, yMin: 0, xMax: 1, yMax: 1),
  );
  const fullZone = MonitoringZoneProfile(
    id: 'tela',
    name: 'Tela inteira',
    zone: MonitoringZone.fullFrame(),
  );
  final initial = DateTime(2026, 10, 16, 10);

  Detection person(double center, {double confidence = 0.92}) => Detection(
        label: 'person',
        displayLabel: 'Pessoa',
        confidence: confidence,
        box: NormalizedBox(
          xMin: center - 0.08,
          yMin: 0.25,
          xMax: center + 0.08,
          yMax: 0.75,
        ),
      );

  test('pessoa identificada dentro da área não significa entrada', () {
    final tracker = ObjectTracker(verifiedZoneTransitionsOnly: true);
    final seen = tracker.update(
      detections: [person(0.70)],
      zones: [customZone],
      now: initial,
      isMoving: (_) => false,
    );
    expect(seen.transitions, isEmpty);
    final still = tracker.update(
      detections: [person(0.70)],
      zones: [customZone],
      now: initial.add(const Duration(seconds: 1)),
      isMoving: (_) => false,
    );
    expect(still.transitions, isEmpty);
  });

  test('perda e retorno de falso positivo não produzem saída ou entrada', () {
    final tracker = ObjectTracker(
      verifiedZoneTransitionsOnly: true,
      maxMissing: const Duration(seconds: 2),
    );
    tracker.update(
      detections: [person(0.70)], zones: [customZone], now: initial,
      isMoving: (_) => false,
    );
    final vanished = tracker.update(
      detections: const [], zones: [customZone],
      now: initial.add(const Duration(seconds: 5)),
      isMoving: (_) => false,
    );
    expect(vanished.transitions, isEmpty);
    final reacquired = tracker.update(
      detections: [person(0.70)], zones: [customZone],
      now: initial.add(const Duration(seconds: 6)),
      isMoving: (_) => false,
    );
    expect(reacquired.transitions, isEmpty);
  });

  test('oscilação perto da borda não dispara eventos', () {
    final tracker = ObjectTracker(verifiedZoneTransitionsOnly: true);
    final positions = [0.48, 0.51, 0.49, 0.52, 0.48];
    for (var i = 0; i < positions.length; i++) {
      final result = tracker.update(
        detections: [person(positions[i])], zones: [customZone],
        now: initial.add(Duration(milliseconds: i * 400)),
        isMoving: (_) => true,
      );
      expect(result.transitions, isEmpty);
    }
  });

  test('cruzamento observado e persistente gera evento', () {
    final tracker = ObjectTracker(verifiedZoneTransitionsOnly: true);
    final locations = [0.37, 0.42, 0.55, 0.64];
    final transitions = <ZoneTransition>[];
    for (var i = 0; i < locations.length; i++) {
      final result = tracker.update(
        detections: [person(locations[i])], zones: [customZone],
        now: initial.add(Duration(milliseconds: i * 400)),
        isMoving: (_) => true,
      );
      transitions.addAll(result.transitions);
    }
    expect(transitions.length, 1);
    expect(transitions.single.type, ZoneTransitionType.entered);
  });

  test('sem movimento evidenciado não anuncia cruzamento', () {
    final tracker = ObjectTracker(verifiedZoneTransitionsOnly: true);
    final transitions = <ZoneTransition>[];
    for (final (index, position) in [0.37, 0.43, 0.56, 0.64].indexed) {
      final result = tracker.update(
        detections: [person(position)], zones: [customZone],
        now: initial.add(Duration(milliseconds: index * 400)),
        isMoving: (_) => false,
      );
      transitions.addAll(result.transitions);
    }
    expect(transitions, isEmpty);
  });

  test('na tela inteira o desaparecimento não pode ser saída de área', () {
    final tracker = ObjectTracker(verifiedZoneTransitionsOnly: true);
    tracker.update(detections: [person(0.7)], zones: [fullZone],
        now: initial, isMoving: (_) => true);
    final result = tracker.update(
      detections: const [], zones: [fullZone],
      now: initial.add(const Duration(seconds: 10)),
      isMoving: (_) => true,
    );
    expect(result.transitions, isEmpty);
  });
}
