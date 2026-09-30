import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/map_weather.dart';
import 'package:vigiaia/services/map_weather_service.dart';

void main() {
  test('decoder online preserva condicao atual e previsao horaria real', () {
    final data = MapWeatherService.decodeOnlineResponse(
      <String, dynamic>{
        'current': <String, dynamic>{
          'time': '2026-09-26T15:00',
          'temperature_2m': 28.4,
          'relative_humidity_2m': 66,
          'apparent_temperature': 30.1,
          'precipitation': 0.2,
          'rain': 0.2,
          'weather_code': 61,
          'surface_pressure': 1008.3,
          'wind_speed_10m': 14.2,
          'wind_direction_10m': 120,
        },
        'hourly': <String, dynamic>{
          'time': <String>[
            '2026-09-26T15:00',
            '2026-09-26T16:00',
            '2026-09-26T17:00',
          ],
          'temperature_2m': <double>[28.4, 27.8, 26.9],
          'apparent_temperature': <double>[30.1, 29.4, 28.2],
          'precipitation_probability': <int>[20, 40, 70],
          'precipitation': <double>[0.2, 0.4, 1.8],
          'weather_code': <int>[61, 61, 63],
          'wind_speed_10m': <double>[14.2, 18.0, 21.0],
          'wind_gusts_10m': <double>[25.0, 30.0, 36.0],
          'wind_direction_10m': <int>[120, 125, 130],
        },
      },
      latitude: -23.5,
      longitude: -46.6,
      receivedAt: DateTime.utc(2026, 9, 26, 15, 1),
    );

    expect(data.temperatureC, 28.4);
    expect(data.humidityPercent, 66);
    expect(data.surfacePressureHpa, 1008.3);
    expect(data.weatherCode, 61);
    expect(data.precipitationProbabilityPercent, 70);
    expect(data.windDirectionDegrees, 120);
    expect(data.hourlyForecast, hasLength(3));
    expect(data.hourlyForecast.last.precipitationProbabilityPercent, 70);
    expect(data.hourlyForecast.last.windGustKmh, 36);
  });

  test('decoder nao transforma campo ausente em zero', () {
    final data = MapWeatherService.decodeOnlineResponse(
      <String, dynamic>{
        'current': <String, dynamic>{
          'time': '2026-09-26T15:00',
          'temperature_2m': 24.0,
        },
        'hourly': <String, dynamic>{},
      },
      latitude: -23.5,
      longitude: -46.6,
      receivedAt: DateTime.utc(2026, 9, 26, 15, 1),
    );

    expect(data.temperatureC, 24);
    expect(data.humidityPercent, isNull);
    expect(data.weatherCode, isNull);
    expect(data.precipitationProbabilityPercent, isNull);
    expect(data.hourlyForecast, isEmpty);
  });

  test('cache meteorologico preserva previsao horaria', () {
    final original = MapWeatherOnlineData(
      latitude: -23.5,
      longitude: -46.6,
      updatedAt: DateTime.utc(2026, 9, 26, 15),
      observedAt: DateTime.utc(2026, 9, 26, 15),
      temperatureC: 25,
      hourlyForecast: <MapWeatherForecastHour>[
        MapWeatherForecastHour(
          time: DateTime.utc(2026, 9, 26, 16),
          temperatureC: 24,
          precipitationProbabilityPercent: 35,
          windGustKmh: 31,
        ),
      ],
    );

    final restored = MapWeatherOnlineData.fromJson(
      original.toJson().cast<String, dynamic>(),
    );
    expect(restored.temperatureC, 25);
    expect(restored.hourlyForecast, hasLength(1));
    expect(restored.hourlyForecast.single.temperatureC, 24);
    expect(restored.hourlyForecast.single.windGustKmh, 31);
  });
}
