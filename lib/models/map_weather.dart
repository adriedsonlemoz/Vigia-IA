enum MapWeatherSource { esp32, online }

extension MapWeatherSourceLabel on MapWeatherSource {
  String get label => switch (this) {
        MapWeatherSource.esp32 => 'ESP32',
        MapWeatherSource.online => 'Online',
      };
}

enum MapWeatherOrigin { unavailable, esp32, online, mixed }

extension MapWeatherOriginLabel on MapWeatherOrigin {
  String get label => switch (this) {
        MapWeatherOrigin.unavailable => 'Indisponível',
        MapWeatherOrigin.esp32 => 'ESP32',
        MapWeatherOrigin.online => 'Online',
        MapWeatherOrigin.mixed => 'Misto',
      };
}

class MapWeatherValue<T> {
  const MapWeatherValue({
    required this.value,
    required this.source,
    required this.observedAt,
    this.sourceDetail,
  });

  final T value;
  final MapWeatherSource source;
  final DateTime observedAt;
  final String? sourceDetail;
}

class MapWeatherSnapshot {
  const MapWeatherSnapshot({
    this.temperatureC,
    this.apparentTemperatureC,
    this.humidityPercent,
    this.surfacePressureHpa,
    this.windSpeedKmh,
    this.windDirectionDegrees,
    this.weatherCode,
    this.precipitationProbabilityPercent,
    this.precipitationMm,
    this.rainMm,
    this.onlineUpdatedAt,
    this.onlineStale = false,
  });

  final MapWeatherValue<double>? temperatureC;
  final MapWeatherValue<double>? apparentTemperatureC;
  final MapWeatherValue<double>? humidityPercent;
  final MapWeatherValue<double>? surfacePressureHpa;
  final MapWeatherValue<double>? windSpeedKmh;
  final MapWeatherValue<double>? windDirectionDegrees;
  final MapWeatherValue<int>? weatherCode;
  final MapWeatherValue<double>? precipitationProbabilityPercent;
  final MapWeatherValue<double>? precipitationMm;
  final MapWeatherValue<double>? rainMm;
  final DateTime? onlineUpdatedAt;
  final bool onlineStale;

  bool get hasValues => <Object?>[
        temperatureC,
        apparentTemperatureC,
        humidityPercent,
        surfacePressureHpa,
        windSpeedKmh,
        windDirectionDegrees,
        weatherCode,
        precipitationProbabilityPercent,
        precipitationMm,
        rainMm,
      ].any((value) => value != null);

  MapWeatherOrigin get origin {
    var hasEsp32 = false;
    var hasOnline = false;
    final sources = <MapWeatherSource?>[
      temperatureC?.source,
      apparentTemperatureC?.source,
      humidityPercent?.source,
      surfacePressureHpa?.source,
      windSpeedKmh?.source,
      windDirectionDegrees?.source,
      weatherCode?.source,
      precipitationProbabilityPercent?.source,
      precipitationMm?.source,
      rainMm?.source,
    ];
    for (final source in sources) {
      if (source == MapWeatherSource.esp32) hasEsp32 = true;
      if (source == MapWeatherSource.online) hasOnline = true;
    }
    if (hasEsp32 && hasOnline) return MapWeatherOrigin.mixed;
    if (hasEsp32) return MapWeatherOrigin.esp32;
    if (hasOnline) return MapWeatherOrigin.online;
    return MapWeatherOrigin.unavailable;
  }

  DateTime? get latestObservedAt {
    final values = <DateTime>[
      if (temperatureC != null) temperatureC!.observedAt,
      if (apparentTemperatureC != null) apparentTemperatureC!.observedAt,
      if (humidityPercent != null) humidityPercent!.observedAt,
      if (surfacePressureHpa != null) surfacePressureHpa!.observedAt,
      if (windSpeedKmh != null) windSpeedKmh!.observedAt,
      if (windDirectionDegrees != null) windDirectionDegrees!.observedAt,
      if (weatherCode != null) weatherCode!.observedAt,
      if (precipitationProbabilityPercent != null)
        precipitationProbabilityPercent!.observedAt,
      if (precipitationMm != null) precipitationMm!.observedAt,
      if (rainMm != null) rainMm!.observedAt,
    ];
    if (values.isEmpty) return null;
    values.sort();
    return values.last;
  }
}
