import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/services/map_weather_service.dart';

void main() {
  test('decoder online usa somente campos realmente retornados', () {
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
          'precipitation_probability': <int>[20, 40, 70, 50],
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
  });
}
