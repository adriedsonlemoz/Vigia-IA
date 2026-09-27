import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/esp32_module.dart';
import '../models/esp32_telemetry.dart';
import '../models/map_weather.dart';
import 'error_log_service.dart';
import 'esp32_module_service.dart';
import 'esp32_telemetry_service.dart';
import 'map_weather_policy.dart';
import 'data_usage_service.dart';

class MapWeatherService extends ChangeNotifier {
  MapWeatherService._();

  static final MapWeatherService instance = MapWeatherService._();
  static const String providerLabel = 'Open-Meteo';
  static const String _providerHost = String.fromEnvironment(
    'OPEN_METEO_HOST',
    defaultValue: 'api.open-meteo.com',
  );
  static const String _providerApiKey = String.fromEnvironment(
    'OPEN_METEO_API_KEY',
  );

  final Esp32TelemetryService _esp32 = Esp32TelemetryService.instance;
  final Esp32ModuleService _modules = Esp32ModuleService.instance;
  final ErrorLogService _logs = ErrorLogService.instance;

  File? _cacheFile;
  HttpClient? _client;
  bool _initialized = false;
  Future<void>? _initializing;
  bool _loading = false;
  String? _lastError;
  DateTime? _lastAttemptAt;
  double? _activeLatitude;
  double? _activeLongitude;
  MapWeatherOnlineData? _onlineCache;
  MapWeatherSnapshot _snapshot = const MapWeatherSnapshot();
  String _fingerprint = '';

