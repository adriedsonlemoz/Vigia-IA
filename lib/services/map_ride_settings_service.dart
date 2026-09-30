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
  double radioVolume = 0.8;
  int radioBitrateKbps = 0;
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
          radioVolume = ((raw['radioVolume'] as num?)?.toDouble() ?? 0.8)
              .clamp(0.0, 1.0)
              .toDouble();
          radioBitrateKbps =
              ((raw['radioBitrateKbps'] as num?)?.toInt() ?? 0)
                  .clamp(0, 1024)
                  .toInt();
          stations = ((raw['stations'] as List?) ?? const <Object>[])
              .whereType<Map>()
              .map((entry) => <String, String>{
                    for (final key in <String>[
                      'id', 'name', 'url', 'favicon', 'country', 'state',
                      'language', 'tags', 'codec', 'bitrate',
                    ])
                      key: entry[key]?.toString() ?? '',
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
      double? radioVolume, int? radioBitrateKbps,
      List<Map<String, String>>? savedStations}) async {
    if (focus != null) focusLevel = focus.clamp(0, 2).toInt();
    if (fullscreen != null) immersive = fullscreen;
    if (alerts != null) speedAlertsEnabled = alerts;
    if (voice != null) speedAlertVoice = voice;
    if (vibration != null) speedAlertVibration = vibration;
    if (limits != null) speedLimitsKmh = limits.toSet().toList()..sort();
    if (stationName != null) radioName = stationName.trim();
    if (stationUrl != null) radioUrl = stationUrl.trim();
    if (radioVolume != null) {
      this.radioVolume = radioVolume.clamp(0.0, 1.0).toDouble();
    }
    if (radioBitrateKbps != null) {
      this.radioBitrateKbps = radioBitrateKbps.clamp(0, 1024).toInt();
    }
    if (savedStations != null) stations = savedStations;
    if (roads != null) roadOverlayEnabled = roads;
    notifyListeners();
    final file = _file;
    if (file == null) return;
    final snapshot = jsonEncode(<String, Object?>{
      'schema': 2,
      'focusLevel': focusLevel,
      'immersive': immersive,
      'speedAlertsEnabled': speedAlertsEnabled,
      'speedAlertVoice': speedAlertVoice,
      'speedAlertVibration': speedAlertVibration,
      'speedLimitsKmh': speedLimitsKmh,
      'radioName': radioName,
      'radioUrl': radioUrl,
      'radioVolume': this.radioVolume,
      'radioBitrateKbps': this.radioBitrateKbps,
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
