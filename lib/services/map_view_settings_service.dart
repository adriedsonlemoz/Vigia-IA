import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/bike_trip_plan.dart';
import '../models/map_travel_mode.dart';
import 'map_view_policy.dart';


enum MapAppearancePreset {
  standard,
  dark,
  highContrast,
  bikeTravel,
}

extension MapAppearancePresetX on MapAppearancePreset {
  String get label => switch (this) {
        MapAppearancePreset.standard => 'Padrão',
        MapAppearancePreset.dark => 'Escuro',
        MapAppearancePreset.highContrast => 'Alto contraste',
        MapAppearancePreset.bikeTravel => 'Bike/Viagem',
      };

  String get description => switch (this) {
        MapAppearancePreset.standard =>
          'Cores equilibradas para uso geral e leitura natural do mapa.',
        MapAppearancePreset.dark =>
          'Style vetorial escuro e sobreposições claras para uso noturno.',
        MapAppearancePreset.highContrast =>
          'Aumenta a separação visual de vias, rota, posição e pontos.',
        MapAppearancePreset.bikeTravel =>
          'Realça rota, natureza e referências úteis durante deslocamentos.',
      };
}

enum MapAppearanceMode {
  manual,
  followSystem,
  dayNight,
}

extension MapAppearanceModeX on MapAppearanceMode {
  String get label => switch (this) {
        MapAppearanceMode.manual => 'Manual',
        MapAppearanceMode.followSystem => 'Sistema',
        MapAppearanceMode.dayNight => 'Dia/noite',
      };
}

enum MapProvider {
  current,
  google,
}

extension MapProviderX on MapProvider {
  String get label => switch (this) {
        MapProvider.current => 'Mapa atual',
        MapProvider.google => 'Google Maps',
      };
}

enum MapStylePreset {
  standard,
  bikeTravel,
  terrain,
  topographic,
  satellite,
}

extension MapStylePresetX on MapStylePreset {
  String get label => switch (this) {
        MapStylePreset.standard => 'Padrão',
        MapStylePreset.bikeTravel => 'Bike/Viagem',
        MapStylePreset.terrain => 'Terreno',
        MapStylePreset.topographic => 'Topográfico',
        MapStylePreset.satellite => 'Satélite',
      };

  String get description => switch (this) {
        MapStylePreset.standard =>
          'Mapa geral leve, com ruas, cidades e pontos básicos.',
        MapStylePreset.bikeTravel =>
          'Prioriza leitura de estradas, natureza e contexto de viagem.',
        MapStylePreset.terrain =>
          'Relevo e hillshade para leitura de serras e variação do terreno.',
        MapStylePreset.topographic =>
          'Topografia, relevo, água e elementos naturais com maior contraste.',
        MapStylePreset.satellite =>
          'Imagem aérea/satélite com referências e rótulos.',
      };

  bool get needsStadiaKey =>
      this == MapStylePreset.terrain || this == MapStylePreset.satellite;
}

class MapViewSettingsService extends ChangeNotifier {
  MapViewSettingsService._();

  static final MapViewSettingsService instance = MapViewSettingsService._();

  MapProvider _provider = MapProvider.current;
  MapOrientationMode _orientationMode = MapOrientationMode.northUp;
  MapFollowViewPreset _followViewPreset = MapFollowViewPreset.near;
  MapStylePreset _stylePreset = MapStylePreset.standard;
  MapAppearancePreset _appearancePreset = MapAppearancePreset.standard;
  MapAppearanceMode _appearanceMode = MapAppearanceMode.manual;
  MapTravelMode _lastTravelMode = MapTravelMode.bicycle;
  double _bikeAverageSpeedKmh = 15;
  double _bikeRidingHoursPerDay = 5;
  bool _bikeBalanceDays = true;
  bool _bikeUseHistoricalSpeed = false;
  bool _navigationVoiceEnabled = true;
  bool _weatherVoiceEnabled = true;
  bool _initialized = false;
  File? _file;

