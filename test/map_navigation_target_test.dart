import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/map_navigation_target.dart';
import 'package:vigiaia/models/map_travel_mode.dart';

void main() {
  test('destino de navegação preserva estado e modo de transporte em JSON', () {
    final target = MapNavigationTarget(
      latitude: -19.9167,
      longitude: -43.9345,
      label: 'Ponto de água',
      startedAt: DateTime.utc(2026, 9, 25, 12, 30),
      sourceId: 'water-1',
      travelMode: MapTravelMode.motorcycle,
    );

    final restored = MapNavigationTarget.fromJson(target.toJson());

    expect(restored.latitude, target.latitude);
    expect(restored.longitude, target.longitude);
    expect(restored.label, target.label);
    expect(restored.startedAt, target.startedAt);
    expect(restored.sourceId, target.sourceId);
    expect(restored.travelMode, MapTravelMode.motorcycle);
  });

  test('destino antigo sem modo continua sendo restaurado como bicicleta', () {
    final restored = MapNavigationTarget.fromJson(<String, dynamic>{
      'latitude': -19.9167,
      'longitude': -43.9345,
      'label': 'Destino legado',
      'startedAt': '2026-09-25T12:30:00.000Z',
      'sourceId': 'legacy-1',
    });

    expect(restored.travelMode, MapTravelMode.bicycle);
  });
}
