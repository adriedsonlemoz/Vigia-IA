import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/map_travel_mode.dart';

void main() {
  test('modos de transporte usam os perfis corretos do roteamento', () {
    expect(MapTravelMode.values, hasLength(4));
    expect(MapTravelMode.bicycle.valhallaCosting, 'bicycle');
    expect(MapTravelMode.motorcycle.valhallaCosting, 'motorcycle');
    expect(MapTravelMode.car.valhallaCosting, 'auto');
    expect(MapTravelMode.walking.valhallaCosting, 'pedestrian');
    expect(
      MapTravelMode.values.map((mode) => mode.label).toList(),
      <String>['Bicicleta', 'Moto', 'Carro', 'A pé'],
    );
  });

  test('modo persistido desconhecido mantém compatibilidade com bicicleta', () {
    expect(
      MapTravelModeX.fromStorage('motorcycle'),
      MapTravelMode.motorcycle,
    );
    expect(MapTravelModeX.fromStorage('unknown'), MapTravelMode.bicycle);
    expect(MapTravelModeX.fromStorage(null), MapTravelMode.bicycle);
  });
}
