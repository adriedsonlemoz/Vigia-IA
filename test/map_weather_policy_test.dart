import 'package:flutter_test/flutter_test.dart';
import 'package:vigiaia/models/map_weather.dart';
import 'package:vigiaia/services/map_weather_policy.dart';

MapWeatherValue<double> value(
  double number,
  MapWeatherSource source,
) =>
    MapWeatherValue<double>(
      value: number,
      source: source,
      observedAt: DateTime.utc(2026, 9, 26, 12),
      sourceDetail: source.label,
    );

void main() {
  test('ESP32 tem prioridade apenas nos campos fisicamente medidos', () {
    final merged = MapWeatherPolicy.merge(
      esp32: MapWeatherSnapshot(
        temperatureC: value(27.2, MapWeatherSource.esp32),
        humidityPercent: value(68, MapWeatherSource.esp32),
      ),
      online: MapWeatherSnapshot(
        temperatureC: value(29, MapWeatherSource.online),
        apparentTemperatureC: value(31, MapWeatherSource.online),
        weatherCode: MapWeatherValue<int>(
          value: 61,
          source: MapWeatherSource.online,
          observedAt: DateTime.utc(2026, 9, 26, 12),
        ),
        windSpeedKmh: value(12, MapWeatherSource.online),
      ),
    );

    expect(merged.temperatureC!.value, 27.2);
    expect(merged.temperatureC!.source, MapWeatherSource.esp32);
    expect(merged.humidityPercent!.source, MapWeatherSource.esp32);
    expect(merged.apparentTemperatureC!.source, MapWeatherSource.online);
    expect(merged.weatherCode!.source, MapWeatherSource.online);
    expect(merged.origin, MapWeatherOrigin.mixed);
  });

  test('temperatura isolada do ESP32 nao inventa condicao meteorologica', () {
    final merged = MapWeatherPolicy.merge(
      esp32: MapWeatherSnapshot(
        temperatureC: value(26.8, MapWeatherSource.esp32),
      ),
      online: const MapWeatherSnapshot(),
    );

    expect(merged.temperatureC, isNotNull);
    expect(merged.weatherCode, isNull);
    expect(MapWeatherPolicy.conditionLabel(merged.weatherCode?.value), isNull);
    expect(merged.origin, MapWeatherOrigin.esp32);
  });

  test('cache diferencia valido de antigo', () {
    final at = DateTime.utc(2026, 9, 26, 12);
    expect(
      MapWeatherPolicy.cacheFresh(at, at.add(const Duration(minutes: 14))),
      isTrue,
    );
    expect(
      MapWeatherPolicy.cacheFresh(at, at.add(const Duration(minutes: 16))),
      isFalse,
    );
    expect(
      MapWeatherPolicy.cacheStale(at, at.add(const Duration(minutes: 46))),
      isTrue,
    );
  });

  test('fala identifica sensor e previsao online sem inferir dados ausentes', () {
    final snapshot = MapWeatherSnapshot(
      temperatureC: value(27.1, MapWeatherSource.esp32),
      precipitationProbabilityPercent: value(60, MapWeatherSource.online),
    );

    final phrase = MapWeatherPolicy.buildVoiceMessage(snapshot);
    expect(phrase, contains('Temperatura medida pelo sensor: 27 graus.'));
    expect(phrase, contains('60 por cento'));
    expect(phrase, isNot(contains('ensolarado')));
  });

  test('codigo WMO conhecido vira descricao; desconhecido permanece sem inferencia', () {
    expect(MapWeatherPolicy.conditionLabel(0), 'Céu limpo');
    expect(MapWeatherPolicy.conditionLabel(63), 'Chuva');
    expect(MapWeatherPolicy.conditionLabel(999), isNull);
  });
}
