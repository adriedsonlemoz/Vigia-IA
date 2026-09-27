import '../models/bike_sensor_snapshot.dart';
import '../models/map_route_point.dart';
import 'map_telemetry_policy.dart';

class MapSpeedReading {
  const MapSpeedReading(this.kmh, this.source);
  final double kmh;
  final String source;
}

class MapSpeedPolicy {
  const MapSpeedPolicy._();

  static MapSpeedReading? select(BikeSensorSnapshot? bike, MapRoutePoint? gps,
      {DateTime? now}) {
    final instant = now ?? DateTime.now();
    if (bike != null && bike.connected && bike.speedAvailable &&
        bike.speedKmh.isFinite && bike.speedKmh >= 0 &&
        instant.difference(bike.capturedAt).inSeconds.abs() <= 10) {
      return MapSpeedReading(bike.speedKmh,
          bike.source == BikeSensorSource.simulator ? 'Simulação' : 'ESP32 · Hall');
    }
    if (!MapTelemetryPolicy.isFresh(gps, now: instant)) return null;
    final speed = MapTelemetryPolicy.currentSpeedKmh(gps);
    return speed == null ? null : MapSpeedReading(speed, 'GPS');
  }
}

/// Dispara uma vez por travessia do limite, com margem para oscilação de GPS.
class MapSpeedAlertPolicy {
  final Set<int> _crossed = <int>{};
  DateTime? _lastAlertAt;

  int? observe(double? speedKmh, List<int> limits, {DateTime? now}) {
    if (speedKmh == null || !speedKmh.isFinite) return null;
    final instant = now ?? DateTime.now();
    for (final limit in limits) {
      if (speedKmh < limit - 2) _crossed.remove(limit);
    }
    for (final limit in limits.toList()..sort()) {
      if (speedKmh < limit || _crossed.contains(limit)) continue;
      if (_lastAlertAt != null && instant.difference(_lastAlertAt!) <
          const Duration(seconds: 20)) continue;
      _crossed.add(limit);
      _lastAlertAt = instant;
      return limit;
    }
    return null;
  }
}
