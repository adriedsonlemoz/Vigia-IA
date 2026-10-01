import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Memória local (persistida) de streams que falharam, usada para marcar
/// estações instáveis e deixá-las no fim das listas.
class RadioHealthService {
  RadioHealthService({File? file}) : _file = file;

  static final RadioHealthService instance = RadioHealthService();

  /// Quantidade de falhas seguidas a partir da qual a estação é considerada instável.
  static const int suspectThreshold = 2;
  static const int _maxEntries = 300;

  File? _file;
  final Map<String, int> _failures = <String, int>{};
  Future<void>? _loading;

  int failuresFor(String url) => _failures[url.trim()] ?? 0;

  bool isSuspect(String url) => failuresFor(url) >= suspectThreshold;

  Future<void> load() => _loading ??= _loadInternal();

  Future<void> _loadInternal() async {
    try {
      final file = await _resolveFile();
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final value = entry.value;
            final count = value is num ? value.toInt() : 0;
            if (count > 0) _failures[entry.key.toString()] = count;
          }
        }
      }
    } catch (_) {
      // Sem armazenamento disponível: a memória vale apenas nesta sessão.
    }
  }

  Future<void> markFailed(String url) async {
    final key = url.trim();
    if (key.isEmpty) return;
    await load();
    _failures[key] = (_failures[key] ?? 0) + 1;
    await _persist();
  }

  Future<void> markWorking(String url) async {
    final key = url.trim();
    if (key.isEmpty) return;
    await load();
    if (_failures.remove(key) != null) await _persist();
  }

  Future<void> _persist() async {
    try {
      if (_failures.length > _maxEntries) {
        final oldest =
            _failures.keys.take(_failures.length - _maxEntries).toList();
        oldest.forEach(_failures.remove);
      }
      final file = await _resolveFile();
      await file.writeAsString(jsonEncode(_failures));
    } catch (_) {
      // Melhor esforço: falha ao gravar não afeta a reprodução.
    }
  }

  Future<File> _resolveFile() async {
    final existing = _file;
    if (existing != null) return existing;
    final root = await getApplicationSupportDirectory();
    final created =
        File('${root.path}${Platform.pathSeparator}radio_health.json');
    _file = created;
    return created;
  }
}
