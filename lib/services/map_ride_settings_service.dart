import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Preferências locais do painel de pilotagem e dos alertas de velocidade.
class MapRideSettingsService extends ChangeNotifier {
  MapRideSettingsService._();
  static final MapRideSettingsService instance = MapRideSettingsService._();

  File? _file;
  Future<void> _writeTail = Future<void>.value();
  bool _initialized = false;
  int focusLevel = 0;
  bool immersive = true;
  bool speedAlertsEnabled = false;
  bool speedAlertVoice = true;
  bool speedAlertVibration = true;
  List<int> speedLimitsKmh = <int>[20, 25, 30];
  String radioName = '';
  String radioUrl = '';
  List<Map<String, String>> stations = <Map<String, String>>[];
  bool roadOverlayEnabled = false;

  Future<void> initialize() async {
    if (_initialized) return;
    final root = await getApplicationSupportDirectory();
    _file = File('${root.path}${Platform.pathSeparator}map_ride_settings.json');
    try {
      final file = _file!;
      if (await file.exists()) {
        final raw = jsonDecode(await file.readAsString());
        if (raw is Map) {
          focusLevel = ((raw['focusLevel'] as num?)?.toInt() ?? 0).clamp(0, 2).toInt();
          immersive = raw['immersive'] as bool? ?? true;
          speedAlertsEnabled = raw['speedAlertsEnabled'] as bool? ?? false;
          speedAlertVoice = raw['speedAlertVoice'] as bool? ?? true;
          speedAlertVibration = raw['speedAlertVibration'] as bool? ?? true;
          speedLimitsKmh = ((raw['speedLimitsKmh'] as List?) ?? <int>[20, 25, 30])
              .whereType<num>().map((value) => value.toInt())
              .where((value) => value >= 5 && value <= 120)
              .toSet().toList()..sort();
          radioName = raw['radioName'] as String? ?? '';
          radioUrl = raw['radioUrl'] as String? ?? '';
          stations = ((raw['stations'] as List?) ?? const <Object>[])
              .whereType<Map>()
              .map((entry) => <String, String>{
                    'name': entry['name']?.toString() ?? '',
                    'url': entry['url']?.toString() ?? '',
                  })
              .where((entry) => entry['url']!.isNotEmpty)
              .toList();
          roadOverlayEnabled = raw['roadOverlayEnabled'] as bool? ?? false;
        }
      }
    } catch (_) {
      // O mapa continua com padrões seguros se a preferência estiver corrompida.
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> update({int? focus, bool? fullscreen, bool? alerts,
      bool? voice, bool? vibration, List<int>? limits,
      String? stationName, String? stationUrl, bool? roads,
      List<Map<String, String>>? savedStations}) async {
    if (focus != null) focusLevel = focus.clamp(0, 2).toInt();
    if (fullscreen != null) immersive = fullscreen;
    if (alerts != null) speedAlertsEnabled = alerts;
    if (voice != null) speedAlertVoice = voice;
    if (vibration != null) speedAlertVibration = vibration;
    if (limits != null) speedLimitsKmh = limits.toSet().toList()..sort();
    if (stationName != null) radioName = stationName.trim();
    if (stationUrl != null) radioUrl = stationUrl.trim();
    if (savedStations != null) stations = savedStations;
    if (roads != null) roadOverlayEnabled = roads;
    notifyListeners();
    final file = _file;
    if (file == null) return;
    final snapshot = jsonEncode(<String, Object?>{
      'schema': 1,
      'focusLevel': focusLevel,
      'immersive': immersive,
      'speedAlertsEnabled': speedAlertsEnabled,
      'speedAlertVoice': speedAlertVoice,
      'speedAlertVibration': speedAlertVibration,
      'speedLimitsKmh': speedLimitsKmh,
      'radioName': radioName,
      'radioUrl': radioUrl,
      'stations': stations,
      'roadOverlayEnabled': roadOverlayEnabled,
    });
    _writeTail = _writeTail.catchError((Object _) {}).then((_) async {
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(snapshot, flush: true);
      if (await file.exists()) await file.delete();
      await temp.rename(file.path);
    });
    await _writeTail;
  }
}
