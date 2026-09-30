/// Ignora aquecimento e troca uma única vez quando há lentidão sustentada.
class DetectorRuntimePolicy {
  int _samples = 0;
  int _slow = 0;
  bool _requested = false;

  bool shouldUseLightModel(double elapsedMs) {
    if (_requested) return false;
    if (++_samples == 1) return false;
    _slow = elapsedMs > 1200 ? _slow + 1 : 0;
    if (_slow < 3) return false;
    _requested = true;
    return true;
  }
}
