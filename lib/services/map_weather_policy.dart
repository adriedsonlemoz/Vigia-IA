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
}
