import '../models/map_route_point.dart';

/// Regras puras da telemetria superior do mapa.
///
/// Nenhum valor e sintetizado: estatisticas da sessao usam somente amostras de
/// velocidade que a plataforma declarou como disponiveis, e precisao so e
/// exibida quando veio explicitamente da leitura GPS.
class MapTelemetrySessionTracker {
  DateTime? _lastSampleAt;
  int _speedSamples = 0;
  double _speedSumKmh = 0;
  double? _maximumSpeedKmh;

  int get speedSamples => _speedSamples;

  double? get averageSpeedKmh =>
      _speedSamples == 0 ? null : _speedSumKmh / _speedSamples;

  double? get maximumSpeedKmh => _maximumSpeedKmh;

  void add(MapRoutePoint? point) {
    if (point == null || _lastSampleAt == point.recordedAt) return;
    _lastSampleAt = point.recordedAt;
    if (!point.speedAvailable) return;
    final speed = point.speedKilometersPerHour;
    if (!speed.isFinite || speed < 0) return;
    _speedSamples += 1;
    _speedSumKmh += speed;
    final maximum = _maximumSpeedKmh;
    if (maximum == null || speed > maximum) _maximumSpeedKmh = speed;
  }
}

class MapTelemetryPolicy {
  const MapTelemetryPolicy._();

  static const Duration freshReadingWindow = Duration(seconds: 20);

  static bool isFresh(
    MapRoutePoint? point, {
    DateTime? now,
  }) {
    if (point == null) return false;
    final age = (now ?? DateTime.now()).difference(point.recordedAt);
    return !age.isNegative && age <= freshReadingWindow;
  }

  static double? currentSpeedKmh(MapRoutePoint? point) {
    if (point == null || !point.speedAvailable) return null;
    final value = point.speedKilometersPerHour;
    return value.isFinite && value >= 0 ? value : null;
  }

  static double? validAccuracyMeters(double? value) {
    if (value == null || !value.isFinite || value <= 0) return null;
    return value;
  }

  static double? speedAccuracyKmh(MapRoutePoint? point) {
    final value = validAccuracyMeters(point?.speedAccuracyMetersPerSecond);
    return value == null ? null : value * 3.6;
  }

  static double? gpsHeadingDegrees(MapRoutePoint? point) {
    if (point == null || !point.headingAvailable) return null;
    final value = point.headingDegrees;
    if (value == null || !value.isFinite || value < 0) return null;
    return ((value % 360) + 360) % 360;
  }
}
