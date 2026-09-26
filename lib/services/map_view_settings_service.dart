import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/map_travel_mode.dart';
import 'map_view_policy.dart';

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

  MapOrientationMode _orientationMode = MapOrientationMode.northUp;
  MapFollowViewPreset _followViewPreset = MapFollowViewPreset.near;
  MapStylePreset _stylePreset = MapStylePreset.standard;
  MapTravelMode _lastTravelMode = MapTravelMode.bicycle;
  bool _navigationVoiceEnabled = true;
  bool _initialized = false;
  File? _file;

  bool get initialized => _initialized;
  MapOrientationMode get orientationMode => _orientationMode;
  MapFollowViewPreset get followViewPreset => _followViewPreset;
  MapStylePreset get stylePreset => _stylePreset;
  MapTravelMode get lastTravelMode => _lastTravelMode;
  bool get navigationVoiceEnabled => _navigationVoiceEnabled;

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
          final orientationName = map['orientationMode'] as String?;
          final presetName = map['followViewPreset'] as String?;
          final styleName = map['stylePreset'] as String?;
          final lastTravelMode = map['lastTravelMode'];
          final navigationVoiceEnabled = map['navigationVoiceEnabled'];
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
          _lastTravelMode = MapTravelModeX.fromStorage(lastTravelMode);
          _navigationVoiceEnabled = navigationVoiceEnabled as bool? ?? true;
        }
      } catch (_) {
        _orientationMode = MapOrientationMode.northUp;
        _followViewPreset = MapFollowViewPreset.near;
        _stylePreset = MapStylePreset.standard;
        _lastTravelMode = MapTravelMode.bicycle;
        _navigationVoiceEnabled = true;
      }
    }
    _initialized = true;
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

  Future<void> setNavigationVoiceEnabled(bool value) async {
    if (!_initialized) await initialize();
    if (_navigationVoiceEnabled == value) return;
    _navigationVoiceEnabled = value;
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
        'version': 5,
        'orientationMode': _orientationMode.name,
        'followViewPreset': _followViewPreset.name,
        'stylePreset': _stylePreset.name,
        'lastTravelMode': _lastTravelMode.storageValue,
        'navigationVoiceEnabled': _navigationVoiceEnabled,
      }),
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
  }
}
