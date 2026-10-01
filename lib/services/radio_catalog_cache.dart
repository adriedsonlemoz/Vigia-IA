import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'radio_browser_service.dart';

/// Guarda as últimas buscas do catálogo para que o painel continue útil sem
/// conexão ou quando os servidores do Radio Browser estiverem fora do ar.
class RadioCatalogCache {
  RadioCatalogCache({File? file}) : _file = file;

  static const int _maxEntries = 8;
  static const int _maxStationsPerEntry = 60;
  static const Duration maxAge = Duration(days: 14);

  File? _file;

  static String keyFor({required String query, required bool brazilOnly}) =>
      '${brazilOnly ? 'br' : 'world'}|${query.trim().toLowerCase()}';

  Future<void> save(String key, List<RadioBrowserStation> stations) async {
    if (stations.isEmpty) return;
    try {
      final file = await _resolveFile();
      final entries = await _readEntries(file);
      entries.remove(key);
      entries[key] = <String, Object?>{
        'savedAt': DateTime.now().toUtc().toIso8601String(),
        'stations': stations
            .take(_maxStationsPerEntry)
            .map((station) => station.toSavedMap())
            .toList(),
      };
      while (entries.length > _maxEntries) {
        entries.remove(entries.keys.first);
      }
      await file.writeAsString(jsonEncode(entries));
    } catch (_) {
      // Melhor esforço: o cache é opcional.
    }
  }

  Future<List<RadioBrowserStation>?> load(String key) async {
    try {
      final file = await _resolveFile();
      final entries = await _readEntries(file);
      final entry = entries[key];
      if (entry is! Map) return null;
      final savedAt = DateTime.tryParse('${entry['savedAt']}');
      if (savedAt != null &&
          DateTime.now().toUtc().difference(savedAt) > maxAge) {
        return null;
      }
      final raw = entry['stations'];
      if (raw is! List) return null;
      final stations = <RadioBrowserStation>[];
      for (final item in raw) {
        if (item is! Map) continue;
        final map = <String, String>{
          for (final field in item.entries)
            field.key.toString(): field.value?.toString() ?? '',
        };
        final station = RadioBrowserStation.fromSavedMap(map);
        if (station.streamUrl.isNotEmpty) stations.add(station);
      }
      return stations.isEmpty ? null : stations;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, Object?>> _readEntries(File file) async {
    if (!await file.exists()) return <String, Object?>{};
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) return <String, Object?>{};
    return <String, Object?>{
      for (final entry in decoded.entries) entry.key.toString(): entry.value,
    };
  }

  Future<File> _resolveFile() async {
    final existing = _file;
    if (existing != null) return existing;
    final root = await getApplicationSupportDirectory();
    final created =
        File('${root.path}${Platform.pathSeparator}radio_catalog_cache.json');
    _file = created;
    return created;
  }
}
