import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/map_navigation_target.dart';

void main() {
  test('destino de navegação preserva estado em JSON', () {
    final target = MapNavigationTarget(
      latitude: -19.9167,
      longitude: -43.9345,
      label: 'Ponto de água',
      startedAt: DateTime.utc(2026, 9, 25, 12, 30),
      sourceId: 'water-1',
    );

    final restored = MapNavigationTarget.fromJson(target.toJson());

    expect(restored.latitude, target.latitude);
    expect(restored.longitude, target.longitude);
    expect(restored.label, target.label);
    expect(restored.startedAt, target.startedAt);
    expect(restored.sourceId, target.sourceId);
  });
}
