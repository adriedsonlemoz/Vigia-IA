/// Usa a cadência observada, não a velocidade solicitada à câmera.
class DetectionCadencePolicy {
  DateTime? _lastObservation;
  Duration window = const Duration(milliseconds: 1500);
  static const urgentFrameMaxAge = Duration(milliseconds: 1500);
  static const spokenFrameMaxAge = Duration(seconds: 5);

  Duration observe(DateTime capturedAt) {
    final previous = _lastObservation;
    _lastObservation = capturedAt;
    final gap = previous == null ? 0 : capturedAt.difference(previous).inMilliseconds;
    window = Duration(milliseconds: (gap * 2 + 250).clamp(1500, 30000).toInt());
    return window;
  }

  static bool fresh(DateTime capturedAt, DateTime now, Duration maximumAge) {
    final age = now.difference(capturedAt);
    return !age.isNegative && age <= maximumAge;
  }

  void reset() {
    _lastObservation = null;
    window = const Duration(milliseconds: 1500);
  }
}