  bool get loading => _loading;
  String? get lastError => _lastError;
  MapWeatherSnapshot get snapshot => _snapshot;
  DateTime? get lastOnlineUpdate => _onlineCache?.updatedAt;

  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    final pending = _initializing;
    if (pending != null) return pending;
    final operation = _initializeInternal();
    _initializing = operation;
    return operation.whenComplete(() => _initializing = null);
  }

  Future<void> _initializeInternal() async {
    if (_initialized) return;
    await Future.wait<void>([
      _esp32.initialize(),
      _modules.initialize(),
    ]);
    final root = await getApplicationSupportDirectory();
    _cacheFile = File(
      '${root.path}${Platform.pathSeparator}map_weather_cache.json',
    );
    await _loadCache();
    _esp32.addListener(_onEsp32Changed);
    _modules.addListener(_onEsp32Changed);
    _initialized = true;
    _recomputeSnapshot();
  }

  Future<void> refreshForLocation({
    required double latitude,
    required double longitude,
    bool force = false,
  }) async {
    await initialize();
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return;
    }

    _activeLatitude = latitude;
    _activeLongitude = longitude;

    final now = DateTime.now();
    final cache = _onlineCache;
    final cacheNear = cache != null &&
        _distanceKm(
              latitude,
              longitude,
              cache.latitude,
              cache.longitude,
            ) <=
            MapWeatherPolicy.locationRefreshDistanceKm;
    if (!force &&
        DataUsageService.instance.dataSaverEnabled &&
        cacheNear &&
        now.difference(cache.updatedAt) < const Duration(hours: 2)) {
      _recomputeSnapshot();
      return;
    }
    if (!force &&
        cacheNear &&
        MapWeatherPolicy.cacheFresh(cache.updatedAt, now)) {
      _recomputeSnapshot();
      return;
    }
    final lastAttempt = _lastAttemptAt;
    if (!force &&
        lastAttempt != null &&
        now.difference(lastAttempt) <
            MapWeatherPolicy.minimumAutomaticRefreshInterval) {
      _recomputeSnapshot();
      return;
    }
    if (_loading) return;

    _loading = true;
    _lastAttemptAt = now;
    _lastError = null;
    notifyListeners();
    try {
      final cacheValue = await _fetchOnline(latitude, longitude);
      _onlineCache = cacheValue;
      await _persistCache(cacheValue);
    } catch (error, stackTrace) {
      _lastError = _friendlyError(error);
      unawaited(
        _logs.recordException(
          source: 'Mapa / Clima',
          error: '${error.runtimeType}: ${_friendlyError(error)}',
          stackTrace: stackTrace,
          level: ErrorLogLevel.warning,
          message:
              'Não foi possível atualizar o clima online; cache e sensores locais foram preservados.',
          context: const <String, Object?>{
            'provider': providerLabel,
          },
        ),
      );
    } finally {
      _loading = false;
      _recomputeSnapshot(forceNotify: true);
    }
  }

  Future<MapWeatherOnlineData> _fetchOnline(
    double latitude,
    double longitude,
  ) async {
    final query = <String, String>{
      'latitude': latitude.toStringAsFixed(5),
      'longitude': longitude.toStringAsFixed(5),
      'current': <String>[
        'temperature_2m',
        'relative_humidity_2m',
        'apparent_temperature',
        'precipitation',
        'rain',
        'weather_code',
        'surface_pressure',
        'wind_speed_10m',
        'wind_direction_10m',
      ].join(','),
      'hourly': <String>[
        'temperature_2m',
        'apparent_temperature',
        'precipitation_probability',
        'precipitation',
        'weather_code',
        'wind_speed_10m',
        'wind_gusts_10m',
        'wind_direction_10m',
      ].join(','),
      'forecast_hours': '12',
      'timezone': 'GMT',
      if (_providerApiKey.isNotEmpty) 'apikey': _providerApiKey,
    };
    final uri = Uri.https(_providerHost, '/v1/forecast', query);
    final client = _client ??= HttpClient()
      ..connectionTimeout = const Duration(seconds: 5);
    final request = await client.getUrl(uri);
    request.headers.set('accept', 'application/json');
    request.headers.set('user-agent', 'VigiaIA/1.0.201 (weather)');
    final response = await request.close().timeout(const Duration(seconds: 8));
    final body = await utf8.decoder
        .bind(response)
        .join()
        .timeout(const Duration(seconds: 8));
    DataUsageService.instance.record(
      DataUsageModule.weather,
      received: utf8.encode(body).length,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const FormatException('Resposta do clima sem objeto JSON.');
    }
    return decodeOnlineResponse(
      decoded.cast<String, dynamic>(),
      latitude: latitude,
      longitude: longitude,
      receivedAt: DateTime.now(),
    );
  }

  @visibleForTesting
  static MapWeatherOnlineData decodeOnlineResponse(
    Map<String, dynamic> json, {
    required double latitude,
    required double longitude,
    required DateTime receivedAt,
  }) {
    final current = _stringMap(json['current']) ?? const <String, dynamic>{};
    if (current.isEmpty) {
      throw const FormatException('Resposta do clima sem condições atuais.');
    }
    final observedAt = _parseDate(current['time']) ?? receivedAt;
    final hourly = _stringMap(json['hourly']) ?? const <String, dynamic>{};
    final probability = _maximumProbability(hourly['precipitation_probability']);
    final forecast = _decodeHourlyForecast(hourly);
    return MapWeatherOnlineData(
      latitude: latitude,
      longitude: longitude,
      updatedAt: receivedAt,
      observedAt: observedAt,
      temperatureC: _finiteDouble(current['temperature_2m'], min: -100, max: 70),
      apparentTemperatureC:
          _finiteDouble(current['apparent_temperature'], min: -120, max: 80),
      humidityPercent:
          _finiteDouble(current['relative_humidity_2m'], min: 0, max: 100),
      surfacePressureHpa:
          _finiteDouble(current['surface_pressure'], min: 300, max: 1200),
      windSpeedKmh:
          _finiteDouble(current['wind_speed_10m'], min: 0, max: 500),
      windDirectionDegrees:
          _finiteDouble(current['wind_direction_10m'], min: 0, max: 360),
      weatherCode: _finiteInt(current['weather_code'], min: 0, max: 99),
      precipitationProbabilityPercent: probability,
      precipitationMm:
          _finiteDouble(current['precipitation'], min: 0, max: 1000),
      rainMm: _finiteDouble(current['rain'], min: 0, max: 1000),
      hourlyForecast: forecast,
    );
  }

  void _onEsp32Changed() => _recomputeSnapshot();

  void _recomputeSnapshot({bool forceNotify = false}) {
    final esp32 = _esp32Snapshot();
    final online = _onlineSnapshot();
    final next = MapWeatherPolicy.merge(esp32: esp32, online: online);
    final nextFingerprint = _snapshotFingerprint(next);
    _snapshot = next;
    if (forceNotify || nextFingerprint != _fingerprint) {
      _fingerprint = nextFingerprint;
      notifyListeners();
    }
  }

  MapWeatherSnapshot _esp32Snapshot() {
    MapWeatherValue<double>? temperature;
    MapWeatherValue<double>? humidity;
    MapWeatherValue<double>? pressure;
    final modules = <String, Esp32Module>{
      for (final module in _modules.modules) module.id: module,
    };
    final states = _esp32.states.values.toList()
      ..sort((a, b) {
        final am = modules[a.moduleId];
        final bm = modules[b.moduleId];
        final ap = am?.position == Esp32ModulePosition.environment ? 0 : 1;
        final bp = bm?.position == Esp32ModulePosition.environment ? 0 : 1;
        if (ap != bp) return ap.compareTo(bp);
        return (b.lastSuccessAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.lastSuccessAt ?? DateTime.fromMillisecondsSinceEpoch(0));
      });

    final now = DateTime.now();
    for (final state in states) {
      final module = modules[state.moduleId];
      final packet = state.packet;
      final lastSuccess = state.lastSuccessAt;
      if (module == null || packet == null || !module.enabled || lastSuccess == null) {
        continue;
      }
      final fresh = now.difference(lastSuccess) <= module.staleAfter;
      if (!fresh ||
          (state.connectionState != Esp32ConnectionState.online &&
              state.connectionState != Esp32ConnectionState.degraded)) {
        continue;
      }
      final env = packet.environmentPayload;
      final observedAt = _parseDate(env['capturedAt']) ??
          packet.capturedAt ??
          packet.receivedAt;
      final detail = module.name;
      temperature ??= _weatherValue(
        _finiteDouble(env['temperatureC'], min: -80, max: 80) ??
            _finiteDouble(packet.bikePayload['temperatureC'], min: -80, max: 80),
        source: MapWeatherSource.esp32,
        observedAt: observedAt,
        sourceDetail: detail,
      );
      humidity ??= _weatherValue(
        _finiteDouble(env['humidityPercent'], min: 0, max: 100),
        source: MapWeatherSource.esp32,
        observedAt: observedAt,
        sourceDetail: detail,
      );
      pressure ??= _weatherValue(
        _finiteDouble(env['pressureHpa'], min: 300, max: 1200),
        source: MapWeatherSource.esp32,
        observedAt: observedAt,
        sourceDetail: detail,
      );
      if (temperature != null && humidity != null && pressure != null) break;
    }
    return MapWeatherSnapshot(
      temperatureC: temperature,
      humidityPercent: humidity,
      surfacePressureHpa: pressure,
    );
  }

  MapWeatherSnapshot _onlineSnapshot() {
    final cache = _onlineCache;
    final activeLatitude = _activeLatitude;
    final activeLongitude = _activeLongitude;
    if (cache == null || activeLatitude == null || activeLongitude == null) {
      return const MapWeatherSnapshot();
    }
    final cacheNear = _distanceKm(
          activeLatitude,
          activeLongitude,
          cache.latitude,
          cache.longitude,
        ) <=
        MapWeatherPolicy.locationRefreshDistanceKm;
    if (!cacheNear) return const MapWeatherSnapshot();
    final stale = MapWeatherPolicy.cacheStale(cache.updatedAt, DateTime.now());
    MapWeatherValue<double>? value(double? raw) => _weatherValue(
          raw,
          source: MapWeatherSource.online,
          observedAt: cache.observedAt,
          sourceDetail: providerLabel,
        );
    return MapWeatherSnapshot(
      temperatureC: value(cache.temperatureC),
      apparentTemperatureC: value(cache.apparentTemperatureC),
      humidityPercent: value(cache.humidityPercent),
      surfacePressureHpa: value(cache.surfacePressureHpa),
      windSpeedKmh: value(cache.windSpeedKmh),
      windDirectionDegrees: value(cache.windDirectionDegrees),
      weatherCode: cache.weatherCode == null
          ? null
          : MapWeatherValue<int>(
              value: cache.weatherCode!,
              source: MapWeatherSource.online,
              observedAt: cache.observedAt,
              sourceDetail: providerLabel,
            ),
      precipitationProbabilityPercent:
          value(cache.precipitationProbabilityPercent),
      precipitationMm: value(cache.precipitationMm),
      rainMm: value(cache.rainMm),
      hourlyForecast: cache.hourlyForecast,
      onlineUpdatedAt: cache.updatedAt,
      onlineStale: stale,
    );
  }

  Future<void> _loadCache() async {
    final file = _cacheFile;
    if (file == null || !await file.exists()) return;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map) {
        _onlineCache = MapWeatherOnlineData.fromJson(
          decoded.cast<String, dynamic>(),
        );
      }
    } catch (error, stackTrace) {
      unawaited(
        _logs.recordException(
          source: 'Mapa / Clima',
          error: error,
          stackTrace: stackTrace,
          level: ErrorLogLevel.info,
          message: 'Cache local de clima inválido foi ignorado.',
        ),
      );
    }
  }

  Future<void> _persistCache(MapWeatherOnlineData cache) async {
    final file = _cacheFile;
    if (file == null) return;
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(cache.toJson()), flush: true);
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
  }

  static MapWeatherValue<double>? _weatherValue(
    double? value, {
    required MapWeatherSource source,
    required DateTime observedAt,
    required String sourceDetail,
  }) =>
      value == null
          ? null
          : MapWeatherValue<double>(
              value: value,
              source: source,
              observedAt: observedAt,
              sourceDetail: sourceDetail,
            );

  static String _snapshotFingerprint(MapWeatherSnapshot value) => <Object?>[
        _round(value.temperatureC?.value, 1),
        value.temperatureC?.source.name,
        _round(value.apparentTemperatureC?.value, 1),
        _round(value.humidityPercent?.value, 0),
        value.humidityPercent?.source.name,
        _round(value.surfacePressureHpa?.value, 1),
        value.surfacePressureHpa?.source.name,
        _round(value.windSpeedKmh?.value, 1),
        _round(value.windDirectionDegrees?.value, 0),
        value.weatherCode?.value,
        _round(value.precipitationProbabilityPercent?.value, 0),
        _round(value.precipitationMm?.value, 1),
        _round(value.rainMm?.value, 1),
        value.hourlyForecast.length,
        for (final item in value.hourlyForecast)
          <Object?>[
            item.time.millisecondsSinceEpoch,
            _round(item.temperatureC, 1),
            _round(item.precipitationProbabilityPercent, 0),
            _round(item.windSpeedKmh, 1),
            _round(item.windGustKmh, 1),
            item.weatherCode,
          ].join(':'),
        value.origin.name,
        value.onlineStale,
      ].join('|');

  static double? _round(double? value, int digits) {
    if (value == null) return null;
    final factor = math.pow(10, digits).toDouble();
    return (value * factor).round() / factor;
  }

  static double _distanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const radiusKm = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return radiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static Map<String, dynamic>? _stringMap(Object? value) {
    if (value is! Map) return null;
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  static DateTime? _parseDate(Object? value) {
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        value.toInt() * 1000,
        isUtc: true,
      );
    }
    if (value is! String || value.trim().isEmpty) return null;
    final text = value.trim();
    final hasZone = text.endsWith('Z') ||
        RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(text);
    return DateTime.tryParse(hasZone ? text : '${text}Z');
  }

  static double? _finiteDouble(Object? value, {double? min, double? max}) {
    final double? parsed;
    if (value is num) {
      parsed = value.toDouble();
    } else if (value is String) {
      parsed = double.tryParse(value.replaceAll(',', '.'));
    } else {
      parsed = null;
    }
    if (parsed == null || !parsed.isFinite) return null;
    if (min != null && parsed < min) return null;
    if (max != null && parsed > max) return null;
    return parsed;
  }

  static int? _finiteInt(Object? value, {required int min, required int max}) {
    final int? parsed;
    if (value is num) {
      parsed = value.toInt();
    } else if (value is String) {
      parsed = int.tryParse(value);
    } else {
      parsed = null;
    }
    if (parsed == null || parsed < min || parsed > max) return null;
    return parsed;
  }

  static double? _maximumProbability(Object? value) {
    if (value is! List) return null;
    double? result;
    for (final item in value) {
      final parsed = _finiteDouble(item, min: 0, max: 100);
      if (parsed != null && (result == null || parsed > result)) result = parsed;
    }
    return result;
  }

  static List<MapWeatherForecastHour> _decodeHourlyForecast(
    Map<String, dynamic> hourly,
  ) {
    final times = hourly['time'];
    if (times is! List || times.isEmpty) {
      return const <MapWeatherForecastHour>[];
    }

    Object? at(String key, int index) {
      final values = hourly[key];
      if (values is! List || index < 0 || index >= values.length) return null;
      return values[index];
    }

    final result = <MapWeatherForecastHour>[];
    for (var index = 0; index < times.length && result.length < 12; index++) {
      final time = _parseDate(times[index]);
      if (time == null) continue;
      final item = MapWeatherForecastHour(
        time: time,
        temperatureC: _finiteDouble(
          at('temperature_2m', index),
          min: -100,
          max: 70,
        ),
        apparentTemperatureC: _finiteDouble(
          at('apparent_temperature', index),
          min: -120,
          max: 80,
        ),
        precipitationProbabilityPercent: _finiteDouble(
          at('precipitation_probability', index),
          min: 0,
          max: 100,
        ),
        precipitationMm: _finiteDouble(
          at('precipitation', index),
          min: 0,
          max: 1000,
        ),
        weatherCode: _finiteInt(
          at('weather_code', index),
          min: 0,
          max: 99,
        ),
        windSpeedKmh: _finiteDouble(
          at('wind_speed_10m', index),
          min: 0,
          max: 500,
        ),
        windGustKmh: _finiteDouble(
          at('wind_gusts_10m', index),
          min: 0,
          max: 500,
        ),
        windDirectionDegrees: _finiteDouble(
          at('wind_direction_10m', index),
          min: 0,
          max: 360,
        ),
      );
      if (item.hasValues) result.add(item);
    }
    return List<MapWeatherForecastHour>.unmodifiable(result);
  }

  static String _friendlyError(Object error) {
    if (error is SocketException) return 'Sem conexão com o serviço de clima.';
    if (error is TimeoutException) return 'Tempo limite ao consultar o clima.';
    if (error is HttpException) return error.message;
    if (error is FormatException) return error.message;
    return 'Falha ao atualizar o clima online.';
  }
}

