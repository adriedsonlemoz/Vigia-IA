enum AdaptiveCameraLayout { single, stacked, sideBySide }

/// Define uma única composição responsiva para uma ou duas câmeras.
AdaptiveCameraLayout adaptiveCameraLayoutFor({
  required int cameraCount,
  required bool landscape,
  required double availableWidth,
}) {
  if (cameraCount <= 1) return AdaptiveCameraLayout.single;
  if (landscape || availableWidth >= 720) {
    return AdaptiveCameraLayout.sideBySide;
  }
  return AdaptiveCameraLayout.stacked;
}
