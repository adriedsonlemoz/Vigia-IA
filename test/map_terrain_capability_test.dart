import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/map_terrain_capability.dart';

void main() {
  test('terrain real permanece desativado sem API runtime e fonte DEM', () {
    expect(MapTerrainCapability.mapLibreFlutterVersion, '0.3.6');
    expect(MapTerrainCapability.rasterDemSourceApiAvailable, isTrue);
    expect(MapTerrainCapability.runtimeTerrain3dApiAvailable, isFalse);
    expect(MapTerrainCapability.elevationSourceConfigured, isFalse);
    expect(MapTerrainCapability.canEnableRealTerrain, isFalse);
    expect(MapTerrainCapability.state, 'disabled');
  });
}
