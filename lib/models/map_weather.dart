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

class MapWeatherForecastHour {
  const MapWeatherForecastHour({
    required this.time,
    this.temperatureC,
    this.apparentTemperatureC,
    this.precipitationProbabilityPercent,
    this.precipitationMm,
    this.weatherCode,
    this.windSpeedKmh,
    this.windGustKmh,
    this.windDirectionDegrees,
  });

  final DateTime time;
  final double? temperatureC;
  final double? apparentTemperatureC;
  final double? precipitationProbabilityPercent;
  final double? precipitationMm;
  final int? weatherCode;
  final double? windSpeedKmh;
  final double? windGustKmh;
  final double? windDirectionDegrees;

  bool get hasValues => <Object?>[
        temperatureC,
        apparentTemperatureC,
        precipitationProbabilityPercent,
        precipitationMm,
        weatherCode,
        windSpeedKmh,
        windGustKmh,
        windDirectionDegrees,
      ].any((value) => value != null);

  Map<String, Object?> toJson() => <String, Object?>{
        'time': time.toIso8601String(),
        'temperatureC': temperatureC,
        'apparentTemperatureC': apparentTemperatureC,
        'precipitationProbabilityPercent': precipitationProbabilityPercent,
        'precipitationMm': precipitationMm,
        'weatherCode': weatherCode,
        'windSpeedKmh': windSpeedKmh,
        'windGustKmh': windGustKmh,
        'windDirectionDegrees': windDirectionDegrees,
      };

  factory MapWeatherForecastHour.fromJson(Map<String, dynamic> json) {
    final time = DateTime.tryParse(json['time']?.toString() ?? '');
    if (time == null) {
      throw const FormatException('Hora de previsão inválida.');
    }
    double? number(Object? value) {
      if (value is! num) return null;
      final parsed = value.toDouble();
      return parsed.isFinite ? parsed : null;
    }

    int? integer(Object? value) {
      if (value is! num) return null;
      return value.toInt();
    }

    return MapWeatherForecastHour(
      time: time,
      temperatureC: number(json['temperatureC']),
      apparentTemperatureC: number(json['apparentTemperatureC']),
      precipitationProbabilityPercent:
          number(json['precipitationProbabilityPercent']),
      precipitationMm: number(json['precipitationMm']),
      weatherCode: integer(json['weatherCode']),
      windSpeedKmh: number(json['windSpeedKmh']),
      windGustKmh: number(json['windGustKmh']),
      windDirectionDegrees: number(json['windDirectionDegrees']),
    );
  }
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
    this.hourlyForecast = const <MapWeatherForecastHour>[],
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
  final List<MapWeatherForecastHour> hourlyForecast;
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
      ].any((value) => value != null) || hourlyForecast.isNotEmpty;

  MapWeatherOrigin get origin {
    var hasEsp32 = false;
    var hasOnline = hourlyForecast.isNotEmpty;
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
