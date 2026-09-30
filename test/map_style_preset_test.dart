import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/map_view_settings_service.dart';

void main() {
  test('mapa oferece os cinco modos previstos', () {
    expect(
      MapStylePreset.values.map((value) => value.name),
      containsAll(<String>[
        'standard',
        'bikeTravel',
        'terrain',
        'topographic',
        'satellite',
      ]),
    );
  });

  test('somente estilos que dependem da Stadia exigem chave', () {
    expect(MapStylePreset.standard.needsStadiaKey, isFalse);
    expect(MapStylePreset.bikeTravel.needsStadiaKey, isFalse);
    expect(MapStylePreset.topographic.needsStadiaKey, isFalse);
    expect(MapStylePreset.terrain.needsStadiaKey, isTrue);
    expect(MapStylePreset.satellite.needsStadiaKey, isTrue);
  });
}
