import '../models/map_route_point.dart';

/// Regras puras da telemetria superior do mapa.
///
/// Nenhum valor é sintetizado: estatísticas da sessão usam somente amostras de
/// velocidade que a plataforma declarou como disponíveis, e precisão só é
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

enum MapGpsQuality { unavailable, unknown, stale, excellent, good, fair, weak }

extension MapGpsQualityLabel on MapGpsQuality {
  String get label => switch (this) {
        MapGpsQuality.unavailable => 'Sem leitura',
        MapGpsQuality.unknown => 'Precisão desconhecida',
        MapGpsQuality.stale => 'Leitura antiga',
        MapGpsQuality.excellent => 'Excelente',
        MapGpsQuality.good => 'Boa',
        MapGpsQuality.fair => 'Razoável',
        MapGpsQuality.weak => 'Fraca',
      };

  double get progress => switch (this) {
        MapGpsQuality.unavailable => 0,
        MapGpsQuality.unknown => 0.08,
        MapGpsQuality.stale => 0.12,
        MapGpsQuality.weak => 0.28,
        MapGpsQuality.fair => 0.52,
        MapGpsQuality.good => 0.76,
        MapGpsQuality.excellent => 1,
      };
}

class MapElevationSummary {
  const MapElevationSummary({
    required this.samples,
    required this.recentProfileMeters,
    this.currentMeters,
    this.minimumMeters,
    this.maximumMeters,
    this.recentDeltaMeters,
  });

  final int samples;
  final double? currentMeters;
  final double? minimumMeters;
  final double? maximumMeters;
  final double? recentDeltaMeters;
  final List<double> recentProfileMeters;

  double? get rangeMeters {
    final minimum = minimumMeters;
    final maximum = maximumMeters;
    if (minimum == null || maximum == null) return null;
    return maximum - minimum;
  }
}

class MapTelemetryPolicy {
  const MapTelemetryPolicy._();

  static const Duration freshReadingWindow = Duration(seconds: 20);
  static const double maximumUsefulHorizontalAccuracyMeters = 100;
  static const double maximumUsefulVerticalAccuracyMeters = 60;

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

  static MapGpsQuality gpsQuality(
    MapRoutePoint? point, {
    DateTime? now,
  }) {
    if (point == null) return MapGpsQuality.unavailable;
    if (!isFresh(point, now: now)) return MapGpsQuality.stale;
    final accuracy = validAccuracyMeters(point.accuracyMeters);
    if (accuracy == null) return MapGpsQuality.unknown;
    if (accuracy > maximumUsefulHorizontalAccuracyMeters) {
      return MapGpsQuality.weak;
    }
    if (accuracy <= 5) return MapGpsQuality.excellent;
    if (accuracy <= 12) return MapGpsQuality.good;
    if (accuracy <= 30) return MapGpsQuality.fair;
    return MapGpsQuality.weak;
  }

  static Duration? readingAge(
    MapRoutePoint? point, {
    DateTime? now,
  }) {
    if (point == null) return null;
    final age = (now ?? DateTime.now()).difference(point.recordedAt);
    return age.isNegative ? Duration.zero : age;
  }

  static MapElevationSummary elevationSummary(
    Iterable<MapRoutePoint> route, {
    MapRoutePoint? current,
    int recentLimit = 32,
  }) {
    final valid = <double>[];
    for (final point in route) {
      final altitude = point.altitudeMeters;
      if (altitude == null || !altitude.isFinite) continue;
      final accuracy = validAccuracyMeters(point.altitudeAccuracyMeters);
      if (accuracy != null && accuracy > maximumUsefulVerticalAccuracyMeters) {
        continue;
      }
      valid.add(altitude);
    }

    final currentAltitude = current?.altitudeMeters;
    if (currentAltitude != null &&
        currentAltitude.isFinite &&
        (valid.isEmpty || valid.last != currentAltitude)) {
      final accuracy = validAccuracyMeters(current?.altitudeAccuracyMeters);
      if (accuracy == null || accuracy <= maximumUsefulVerticalAccuracyMeters) {
        valid.add(currentAltitude);
      }
    }

    if (valid.isEmpty) {
      return const MapElevationSummary(
        samples: 0,
        recentProfileMeters: <double>[],
      );
    }

    var minimum = valid.first;
    var maximum = valid.first;
    for (final value in valid.skip(1)) {
      if (value < minimum) minimum = value;
      if (value > maximum) maximum = value;
    }

    final recent = valid.length <= recentLimit
        ? List<double>.from(valid)
        : valid.sublist(valid.length - recentLimit);
    final recentDelta = recent.length < 2 ? null : recent.last - recent.first;

    return MapElevationSummary(
      samples: valid.length,
      currentMeters: valid.last,
      minimumMeters: minimum,
      maximumMeters: maximum,
      recentDeltaMeters: recentDelta,
      recentProfileMeters: List<double>.unmodifiable(recent),
    );
  }
}
