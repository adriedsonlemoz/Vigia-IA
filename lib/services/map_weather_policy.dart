import '../models/map_weather.dart';

class MapWeatherPolicy {
  const MapWeatherPolicy._();

  static const Duration cacheTtl = Duration(minutes: 15);
  static const Duration staleAfter = Duration(minutes: 45);
  static const Duration minimumAutomaticRefreshInterval = Duration(minutes: 2);
  static const double locationRefreshDistanceKm = 5;

  static MapWeatherSnapshot merge({
    required MapWeatherSnapshot esp32,
    required MapWeatherSnapshot online,
  }) =>
      MapWeatherSnapshot(
        temperatureC: esp32.temperatureC ?? online.temperatureC,
        apparentTemperatureC: online.apparentTemperatureC,
        humidityPercent: esp32.humidityPercent ?? online.humidityPercent,
        surfacePressureHpa:
            esp32.surfacePressureHpa ?? online.surfacePressureHpa,
        windSpeedKmh: online.windSpeedKmh,
        windDirectionDegrees: online.windDirectionDegrees,
        weatherCode: online.weatherCode,
        precipitationProbabilityPercent:
            online.precipitationProbabilityPercent,
        precipitationMm: online.precipitationMm,
        rainMm: online.rainMm,
        hourlyForecast: online.hourlyForecast,
        onlineUpdatedAt: online.onlineUpdatedAt,
        onlineStale: online.onlineStale,
      );

  static bool cacheFresh(DateTime updatedAt, DateTime now) =>
      now.difference(updatedAt) <= cacheTtl;

  static bool cacheStale(DateTime updatedAt, DateTime now) =>
      now.difference(updatedAt) > staleAfter;

  static String? conditionLabel(int? code) => switch (code) {
        0 => 'Céu limpo',
        1 => 'Predominantemente limpo',
        2 => 'Parcialmente nublado',
        3 => 'Nublado',
        45 || 48 => 'Nevoeiro',
        51 || 53 || 55 => 'Garoa',
        56 || 57 => 'Garoa congelante',
        61 || 63 || 65 => 'Chuva',
        66 || 67 => 'Chuva congelante',
        71 || 73 || 75 || 77 => 'Neve',
        80 || 81 || 82 => 'Pancadas de chuva',
        85 || 86 => 'Pancadas de neve',
        95 => 'Trovoadas',
        96 || 99 => 'Trovoadas com granizo',
        _ => null,
      };

  static String windDirectionLabel(double? degrees) {
    if (degrees == null || !degrees.isFinite) return '--';
    const labels = <String>['N', 'NE', 'L', 'SE', 'S', 'SO', 'O', 'NO'];
    final normalized = ((degrees % 360) + 360) % 360;
    return labels[((normalized + 22.5) ~/ 45) % 8];
  }

  static String buildVoiceMessage(MapWeatherSnapshot snapshot) {
    final parts = <String>[];
    final temperature = snapshot.temperatureC;
    if (temperature != null) {
      final rounded = temperature.value.round();
      parts.add(
        temperature.source == MapWeatherSource.esp32
            ? 'Temperatura medida pelo sensor: $rounded graus.'
            : 'Temperatura online: $rounded graus.',
      );
    }
    final condition = conditionLabel(snapshot.weatherCode?.value);
    final chance = snapshot.precipitationProbabilityPercent;
    if (condition != null || chance != null) {
      final forecast = <String>[];
      if (condition != null) forecast.add(condition.toLowerCase());
      if (chance != null) {
        forecast.add(
          'possibilidade de chuva nas próximas horas: ${chance.value.round()} por cento',
        );
      }
      parts.add('Previsão online: ${forecast.join('. ')}.');
    }
    return parts.join(' ').trim();
  }

