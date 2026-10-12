import '../models/offline_map_package.dart';

/// Uma caixa delimitadora ou metadados do MBTiles nao provam que todos os
/// tiles estejam presentes. Nunca anuncie cobertura integral apenas por estar
/// dentro dos limites do arquivo.
enum OfflineMapCoverageState {
  noPackage,
  unknown,
  outsideBounds,
  outsideZoom,
  possible,
  corridorUnverified,
}

class OfflineMapCoveragePolicy {
  const OfflineMapCoveragePolicy._();

  static OfflineMapCoverageState assess({
    required OfflineMapPackage? package,
    required double latitude,
    required double longitude,
    required double zoom,
  }) {
    if (package == null) return OfflineMapCoverageState.noPackage;
    if (!package.hasBounds) return OfflineMapCoverageState.unknown;
    if (!package.contains(latitude: latitude, longitude: longitude)) {
      return OfflineMapCoverageState.outsideBounds;
    }
    if (!zoom.isFinite ||
        (package.minZoom != null && zoom < package.minZoom!) ||
        (package.maxZoom != null && zoom > package.maxZoom!)) {
      return OfflineMapCoverageState.outsideZoom;
    }
    if (package.downloadKind == 'route') {
      return OfflineMapCoverageState.corridorUnverified;
    }
    return OfflineMapCoverageState.possible;
  }

  static bool needsWarning(OfflineMapCoverageState state) =>
      state == OfflineMapCoverageState.unknown ||
      state == OfflineMapCoverageState.outsideBounds ||
      state == OfflineMapCoverageState.outsideZoom;

  static String warningLabel(OfflineMapCoverageState state) => switch (state) {
        OfflineMapCoverageState.unknown => 'Cobertura offline não verificada',
        OfflineMapCoverageState.outsideZoom => 'Zoom fora do detalhe offline',
        OfflineMapCoverageState.outsideBounds => 'Fora da área offline',
        _ => '',
      };
}