  bool get initialized => _initialized;
  MapProvider get provider => _provider;
  MapOrientationMode get orientationMode => _orientationMode;
  MapFollowViewPreset get followViewPreset => _followViewPreset;
  MapStylePreset get stylePreset => _stylePreset;
  MapAppearancePreset get appearancePreset => _appearancePreset;
  MapAppearanceMode get appearanceMode => _appearanceMode;
  MapTravelMode get lastTravelMode => _lastTravelMode;
  BikeTravelPreferences get bikeTravelPreferences => BikeTravelPreferences(
        averageSpeedKmh: _bikeAverageSpeedKmh,
        ridingHoursPerDay: _bikeRidingHoursPerDay,
        balanceDays: _bikeBalanceDays,
      );
  bool get bikeUseHistoricalSpeed => _bikeUseHistoricalSpeed;
  bool get navigationVoiceEnabled => _navigationVoiceEnabled;
  bool get weatherVoiceEnabled => _weatherVoiceEnabled;

  Future<void> initialize() async {
    if (_initialized) return;
    final root = await getApplicationSupportDirectory();
    _file = File('${root.path}${Platform.pathSeparator}map_view_settings.json');
    final file = _file!;
    if (await file.exists()) {
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map) {
          final map = decoded.cast<String, dynamic>();
          final providerName = map['provider'] as String?;
          final orientationName = map['orientationMode'] as String?;
          final presetName = map['followViewPreset'] as String?;
          final styleName = map['stylePreset'] as String?;
          final appearanceName = map['appearancePreset'] as String?;
          final appearanceModeName = map['appearanceMode'] as String?;
          final lastTravelMode = map['lastTravelMode'];
          final bikeAverageSpeedKmh = (map['bikeAverageSpeedKmh'] as num?)?.toDouble();
          final bikeRidingHoursPerDay =
              (map['bikeRidingHoursPerDay'] as num?)?.toDouble();
          final bikeBalanceDays = map['bikeBalanceDays'];
          final bikeUseHistoricalSpeed = map['bikeUseHistoricalSpeed'];
          final navigationVoiceEnabled = map['navigationVoiceEnabled'];
          final weatherVoiceEnabled = map['weatherVoiceEnabled'];
          _provider = MapProvider.values.firstWhere(
            (value) => value.name == providerName,
            orElse: () => MapProvider.current,
          );
          _orientationMode = orientationName == 'headingUp'
              ? MapOrientationMode.directionUp
              : MapOrientationMode.values.firstWhere(
                  (value) => value.name == orientationName,
                  orElse: () => MapOrientationMode.northUp,
                );
          _followViewPreset = MapFollowViewPreset.values.firstWhere(
            (value) => value.name == presetName,
            orElse: () => MapFollowViewPreset.near,
          );
          _stylePreset = MapStylePreset.values.firstWhere(
            (value) => value.name == styleName,
            orElse: () => MapStylePreset.standard,
          );
          _appearancePreset = MapAppearancePreset.values.firstWhere(
            (value) => value.name == appearanceName,
            orElse: () => MapAppearancePreset.standard,
          );
          _appearanceMode = MapAppearanceMode.values.firstWhere(
            (value) => value.name == appearanceModeName,
            orElse: () => MapAppearanceMode.manual,
          );
          _lastTravelMode = MapTravelModeX.fromStorage(lastTravelMode);
          _bikeAverageSpeedKmh =
              (bikeAverageSpeedKmh ?? 15).clamp(5.0, 40.0).toDouble();
          _bikeRidingHoursPerDay =
              (bikeRidingHoursPerDay ?? 5).clamp(1.0, 12.0).toDouble();
          _bikeBalanceDays = bikeBalanceDays as bool? ?? true;
          _bikeUseHistoricalSpeed = bikeUseHistoricalSpeed as bool? ?? false;
          _navigationVoiceEnabled = navigationVoiceEnabled as bool? ?? true;
          _weatherVoiceEnabled = weatherVoiceEnabled as bool? ?? true;
        }
      } catch (_) {
        _provider = MapProvider.current;
        _orientationMode = MapOrientationMode.northUp;
        _followViewPreset = MapFollowViewPreset.near;
        _stylePreset = MapStylePreset.standard;
        _appearancePreset = MapAppearancePreset.standard;
        _appearanceMode = MapAppearanceMode.manual;
        _lastTravelMode = MapTravelMode.bicycle;
        _bikeAverageSpeedKmh = 15;
        _bikeRidingHoursPerDay = 5;
        _bikeBalanceDays = true;
        _bikeUseHistoricalSpeed = false;
        _navigationVoiceEnabled = true;
        _weatherVoiceEnabled = true;
      }
    }
    _initialized = true;
  }

  Future<void> setProvider(MapProvider value) async {
    if (!_initialized) await initialize();
    if (_provider == value) return;
    _provider = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setOrientationMode(MapOrientationMode value) async {
    if (!_initialized) await initialize();
    if (_orientationMode == value) return;
    _orientationMode = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setFollowViewPreset(MapFollowViewPreset value) async {
    if (!_initialized) await initialize();
    if (_followViewPreset == value) return;
    _followViewPreset = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setLastTravelMode(MapTravelMode value) async {
    if (!_initialized) await initialize();
    if (_lastTravelMode == value) return;
    _lastTravelMode = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setBikeTravelPreferences(BikeTravelPreferences value) async {
    if (!_initialized) await initialize();
    final speed = value.averageSpeedKmh.clamp(5.0, 40.0).toDouble();
    final hours = value.ridingHoursPerDay.clamp(1.0, 12.0).toDouble();
    if (_bikeAverageSpeedKmh == speed &&
        _bikeRidingHoursPerDay == hours &&
        _bikeBalanceDays == value.balanceDays) {
      return;
    }
    _bikeAverageSpeedKmh = speed;
    _bikeRidingHoursPerDay = hours;
    _bikeBalanceDays = value.balanceDays;
    notifyListeners();
    await _persist();
  }

  Future<void> setBikeUseHistoricalSpeed(bool value) async {
    if (!_initialized) await initialize();
    if (_bikeUseHistoricalSpeed == value) return;
    _bikeUseHistoricalSpeed = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setNavigationVoiceEnabled(bool value) async {
    if (!_initialized) await initialize();
    if (_navigationVoiceEnabled == value) return;
    _navigationVoiceEnabled = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setWeatherVoiceEnabled(bool value) async {
    if (!_initialized) await initialize();
    if (_weatherVoiceEnabled == value) return;
    _weatherVoiceEnabled = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setAppearancePreset(MapAppearancePreset value) async {
    if (!_initialized) await initialize();
    if (_appearancePreset == value && _appearanceMode == MapAppearanceMode.manual) {
      return;
    }
    _appearancePreset = value;
    _appearanceMode = MapAppearanceMode.manual;
    notifyListeners();
    await _persist();
  }

  Future<void> setAppearanceMode(MapAppearanceMode value) async {
    if (!_initialized) await initialize();
    if (_appearanceMode == value) return;
    _appearanceMode = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setStylePreset(MapStylePreset value) async {
    if (!_initialized) await initialize();
    if (_stylePreset == value) return;
    _stylePreset = value;
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final file = _file!;
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      jsonEncode(<String, Object?>{
        'version': 10,
        'provider': _provider.name,
        'orientationMode': _orientationMode.name,
        'followViewPreset': _followViewPreset.name,
        'stylePreset': _stylePreset.name,
        'appearancePreset': _appearancePreset.name,
        'appearanceMode': _appearanceMode.name,
        'lastTravelMode': _lastTravelMode.storageValue,
        'bikeAverageSpeedKmh': _bikeAverageSpeedKmh,
        'bikeRidingHoursPerDay': _bikeRidingHoursPerDay,
        'bikeBalanceDays': _bikeBalanceDays,
        'bikeUseHistoricalSpeed': _bikeUseHistoricalSpeed,
        'navigationVoiceEnabled': _navigationVoiceEnabled,
        'weatherVoiceEnabled': _weatherVoiceEnabled,
      }),
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
  }
}