class MapWeatherOnlineData {
  const MapWeatherOnlineData({
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
    required this.observedAt,
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
  });

  final double latitude;
  final double longitude;
  final DateTime updatedAt;
  final DateTime observedAt;
  final double? temperatureC;
  final double? apparentTemperatureC;
  final double? humidityPercent;
  final double? surfacePressureHpa;
  final double? windSpeedKmh;
  final double? windDirectionDegrees;
  final int? weatherCode;
  final double? precipitationProbabilityPercent;
  final double? precipitationMm;
  final double? rainMm;
  final List<MapWeatherForecastHour> hourlyForecast;

  Map<String, Object?> toJson() => <String, Object?>{
        'version': 2,
        'latitude': latitude,
        'longitude': longitude,
        'updatedAt': updatedAt.toIso8601String(),
        'observedAt': observedAt.toIso8601String(),
        'temperatureC': temperatureC,
        'apparentTemperatureC': apparentTemperatureC,
        'humidityPercent': humidityPercent,
        'surfacePressureHpa': surfacePressureHpa,
        'windSpeedKmh': windSpeedKmh,
        'windDirectionDegrees': windDirectionDegrees,
        'weatherCode': weatherCode,
        'precipitationProbabilityPercent': precipitationProbabilityPercent,
        'precipitationMm': precipitationMm,
        'rainMm': rainMm,
        'hourlyForecast': <Map<String, Object?>>[
          for (final item in hourlyForecast) item.toJson(),
        ],
      };

