import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_map_mbtiles/flutter_map_mbtiles.dart';
import 'package:path_provider/path_provider.dart';

import '../models/offline_map_package.dart';

class OfflineMapService extends ChangeNotifier {
  OfflineMapService._();

  static final OfflineMapService instance = OfflineMapService._();

  final List<OfflineMapPackage> _packages = <OfflineMapPackage>[];
  Directory? _directory;
  File? _manifest;
  bool _initialized = false;
  bool _busy = false;
  double? _progress;
  String? _operationLabel;
  String? _activeId;
  OfflineMapMode _mode = OfflineMapMode.automatic;

  List<OfflineMapPackage> get packages =>
      List<OfflineMapPackage>.unmodifiable(_packages);
  bool get busy => _busy;
  double? get progress => _progress;
  String? get operationLabel => _operationLabel;
  String? get activeId => _activeId;
  OfflineMapMode get mode => _mode;

  OfflineMapPackage? get activePackage {
    final id = _activeId;
    if (id == null) return null;
    for (final item in _packages) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    final root = await getApplicationSupportDirectory();
    _directory = Directory(
      '${root.path}${Platform.pathSeparator}offline_maps',
    );
    await _directory!.create(recursive: true);
    _manifest = File(
      '${_directory!.path}${Platform.pathSeparator}offline_maps.json',
    );

    if (await _manifest!.exists()) {
      try {
        final decoded = jsonDecode(await _manifest!.readAsString());
        if (decoded is Map) {
          _activeId = decoded['activeId'] as String?;
          final modeName = decoded['mode'] as String?;
          _mode = OfflineMapMode.values.firstWhere(
            (value) => value.name == modeName,
            orElse: () => OfflineMapMode.automatic,
          );
          final rawItems = decoded['packages'];
          if (rawItems is List) {
            for (final raw in rawItems.whereType<Map>()) {
              final item = OfflineMapPackage.fromJson(
                Map<String, dynamic>.from(raw),
              );
              if (item.id.isNotEmpty &&
                  item.path.isNotEmpty &&
                  await File(item.path).exists()) {
                _packages.add(item);
              }
            }
          }
        }
      } catch (_) {
        _packages.clear();
        _activeId = null;
        _mode = OfflineMapMode.automatic;
      }
    }

    if (_activeId != null && activePackage == null) {
      _activeId = _packages.isEmpty ? null : _packages.first.id;
    }
    if (_mode == OfflineMapMode.offline && activePackage == null) {
      _mode = OfflineMapMode.automatic;
    }
    _packages.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    _initialized = true;
    await _persist();
    notifyListeners();
  }

  Future<OfflineMapPackage> downloadPackage({
    required Uri uri,
    String? displayName,
  }) async {
    await initialize();
    if (_busy) throw StateError('Já existe um mapa sendo processado.');
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw const FormatException('Use um link HTTP ou HTTPS válido.');
    }
    if (uri.host.isEmpty) {
      throw const FormatException('O endereço do pacote não possui servidor.');
    }

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final name = _normalizedDisplayName(
      displayName,
      fallback: _nameFromUri(uri),
    );
    final safeName = _safeFileName(name);
    final target = File(
      '${_directory!.path}${Platform.pathSeparator}${safeName}_$id.mbtiles',
    );
    final temporary = File('${target.path}.part');

