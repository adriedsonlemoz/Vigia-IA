/// Capacidade de relevo real do renderer MapLibre usado pelo Vigia IA.
///
/// O pacote maplibre 0.3.6 expoe RasterDemSource/Hillshade, mas a API Flutter
/// publica desta versao nao expoe um controle de terrain 3D equivalente a
/// setTerrain no StyleController/MapOptions. O projeto tambem nao possui uma
/// fonte DEM contratada/configurada. Por isso relevo geometrico permanece
/// desativado: hillshade nao e tratado como terrain 3D e nenhum dado e simulado.
class MapTerrainCapability {
  const MapTerrainCapability._();

  static const String mapLibreFlutterVersion = '0.3.6';
  static const bool rasterDemSourceApiAvailable = true;
  static const bool runtimeTerrain3dApiAvailable = false;
  static const bool elevationSourceConfigured = false;

  static bool get canEnableRealTerrain =>
      runtimeTerrain3dApiAvailable && elevationSourceConfigured;

  static const String state = 'disabled';
  static const String reason =
      'MapLibre Flutter 0.3.6 expoe RasterDemSource/Hillshade, mas nao oferece '
      'API publica segura de terrain 3D no StyleController/MapOptions e o Vigia '
      'IA nao possui fonte DEM configurada.';
}
