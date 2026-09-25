import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'map_view_policy.dart';

class MapViewSettingsService extends ChangeNotifier {
  MapViewSettingsService._();

  static final MapViewSettingsService instance = MapViewSettingsService._();

  MapOrientationMode _orientationMode = MapOrientationMode.northUp;
  MapFollowViewPreset _followViewPreset = MapFollowViewPreset.near;
  bool _initialized = false;
  File? _file;

  bool get initialized => _initialized;
  MapOrientationMode get orientationMode => _orientationMode;
  MapFollowViewPreset get followViewPreset => _followViewPreset;

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
          _orientationMode = MapOrientationMode.values.firstWhere(
            (value) => value.name == orientationName,
            orElse: () => MapOrientationMode.northUp,
          );
          _followViewPreset = MapFollowViewPreset.values.firstWhere(
            (value) => value.name == presetName,
            orElse: () => MapFollowViewPreset.near,
          );
        }
      } catch (_) {
        _orientationMode = MapOrientationMode.northUp;
        _followViewPreset = MapFollowViewPreset.near;
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

  Future<void> _persist() async {
    final file = _file!;
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      jsonEncode(<String, Object?>{
        'version': 1,
        'orientationMode': _orientationMode.name,
        'followViewPreset': _followViewPreset.name,
      }),
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
  }
}