  factory MapWeatherOnlineData.fromJson(Map<String, dynamic> json) {
    final updatedAt = DateTime.tryParse(json['updatedAt']?.toString() ?? '');
    final observedAt = DateTime.tryParse(json['observedAt']?.toString() ?? '');
    final latitude = MapWeatherService._finiteDouble(
      json['latitude'],
      min: -90,
      max: 90,
    );
    final longitude = MapWeatherService._finiteDouble(
      json['longitude'],
      min: -180,
      max: 180,
    );
    if (updatedAt == null || observedAt == null || latitude == null || longitude == null) {
      throw const FormatException('Cache de clima incompleto.');
    }
    final rawForecast = json['hourlyForecast'];
    final forecast = <MapWeatherForecastHour>[];
    if (rawForecast is List) {
      for (final raw in rawForecast) {
        if (raw is! Map) continue;
        try {
          forecast.add(
            MapWeatherForecastHour.fromJson(
              raw.map((key, value) => MapEntry(key.toString(), value)),
            ),
          );
        } catch (_) {
          // Um item inválido não deve descartar todo o cache meteorológico.
        }
      }
    }
    return MapWeatherOnlineData(
      latitude: latitude,
      longitude: longitude,
      updatedAt: updatedAt,
      observedAt: observedAt,
      temperatureC: MapWeatherService._finiteDouble(
        json['temperatureC'],
        min: -100,
        max: 70,
      ),
      apparentTemperatureC: MapWeatherService._finiteDouble(
        json['apparentTemperatureC'],
        min: -120,
        max: 80,
      ),
      humidityPercent: MapWeatherService._finiteDouble(
        json['humidityPercent'],
        min: 0,
        max: 100,
      ),
      surfacePressureHpa: MapWeatherService._finiteDouble(
        json['surfacePressureHpa'],
        min: 300,
        max: 1200,
      ),
      windSpeedKmh: MapWeatherService._finiteDouble(
        json['windSpeedKmh'],
        min: 0,
        max: 500,
      ),
      windDirectionDegrees: MapWeatherService._finiteDouble(
        json['windDirectionDegrees'],
        min: 0,
        max: 360,
      ),
      weatherCode: MapWeatherService._finiteInt(
        json['weatherCode'],
        min: 0,
        max: 99,
      ),
      precipitationProbabilityPercent: MapWeatherService._finiteDouble(
        json['precipitationProbabilityPercent'],
        min: 0,
        max: 100,
      ),
      precipitationMm: MapWeatherService._finiteDouble(
        json['precipitationMm'],
        min: 0,
        max: 1000,
      ),
      rainMm: MapWeatherService._finiteDouble(
        json['rainMm'],
        min: 0,
        max: 1000,
      ),
      hourlyForecast: List<MapWeatherForecastHour>.unmodifiable(forecast),
    );
  }
}
