import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'radio_browser_service.dart';

/// Histórico local, sem conta nem telemetria. Só registra stream confirmado.
class RadioRecentEntry {
  const RadioRecentEntry(this.station, this.playedAt);
  final RadioBrowserStation station;
  final DateTime playedAt;
}

class RadioRecentHistory {
  factory RadioRecentHistory({File? file}) => RadioRecentHistory._(file);

  RadioRecentHistory._(this._file);
  static const int maximumEntries = 20;
  File? _file;

  Future<File> _resolve() async {
    if (_file != null) { return _file!; }
    final dir = await getApplicationSupportDirectory();
    _file = File('${dir.path}${Platform.pathSeparator}radio_recent_history.json');
    return _file!;
  }

  Future<List<RadioRecentEntry>> load() async {
    try {
      final file = await _resolve();
      if (!await file.exists()) { return const <RadioRecentEntry>[]; }
      final raw = jsonDecode(await file.readAsString());
      if (raw is! List) { return const <RadioRecentEntry>[]; }
      final entries = <RadioRecentEntry>[];
      final seen = <String>{};
      for (final item in raw) {
        if (item is! Map) { continue; }
        final map = item['station'];
        if (map is! Map) { continue; }
        final station = RadioBrowserStation.fromSavedMap(<String, String>{
          for (final field in map.entries)
            field.key.toString(): field.value?.toString() ?? '',
        });
        final uri = Uri.tryParse(station.streamUrl);
        if (uri == null || uri.host.isEmpty ||
            !<String>{'https', 'http'}.contains(uri.scheme) ||
            !seen.add(station.streamUrl)) { continue; }
        final at = DateTime.tryParse(item['playedAt']?.toString() ?? '');
        if (at == null) { continue; }
        entries.add(RadioRecentEntry(station, at));
        if (entries.length >= maximumEntries) { break; }
      }
      return entries;
    } catch (_) {
      return const <RadioRecentEntry>[];
    }
  }

  Future<List<RadioRecentEntry>> record(RadioBrowserStation station) async {
    if (station.streamUrl.isEmpty) { return load(); }
    final existing = await load();
    final updated = <RadioRecentEntry>[
      RadioRecentEntry(station, DateTime.now().toUtc()),
      ...existing.where((e) => e.station.streamUrl != station.streamUrl),
    ].take(maximumEntries).toList(growable: false);
    await _write(updated);
    return updated;
  }

  Future<List<RadioRecentEntry>> remove(String url) async {
    final updated = (await load())
        .where((e) => e.station.streamUrl != url).toList(growable: false);
    await _write(updated);
    return updated;
  }

  Future<void> clear() async => _write(const <RadioRecentEntry>[]);

  Future<void> _write(List<RadioRecentEntry> entries) async {
    try {
      final file = await _resolve();
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(jsonEncode([
        for (final e in entries) {
          'station': e.station.toSavedMap(),
          'playedAt': e.playedAt.toUtc().toIso8601String(),
        },
      ]), flush: true);
      if (await file.exists()) { await file.delete(); }
      await tmp.rename(file.path);
    } catch (_) {
      // O áudio não deve falhar se o armazenamento de histórico estiver cheio.
    }
  }
}