    _setOperation('Baixando $name', progress: 0);
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..idleTimeout = const Duration(seconds: 30);
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, 'VigiaIA/1.0 offline-map');
      final response = await request.close().timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Servidor respondeu HTTP ${response.statusCode}.',
          uri: uri,
        );
      }

      final total = response.contentLength > 0 ? response.contentLength : null;
      var received = 0;
      final sink = temporary.openWrite();
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          _progress = total == null
              ? null
              : (received / total).clamp(0.0, 1.0).toDouble();
          notifyListeners();
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      await _validateMbTiles(temporary);
      if (await target.exists()) await target.delete();
      await temporary.rename(target.path);
      final size = await target.length();
      final item = OfflineMapPackage(
        id: id,
        name: name,
        path: target.path,
        sizeBytes: size,
        addedAt: DateTime.now(),
        sourceHost: uri.host,
      );
      _packages.insert(0, item);
      _activeId = item.id;
      _mode = OfflineMapMode.automatic;
      await _persist();
      return item;
    } catch (_) {
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    } finally {
      client.close(force: true);
      _clearOperation();
    }
  }

  Future<OfflineMapPackage> importPackage({
    required String sourcePath,
    String? displayName,
  }) async {
    await initialize();
    if (_busy) throw StateError('Já existe um mapa sendo processado.');
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('Arquivo MBTiles não encontrado.');
    }
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final rawName = displayName?.trim() ?? '';
    final withoutExtension = rawName.toLowerCase().endsWith('.mbtiles')
        ? rawName.substring(0, rawName.length - '.mbtiles'.length)
        : rawName;
    final name = _normalizedDisplayName(
      withoutExtension,
      fallback: 'Mapa offline',
    );
    final target = File(
      '${_directory!.path}${Platform.pathSeparator}${_safeFileName(name)}_$id.mbtiles',
    );
    final temporary = File('${target.path}.part');
    _setOperation('Importando $name', progress: null);
    try {
      await source.copy(temporary.path);
      await _validateMbTiles(temporary);
      if (await target.exists()) await target.delete();
      await temporary.rename(target.path);
      final item = OfflineMapPackage(
        id: id,
        name: name,
        path: target.path,
        sizeBytes: await target.length(),
        addedAt: DateTime.now(),
        sourceHost: 'arquivo local',
      );
      _packages.insert(0, item);
      _activeId = item.id;
      _mode = OfflineMapMode.automatic;
      await _persist();
      return item;
    } finally {
      if (await temporary.exists()) await temporary.delete();
      try {
        if (source.path.contains('offline_map_import_') && await source.exists()) {
          await source.delete();
        }
      } catch (_) {}
      _clearOperation();
    }
  }

  Future<void> setActive(String id) async {
    await initialize();
    if (!_packages.any((item) => item.id == id)) return;
    _activeId = id;
    await _persist();
    notifyListeners();
  }

  Future<void> setMode(OfflineMapMode value) async {
    await initialize();
    if (value == OfflineMapMode.offline && activePackage == null) {
      throw StateError('Baixe um pacote MBTiles antes de ativar o modo offline.');
    }
    _mode = value;
    await _persist();
    notifyListeners();
  }

  Future<void> deletePackage(String id) async {
    await initialize();
    final index = _packages.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final item = _packages.removeAt(index);
    try {
      final file = File(item.path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // O registro ainda deve ser removido mesmo se o SO já tiver apagado o arquivo.
    }
    if (_activeId == id) {
      _activeId = _packages.isEmpty ? null : _packages.first.id;
    }
    if (_mode == OfflineMapMode.offline && activePackage == null) {
      _mode = OfflineMapMode.automatic;
    }
    await _persist();
    notifyListeners();
  }

  Future<void> _validateMbTiles(File file) async {
    if (!await file.exists() || await file.length() < 4096) {
      throw const FormatException(
        'O arquivo recebido não parece ser um MBTiles válido.',
      );
    }
    final handle = await file.open();
    try {
      final header = await handle.read(16);
      final signature = ascii.decode(header, allowInvalid: true);
      if (!signature.startsWith('SQLite format 3')) {
        throw const FormatException(
          'O download não é um banco MBTiles/SQLite válido.',
        );
      }
    } finally {
      await handle.close();
    }

    MbTilesTileProvider? provider;
    try {
      provider = MbTilesTileProvider.fromPath(path: file.path);
      final metadata = provider.mbtiles.getMetadata();
      final format = metadata.format.trim().toLowerCase();
      const rasterFormats = <String>{'png', 'jpg', 'jpeg', 'webp'};
      if (!rasterFormats.contains(format)) {
        throw FormatException(
          'Este pacote usa formato “${metadata.format}”. '
          'Nesta versão, use MBTiles raster PNG/JPG/WebP.',
        );
      }
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'O arquivo SQLite não possui uma estrutura MBTiles raster válida.',
      );
    } finally {
      provider?.dispose();
    }
  }

  String _nameFromUri(Uri uri) {
    final last = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    final decoded = Uri.decodeComponent(last);
    final withoutExtension = decoded.toLowerCase().endsWith('.mbtiles')
        ? decoded.substring(0, decoded.length - '.mbtiles'.length)
        : decoded;
    return withoutExtension.trim().isEmpty ? 'Mapa offline' : withoutExtension;
  }

  String _normalizedDisplayName(String? value, {required String fallback}) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? fallback : trimmed;
  }

  String _safeFileName(String value) {
    final cleaned = value
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return cleaned.isEmpty ? 'mapa_offline' : cleaned;
  }

  void _setOperation(String label, {double? progress}) {
    _busy = true;
    _operationLabel = label;
    _progress = progress;
    notifyListeners();
  }

  void _clearOperation() {
    _busy = false;
    _operationLabel = null;
    _progress = null;
    notifyListeners();
  }

  Future<void> _persist() async {
    if (_manifest == null) return;
    final payload = <String, Object?>{
      'activeId': _activeId,
      'mode': _mode.name,
      'packages': _packages.map((item) => item.toJson()).toList(growable: false),
    };
    await _manifest!.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
  }
}
