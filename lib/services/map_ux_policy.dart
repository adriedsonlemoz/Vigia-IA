class MapCameraSnapPoint {
  const MapCameraSnapPoint({
    required this.xFraction,
    required this.yFraction,
  });

  final double xFraction;
  final double yFraction;
}

class MapUxPolicy {
  const MapUxPolicy._();

  static const double controlEdge = 8;
  static const double controlSize = 44;
  static const double controlGap = 6;

  static bool compactLandscape({
    required double width,
    required double height,
  }) =>
      height < 520 && width > height;

  static bool compactHud({
    required double width,
    required double height,
  }) =>
      compactLandscape(width: width, height: height) || width < 380;

  static double cameraMinY({
    required double safeTop,
    required bool compactLandscape,
  }) =>
      safeTop + (compactLandscape ? 150 : 142);

  static double cameraBottomReserve({
    required double safeBottom,
    required bool hasSelectedPoi,
    required bool hasNavigation,
  }) {
    var reserve = safeBottom + 56;
    if (hasNavigation) reserve += 82;
    if (hasSelectedPoi) reserve += 60;
    return reserve;
  }

  static double cameraEffectiveScale({
    required double savedScale,
    required bool hasNavigation,
    required bool compactHud,
  }) {
    final normalized = savedScale.clamp(0.72, 1.35).toDouble();
    if (!hasNavigation) return normalized;
    final ceiling = compactHud ? 0.82 : 1.0;
    return normalized.clamp(0.72, ceiling).toDouble();
  }

  static MapCameraSnapPoint cameraSnapPoint({
    required double xFraction,
    required double yFraction,
    required bool compactLandscape,
    double? otherXFraction,
    double? otherYFraction,
  }) {
    var x = xFraction < 0.5 ? 0.0 : 1.0;
    var y = yFraction < 0.5 ? 0.0 : 1.0;
    if (otherXFraction == null || otherYFraction == null) {
      return MapCameraSnapPoint(xFraction: x, yFraction: y);
    }

    final otherX = otherXFraction < 0.5 ? 0.0 : 1.0;
    final otherY = otherYFraction < 0.5 ? 0.0 : 1.0;
    if (x == otherX && y == otherY) {
      if (compactLandscape) {
        x = x == 0 ? 1 : 0;
      } else {
        y = y == 0 ? 1 : 0;
      }
    }
    return MapCameraSnapPoint(xFraction: x, yFraction: y);
  }

  static double fractionForPosition({
    required double position,
    required double min,
    required double max,
  }) {
    if (max <= min) return 0;
    return ((position - min) / (max - min)).clamp(0, 1).toDouble();
  }

  static double positionForFraction({
    required double fraction,
    required double min,
    required double max,
  }) {
    if (max <= min) return min;
    return (min + ((max - min) * fraction.clamp(0, 1))).toDouble();
  }

  static double attributionBottom({
    required double safeBottom,
    required bool hasSelectedPoi,
    required bool hasNavigation,
  }) {
    var offset = safeBottom + 50;
    if (hasNavigation) offset += 82;
    if (hasSelectedPoi) offset += 60;
    return offset;
  }
}