  static MapRideWeatherAssessment assessForRide(MapWeatherSnapshot snapshot) {
    if (!snapshot.hasValues) {
      return const MapRideWeatherAssessment(
        level: MapRideWeatherLevel.unavailable,
        summary: 'Aguardando clima',
      );
    }

    final hours = snapshot.hourlyForecast.take(6).toList(growable: false);
    final hasHazardData = hours.isNotEmpty ||
        snapshot.precipitationProbabilityPercent != null ||
        snapshot.windSpeedKmh != null ||
        snapshot.weatherCode != null;
    if (!hasHazardData) {
      return const MapRideWeatherAssessment(
        level: MapRideWeatherLevel.unavailable,
        summary: 'Previsão insuficiente para avaliar o pedal',
        detail: 'Sensores locais continuam visíveis, mas faltam dados de chuva, vento ou condição do tempo.',
      );
    }

    double? maxRain = snapshot.precipitationProbabilityPercent?.value;
    double? maxWind = snapshot.windSpeedKmh?.value;
    double? maxGust;
    var storm = (snapshot.weatherCode?.value ?? -1) >= 95;
    for (final hour in hours) {
      final rain = hour.precipitationProbabilityPercent;
      if (rain != null && (maxRain == null || rain > maxRain)) maxRain = rain;
      final wind = hour.windSpeedKmh;
      if (wind != null && (maxWind == null || wind > maxWind)) maxWind = wind;
      final gust = hour.windGustKmh;
      if (gust != null && (maxGust == null || gust > maxGust)) maxGust = gust;
      final code = hour.weatherCode;
      if (code != null && code >= 95) storm = true;
    }

    final feels = snapshot.apparentTemperatureC?.value ?? snapshot.temperatureC?.value;
    if (storm || (maxGust != null && maxGust >= 60) || (maxRain != null && maxRain >= 85)) {
      return MapRideWeatherAssessment(
        level: MapRideWeatherLevel.critical,
        summary: storm ? 'Trovoadas no horizonte' : 'Condição severa nas próximas horas',
        detail: _rideWeatherDetail(maxRain: maxRain, maxWind: maxWind, maxGust: maxGust),
      );
    }
    if ((maxRain != null && maxRain >= 50) ||
        (maxWind != null && maxWind >= 35) ||
        (maxGust != null && maxGust >= 45) ||
        (feels != null && (feels <= 5 || feels >= 38))) {
      return MapRideWeatherAssessment(
        level: MapRideWeatherLevel.attention,
        summary: 'Condições exigem atenção',
        detail: _rideWeatherDetail(maxRain: maxRain, maxWind: maxWind, maxGust: maxGust),
      );
    }
    return MapRideWeatherAssessment(
      level: MapRideWeatherLevel.favorable,
      summary: 'Sem alerta meteorológico pelos limites locais',
      detail: _rideWeatherDetail(maxRain: maxRain, maxWind: maxWind, maxGust: maxGust),
    );
  }

  static String? _rideWeatherDetail({
    double? maxRain,
    double? maxWind,
    double? maxGust,
  }) {
    final parts = <String>[];
    if (maxRain != null) parts.add('chuva até ${maxRain.round()}%');
    if (maxWind != null) parts.add('vento até ${maxWind.round()} km/h');
    if (maxGust != null) parts.add('rajadas até ${maxGust.round()} km/h');
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

enum MapRideWeatherLevel { unavailable, favorable, attention, critical }

extension MapRideWeatherLevelLabel on MapRideWeatherLevel {
  String get label => switch (this) {
        MapRideWeatherLevel.unavailable => 'Sem dados',
        MapRideWeatherLevel.favorable => 'Favorável',
        MapRideWeatherLevel.attention => 'Atenção',
        MapRideWeatherLevel.critical => 'Cuidado',
      };
}

class MapRideWeatherAssessment {
  const MapRideWeatherAssessment({
    required this.level,
    required this.summary,
    this.detail,
  });

  final MapRideWeatherLevel level;
  final String summary;
  final String? detail;
}
