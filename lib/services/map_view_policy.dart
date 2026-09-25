enum MapOrientationMode { northUp, headingUp }

enum MapFollowViewPreset { near, region }

/// Regras puras de camera do mapa. Mantem zoom, orientacao e dead-zones
/// testaveis sem depender do widget/MapController.
class MapViewPolicy {
  const MapViewPolicy._();

  static const double nearZoom = 14.7;
  static const double regionZoom = 12.2;
  static const double minimumHeadingSpeedKmh = 3.0;
  static const double headingRotationDeadZoneDegrees = 2.5;

  static double zoomFor(MapFollowViewPreset preset) => switch (preset) {
        MapFollowViewPreset.near => nearZoom,
        MapFollowViewPreset.region => regionZoom,
      };

  static double normalizeDegrees(double value) {
    final normalized = value % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }

  /// flutter_map gira o mapa; para manter o rumo do deslocamento apontando
  /// para o topo, a camera precisa girar no sentido oposto ao heading GPS.
  static double mapRotationForHeading(double headingDegrees) =>
      normalizeDegrees(360 - normalizeDegrees(headingDegrees));

  static double shortestAngularDelta(double from, double to) {
    final delta = normalizeDegrees(to) - normalizeDegrees(from);
    if (delta > 180) return delta - 360;
    if (delta < -180) return delta + 360;
    return delta;
  }

  static bool shouldApplyHeadingRotation({
    required double headingDegrees,
    required double speedKmh,
    required double currentMapRotationDegrees,
    bool force = false,
  }) {
    if (!headingDegrees.isFinite) return false;
    if (!force && speedKmh < minimumHeadingSpeedKmh) return false;
    if (force) return true;
    final desired = mapRotationForHeading(headingDegrees);
    return shortestAngularDelta(currentMapRotationDegrees, desired).abs() >=
        headingRotationDeadZoneDegrees;
  }

  /// Distancia vertical em pixels usada pelo MapController.move(offset: ...)
  /// para deixar o usuario abaixo do centro e aumentar a estrada visivel a
  /// frente. Em paisagem o deslocamento e menor para preservar area util.
  static double followOffsetPixels({
    required double viewportHeight,
    required bool compactLandscape,
  }) {
    if (!viewportHeight.isFinite || viewportHeight <= 0) return 0;
    final fraction = compactLandscape ? 0.12 : 0.18;
    final raw = viewportHeight * fraction;
    final minimum = compactLandscape ? 34.0 : 58.0;
    final maximum = compactLandscape ? 78.0 : 150.0;
    return raw.clamp(minimum, maximum).toDouble();
  }
}
