import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_map_mbtiles/flutter_map_mbtiles.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../models/offline_map_package.dart';
import 'native_platform_service.dart';

class OfflineMapDownloadEstimate {
  const OfflineMapDownloadEstimate({required this.tiles, required this.bytes});

  final int tiles;
  final int bytes;

  /// Stadia Maps cobra 1 crédito por tile raster padrão.
  int get credits => tiles * OfflineMapService.stadiaRasterCreditsPerTile;
}

class OfflineMapBounds {
  const OfflineMapBounds({
    required this.west,
    required this.south,
    required this.east,
    required this.north,
  });

  final double west;
  final double south;
  final double east;
  final double north;
}

class OfflineMapService extends ChangeNotifier {
  OfflineMapService._();

  static final OfflineMapService instance = OfflineMapService._();

  static const int stadiaCacheLimitBytes = 100 * 1024 * 1024;
  static const int _stadiaSafeLimitBytes = 95 * 1024 * 1024;
  static const int estimatedRasterTileBytes = 24 * 1024;
  static const int stadiaRasterCreditsPerTile = 1;
  static const int stadiaFreePlanReferenceCredits = 200000;
  static const int _defaultStadiaMonthlyCreditLimit = 150000;
  static const String _stadiaProviderId = 'stadia-alidade-smooth';
  final List<OfflineMapPackage> _packages = <OfflineMapPackage>[];
  final NativePlatformService _native = NativePlatformService.instance;
  Directory? _directory;
  File? _manifest;
  bool _initialized = false;
  bool _busy = false;
  double? _progress;
  String? _operationLabel;
  String? _activeId;
  OfflineMapMode _mode = OfflineMapMode.automatic;
  String? _stadiaApiKeyProtected;
  String? _stadiaApiKey;
  int _downloadBytes = 0;
  int _downloadTilesCompleted = 0;
  int _downloadTilesTotal = 0;
  bool _downloadPaused = false;
  bool _cancelRequested = false;
  Completer<void>? _resumeCompleter;
  String _stadiaCreditMonth = _creditMonthKey(DateTime.now());
  int _stadiaCreditsUsedThisMonth = 0;
  int _stadiaMonthlyCreditLimit = _defaultStadiaMonthlyCreditLimit;

  List<OfflineMapPackage> get packages =>
      List<OfflineMapPackage>.unmodifiable(_packages);
  bool get busy => _busy;
  double? get progress => _progress;
  String? get operationLabel => _operationLabel;
  String? get activeId => _activeId;
  OfflineMapMode get mode => _mode;
  int get downloadBytes => _downloadBytes;
  int get downloadTilesCompleted => _downloadTilesCompleted;
  int get downloadTilesTotal => _downloadTilesTotal;
  bool get downloadPaused => _downloadPaused;
  bool get canPauseDownload => _busy && _downloadTilesTotal > 0;
  bool get hasStadiaApiKey => _stadiaApiKey?.trim().isNotEmpty ?? false;
  int get stadiaCreditsUsedThisMonth => _stadiaCreditsUsedThisMonth;
  int get stadiaMonthlyCreditLimit => _stadiaMonthlyCreditLimit;
  int get stadiaCreditsRemainingThisMonth =>
      math.max(0, _stadiaMonthlyCreditLimit - _stadiaCreditsUsedThisMonth);
  double get stadiaMonthlyCreditUsageFraction => _stadiaMonthlyCreditLimit <= 0
      ? 1.0
      : (_stadiaCreditsUsedThisMonth / _stadiaMonthlyCreditLimit)
          .clamp(0.0, 1.0)
          .toDouble();

  int get stadiaCachedBytes => _packages
      .where((item) => item.providerId == _stadiaProviderId)
      .fold<int>(0, (total, item) => total + item.sizeBytes);

  int get stadiaAvailableCacheBytes =>
      math.max(0, stadiaCacheLimitBytes - stadiaCachedBytes);

  int get stadiaSafeAvailableCacheBytes =>
      math.max(0, _stadiaSafeLimitBytes - stadiaCachedBytes);

  OfflineMapPackage? get activePackage {
    final id = _activeId;
    if (id == null) return null;
    for (final item in _packages) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<void> initialize() async {
    if (_initialized) {
      if (_resetCreditWindowIfNeeded()) {
        await _persist();
        notifyListeners();
      }
      return;
    }
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
          _stadiaApiKeyProtected = decoded['stadiaApiKeyProtected'] as String?;
          _stadiaCreditMonth =
              decoded['stadiaCreditMonth'] as String? ?? _stadiaCreditMonth;
          _stadiaCreditsUsedThisMonth =
              (decoded['stadiaCreditsUsedThisMonth'] as num?)?.toInt() ?? 0;
          _stadiaMonthlyCreditLimit =
              ((decoded['stadiaMonthlyCreditLimit'] as num?)?.toInt() ??
                      _defaultStadiaMonthlyCreditLimit)
                  .clamp(1000, 10000000)
                  .toInt();
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

    _resetCreditWindowIfNeeded();

    if (_stadiaApiKeyProtected != null) {
      _stadiaApiKey = await _native.unprotectSecret(_stadiaApiKeyProtected);
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

  Future<void> configureStadiaApiKey(String value) async {
    await initialize();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      _stadiaApiKey = null;
      _stadiaApiKeyProtected = null;
    } else {
      _stadiaApiKeyProtected = await _native.protectSecret(trimmed);
      _stadiaApiKey = trimmed;
    }
    await _persist();
    notifyListeners();
  }

  Future<void> configureStadiaMonthlyCreditLimit(int credits) async {
    await initialize();
    _resetCreditWindowIfNeeded();
    _stadiaMonthlyCreditLimit = credits.clamp(1000, 10000000).toInt();
    await _persist();
    notifyListeners();
  }

  static int creditsForRasterTiles(int tiles) =>
      tiles <= 0 ? 0 : tiles * stadiaRasterCreditsPerTile;

  OfflineMapDownloadEstimate estimateBounds({
    required OfflineMapBounds bounds,
    int minZoom = 8,
    int maxZoom = 16,
  }) {
    final tiles = _tilesForBounds(bounds, minZoom: minZoom, maxZoom: maxZoom).length;
    return OfflineMapDownloadEstimate(
      tiles: tiles,
      bytes: tiles * estimatedRasterTileBytes,
    );
  }

  OfflineMapDownloadEstimate estimateRoute({
    required List<LatLng> route,
    double bufferKm = 2,
    int minZoom = 8,
    int maxZoom = 16,
  }) {
    final tiles = _tilesForRoute(
      route,
      bufferKm: bufferKm,
      minZoom: minZoom,
      maxZoom: maxZoom,
    ).length;
    return OfflineMapDownloadEstimate(
      tiles: tiles,
      bytes: tiles * estimatedRasterTileBytes,
    );
  }

  Future<OfflineMapPackage> downloadStadiaRegion({
    required String displayName,
    required OfflineMapBounds bounds,
    int minZoom = 8,
    int maxZoom = 16,
  }) async {
    final tiles = _tilesForBounds(bounds, minZoom: minZoom, maxZoom: maxZoom);
    return _downloadStadiaTiles(
      displayName: displayName,
      tiles: tiles,
      bounds: bounds,
      minZoom: minZoom,
      maxZoom: maxZoom,
      downloadKind: 'region',
    );
  }

  Future<OfflineMapPackage> downloadStadiaRoute({
    required String displayName,
    required List<LatLng> route,
    double bufferKm = 2,
    int minZoom = 8,
    int maxZoom = 16,
  }) async {
    if (route.length < 2) {
      throw StateError('Registre um trajeto com pelo menos dois pontos.');
    }
    final tiles = _tilesForRoute(
      route,
      bufferKm: bufferKm,
      minZoom: minZoom,
      maxZoom: maxZoom,
    );
    return _downloadStadiaTiles(
      displayName: displayName,
      tiles: tiles,
      bounds: _routeBounds(route, marginKm: bufferKm),
      minZoom: minZoom,
      maxZoom: maxZoom,
      downloadKind: 'route',
    );
  }

  Future<OfflineMapPackage> _downloadStadiaTiles({
    required String displayName,
    required List<_TileCoordinate> tiles,
    required OfflineMapBounds bounds,
    required int minZoom,
    required int maxZoom,
    required String downloadKind,
  }) async {
    await initialize();
    final monthChanged = _resetCreditWindowIfNeeded();
    if (monthChanged) await _persist();
    if (_busy) throw StateError('Já existe um mapa sendo processado.');
    final apiKey = _stadiaApiKey?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError(
        'Configure uma chave da Stadia Maps antes do download direto.',
      );
    }
    if (tiles.isEmpty) throw StateError('A área selecionada não possui tiles.');
    final existingCacheBytes = stadiaCachedBytes;
    final safeRemainingBytes = math.max(0, _stadiaSafeLimitBytes - existingCacheBytes);
    final estimated = tiles.length * estimatedRasterTileBytes;
    if (estimated > safeRemainingBytes) {
      throw StateError(
        'A área estimada ultrapassa o espaço seguro restante do cache offline. '
        'Exclua outro mapa direto ou reduza a região/zoom.',
      );
    }
    final estimatedCredits = creditsForRasterTiles(tiles.length);
    if (estimatedCredits > stadiaCreditsRemainingThisMonth) {
      throw StateError(
        'Este download usaria aproximadamente $estimatedCredits créditos e '
        'ultrapassaria o limite mensal local configurado. '
        'Aumente o limite apenas se sua conta permitir ou reduza a área/zoom.',
      );
    }

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final name = _normalizedDisplayName(displayName, fallback: 'Mapa offline');
    final target = File(
      '${_directory!.path}${Platform.pathSeparator}${_safeFileName(name)}_$id.mbtiles',
    );
    final temporary = File('${target.path}.part');
    if (await temporary.exists()) await temporary.delete();

    _downloadBytes = 0;
    _downloadTilesCompleted = 0;
    _downloadTilesTotal = tiles.length;
    _downloadPaused = false;
    _cancelRequested = false;
    _setOperation('Baixando $name', progress: 0);

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..idleTimeout = const Duration(seconds: 30);
    Database? db;
    PreparedStatement? insertTile;
    DateTime? earliestExpiry;
    try {
      db = sqlite3.open(temporary.path);
      db.execute('PRAGMA journal_mode=OFF;');
      db.execute('PRAGMA synchronous=OFF;');
      db.execute(
        'CREATE TABLE metadata (name TEXT PRIMARY KEY, value TEXT)',
      );
      db.execute('''
        CREATE TABLE tiles (
          zoom_level INTEGER NOT NULL,
          tile_column INTEGER NOT NULL,
          tile_row INTEGER NOT NULL,
          tile_data BLOB NOT NULL,
          UNIQUE (zoom_level, tile_column, tile_row)
        )
      ''');
      db.execute(
        'CREATE UNIQUE INDEX tile_index '
        'ON tiles (zoom_level, tile_column, tile_row)',
      );
      final metadata = <String, String>{
        'name': name,
        'type': 'baselayer',
        'version': '1.0',
        'description': 'Mapa offline criado pelo Vigia IA',
        'format': 'png',
        'bounds': '${bounds.west},${bounds.south},${bounds.east},${bounds.north}',
        'minzoom': '$minZoom',
        'maxzoom': '$maxZoom',
        'attribution': '© Stadia Maps © OpenMapTiles © OpenStreetMap',
      };
      final insertMetadata = db.prepare(
        'INSERT OR REPLACE INTO metadata(name, value) VALUES (?, ?)',
      );
      try {
        for (final entry in metadata.entries) {
          insertMetadata.execute(<Object?>[entry.key, entry.value]);
        }
      } finally {
        insertMetadata.dispose();
      }
      insertTile = db.prepare(
        'INSERT OR REPLACE INTO tiles('
        'zoom_level, tile_column, tile_row, tile_data) VALUES (?, ?, ?, ?)',
      );

      const batchSize = 4;
      for (var offset = 0; offset < tiles.length; offset += batchSize) {
        await _waitIfPausedOrCancelled();
        final end = math.min(offset + batchSize, tiles.length);
        final batch = tiles.sublist(offset, end);
        final downloaded = await Future.wait(
          batch.map((tile) => _fetchStadiaTile(client, apiKey, tile)),
        );
        // As requisições já foram concluídas neste ponto; registre o consumo
        // mesmo se a gravação local do MBTiles falhar depois.
        _stadiaCreditsUsedThisMonth += creditsForRasterTiles(batch.length);
        if (_downloadTilesCompleted % 100 < batch.length) {
          await _persist();
        }
        db.execute('BEGIN;');
        try {
          for (var index = 0; index < batch.length; index++) {
            final tile = batch[index];
            final result = downloaded[index];
            _downloadBytes += result.bytes.length;
            if (existingCacheBytes + _downloadBytes > stadiaCacheLimitBytes) {
              throw StateError(
                'O cache offline direto atingiu 100 MB no aparelho. '
                'Exclua outro mapa direto ou reduza a região.',
              );
            }
            final tmsRow = (1 << tile.z) - 1 - tile.y;
            insertTile.execute(<Object?>[
              tile.z,
              tile.x,
              tmsRow,
              result.bytes,
            ]);
            final expiry = result.expiresAt;
            if (expiry != null &&
                (earliestExpiry == null || expiry.isBefore(earliestExpiry))) {
              earliestExpiry = expiry;
            }
            _downloadTilesCompleted++;
          }
          db.execute('COMMIT;');
        } catch (_) {
          db.execute('ROLLBACK;');
          rethrow;
        }
        _progress = _downloadTilesCompleted / _downloadTilesTotal;
        notifyListeners();
      }

      insertTile.dispose();
      insertTile = null;
      db.dispose();
      db = null;
      await _validateMbTiles(temporary);
      if (await target.exists()) await target.delete();
      await temporary.rename(target.path);
      final now = DateTime.now();
      final item = OfflineMapPackage(
        id: id,
        name: name,
        path: target.path,
        sizeBytes: await target.length(),
        addedAt: now,
        updatedAt: now,
        sourceHost: 'tiles.stadiamaps.com',
        providerId: _stadiaProviderId,
        downloadKind: downloadKind,
        west: bounds.west,
        south: bounds.south,
        east: bounds.east,
        north: bounds.north,
        minZoom: minZoom,
        maxZoom: maxZoom,
        expiresAt: earliestExpiry,
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
      insertTile?.dispose();
      db?.dispose();
      client.close(force: true);
      await _persist();
      _clearOperation();
    }
  }

  Future<_DownloadedTile> _fetchStadiaTile(
    HttpClient client,
    String apiKey,
    _TileCoordinate tile,
  ) async {
    final uri = Uri.parse(
      'https://tiles.stadiamaps.com/tiles/alidade_smooth/'
      '${tile.z}/${tile.x}/${tile.y}.png',
    );
    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.userAgentHeader, 'VigiaIA/1.0 offline-map');
    request.headers.set(HttpHeaders.authorizationHeader, 'Stadia-Auth $apiKey');
    final response = await request.close().timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.drain<void>();
      throw HttpException(
        'Tile ${tile.z}/${tile.x}/${tile.y}: HTTP ${response.statusCode}.',
        uri: uri,
      );
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      builder.add(chunk);
    }
    final bytes = builder.takeBytes();
    if (bytes.isEmpty) {
      throw HttpException('Tile vazio recebido.', uri: uri);
    }
    return _DownloadedTile(
      bytes: bytes,
      expiresAt: _expiryFromHeaders(response.headers),
    );
  }

  DateTime? _expiryFromHeaders(HttpHeaders headers) {
    final cacheControl = headers.value(HttpHeaders.cacheControlHeader);
    if (cacheControl != null) {
      final match = RegExp(r'max-age\s*=\s*(\d+)', caseSensitive: false)
          .firstMatch(cacheControl);
      final seconds = int.tryParse(match?.group(1) ?? '');
      if (seconds != null) return DateTime.now().add(Duration(seconds: seconds));
    }
    final expires = headers.value(HttpHeaders.expiresHeader);
    if (expires != null) {
      try {
        return HttpDate.parse(expires).toLocal();
      } catch (_) {}
    }
    return null;
  }

  Future<void> pauseDownload() async {
    if (!canPauseDownload || _downloadPaused) return;
    _downloadPaused = true;
    _resumeCompleter ??= Completer<void>();
    notifyListeners();
  }

  void resumeDownload() {
    if (!_downloadPaused) return;
    _downloadPaused = false;
    final completer = _resumeCompleter;
    _resumeCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete();
    notifyListeners();
  }

  void cancelDownload() {
    if (!_busy) return;
    _cancelRequested = true;
    resumeDownload();
    notifyListeners();
  }

  Future<void> _waitIfPausedOrCancelled() async {
    if (_cancelRequested) throw StateError('Download cancelado.');
    if (_downloadPaused) {
      _resumeCompleter ??= Completer<void>();
      await _resumeCompleter!.future;
    }
    if (_cancelRequested) throw StateError('Download cancelado.');
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

    _downloadBytes = 0;
    _downloadTilesCompleted = 0;
    _downloadTilesTotal = 0;
    _cancelRequested = false;
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
          if (_cancelRequested) throw StateError('Download cancelado.');
          sink.add(chunk);
          received += chunk.length;
          _downloadBytes = received;
          _progress = total == null
              ? null
              : (received / total).clamp(0.0, 1.0).toDouble();
          notifyListeners();
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      final info = await _validateMbTiles(temporary);
      if (await target.exists()) await target.delete();
      await temporary.rename(target.path);
      final now = DateTime.now();
      final item = OfflineMapPackage(
        id: id,
        name: name,
        path: target.path,
        sizeBytes: await target.length(),
        addedAt: now,
        updatedAt: now,
        sourceHost: uri.host,
        west: info.bounds?.west,
        south: info.bounds?.south,
        east: info.bounds?.east,
        north: info.bounds?.north,
        minZoom: info.minZoom,
        maxZoom: info.maxZoom,
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
      final info = await _validateMbTiles(temporary);
      if (await target.exists()) await target.delete();
      await temporary.rename(target.path);
      final now = DateTime.now();
      final item = OfflineMapPackage(
        id: id,
        name: name,
        path: target.path,
        sizeBytes: await target.length(),
        addedAt: now,
        updatedAt: now,
        sourceHost: 'arquivo local',
        west: info.bounds?.west,
        south: info.bounds?.south,
        east: info.bounds?.east,
        north: info.bounds?.north,
        minZoom: info.minZoom,
        maxZoom: info.maxZoom,
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

  Future<OfflineMapPackage> updateStadiaPackage(OfflineMapPackage item) async {
    if (item.providerId != _stadiaProviderId ||
        !item.hasBounds ||
        item.downloadKind == 'route') {
      throw StateError(
        'Este pacote não pode ser atualizado automaticamente; baixe o trajeto novamente.',
      );
    }
    final name = item.name;
    final bounds = OfflineMapBounds(
      west: item.west!,
      south: item.south!,
      east: item.east!,
      north: item.north!,
    );
    final minZoom = item.minZoom ?? 8;
    final maxZoom = item.maxZoom ?? 16;

    // O limite do provedor vale para o total armazenado por aparelho.
    // Removemos a cópia vencida antes de baixar a substituta para não duplicar
    // temporariamente o cache durante a atualização.
    await deletePackage(item.id);
    return downloadStadiaRegion(
      displayName: name,
      bounds: bounds,
      minZoom: minZoom,
      maxZoom: maxZoom,
    );
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

  Future<_MbTilesInfo> _validateMbTiles(File file) async {
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
      final raw = _readMetadata(file.path);
      final bounds = _parseBounds(raw['bounds']);
      return _MbTilesInfo(
        bounds: bounds,
        minZoom: int.tryParse(raw['minzoom'] ?? ''),
        maxZoom: int.tryParse(raw['maxzoom'] ?? ''),
      );
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

  Map<String, String> _readMetadata(String path) {
    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    try {
      final result = db.select('SELECT name, value FROM metadata');
      return <String, String>{
        for (final row in result)
          if (row['name'] is String && row['value'] is String)
            row['name'] as String: row['value'] as String,
      };
    } finally {
      db.dispose();
    }
  }

  OfflineMapBounds? _parseBounds(String? value) {
    if (value == null) return null;
    final parts = value.split(',').map((part) => double.tryParse(part.trim())).toList();
    if (parts.length != 4 || parts.any((part) => part == null)) return null;
    return OfflineMapBounds(
      west: parts[0]!,
      south: parts[1]!,
      east: parts[2]!,
      north: parts[3]!,
    );
  }

  List<_TileCoordinate> _tilesForBounds(
    OfflineMapBounds bounds, {
    required int minZoom,
    required int maxZoom,
  }) {
    final safeMin = minZoom.clamp(0, 20).toInt();
    final safeMax = maxZoom.clamp(safeMin, 20).toInt();
    final tiles = <_TileCoordinate>[];
    for (var zoom = safeMin; zoom <= safeMax; zoom++) {
      final n = 1 << zoom;
      final x1 = _lonToTileX(bounds.west, zoom).clamp(0, n - 1).toInt();
      final x2 = _lonToTileX(bounds.east, zoom).clamp(0, n - 1).toInt();
      final y1 = _latToTileY(bounds.north, zoom).clamp(0, n - 1).toInt();
      final y2 = _latToTileY(bounds.south, zoom).clamp(0, n - 1).toInt();
      for (var x = math.min(x1, x2); x <= math.max(x1, x2); x++) {
        for (var y = math.min(y1, y2); y <= math.max(y1, y2); y++) {
          tiles.add(_TileCoordinate(zoom, x, y));
        }
      }
    }
    return tiles;
  }

  List<_TileCoordinate> _tilesForRoute(
    List<LatLng> route, {
    required double bufferKm,
    required int minZoom,
    required int maxZoom,
  }) {
    if (route.length < 2) return const <_TileCoordinate>[];
    final safeMin = minZoom.clamp(0, 20).toInt();
    final safeMax = maxZoom.clamp(safeMin, 20).toInt();
    final encoded = <String, _TileCoordinate>{};
    for (var zoom = safeMin; zoom <= safeMax; zoom++) {
      final n = 1 << zoom;
      for (var index = 1; index < route.length; index++) {
        final a = route[index - 1];
        final b = route[index];
        final ax = _lonToTileXDouble(a.longitude, zoom);
        final ay = _latToTileYDouble(a.latitude, zoom);
        final bx = _lonToTileXDouble(b.longitude, zoom);
        final by = _latToTileYDouble(b.latitude, zoom);
        final steps = math.max(1, (math.max((bx - ax).abs(), (by - ay).abs()) * 2).ceil());
        for (var step = 0; step <= steps; step++) {
          final t = step / steps;
          final x = (ax + (bx - ax) * t).floor();
          final y = (ay + (by - ay) * t).floor();
          final lat = a.latitude + (b.latitude - a.latitude) * t;
          final tileWidthKm = math.max(
            0.05,
            40075.016686 * math.cos(lat * math.pi / 180).abs() / n,
          );
          final radiusTiles = (bufferKm / tileWidthKm).ceil().clamp(0, 20).toInt();
          for (var dx = -radiusTiles; dx <= radiusTiles; dx++) {
            for (var dy = -radiusTiles; dy <= radiusTiles; dy++) {
              final tx = x + dx;
              final ty = y + dy;
              if (tx < 0 || tx >= n || ty < 0 || ty >= n) continue;
              final tile = _TileCoordinate(zoom, tx, ty);
              encoded['$zoom/$tx/$ty'] = tile;
            }
          }
        }
      }
    }
    final tiles = encoded.values.toList(growable: false)
      ..sort((a, b) {
        final z = a.z.compareTo(b.z);
        if (z != 0) return z;
        final x = a.x.compareTo(b.x);
        return x != 0 ? x : a.y.compareTo(b.y);
      });
    return tiles;
  }

  OfflineMapBounds _routeBounds(List<LatLng> route, {required double marginKm}) {
    var minLat = route.first.latitude;
    var maxLat = route.first.latitude;
    var minLon = route.first.longitude;
    var maxLon = route.first.longitude;
    for (final point in route.skip(1)) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLon = math.min(minLon, point.longitude);
      maxLon = math.max(maxLon, point.longitude);
    }
    final centerLat = (minLat + maxLat) / 2;
    final latMargin = marginKm / 111.0;
    final cosLat = math
        .cos(centerLat * math.pi / 180)
        .abs()
        .clamp(0.15, 1.0)
        .toDouble();
    final lonMargin = marginKm / (111.0 * cosLat);
    return OfflineMapBounds(
      west: minLon - lonMargin,
      south: minLat - latMargin,
      east: maxLon + lonMargin,
      north: maxLat + latMargin,
    );
  }

  int _lonToTileX(double lon, int zoom) => _lonToTileXDouble(lon, zoom).floor();

  double _lonToTileXDouble(double lon, int zoom) {
    final n = 1 << zoom;
    return ((lon + 180) / 360) * n;
  }

  int _latToTileY(double lat, int zoom) => _latToTileYDouble(lat, zoom).floor();

  double _latToTileYDouble(double lat, int zoom) {
    final safe = lat.clamp(-85.05112878, 85.05112878).toDouble();
    final rad = safe * math.pi / 180;
    final n = 1 << zoom;
    return (1 - math.log(math.tan(rad) + 1 / math.cos(rad)) / math.pi) / 2 * n;
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
    _downloadBytes = 0;
    _downloadTilesCompleted = 0;
    _downloadTilesTotal = 0;
    _downloadPaused = false;
    _cancelRequested = false;
    final completer = _resumeCompleter;
    _resumeCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete();
    notifyListeners();
  }

  static String _creditMonthKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}';

  bool _resetCreditWindowIfNeeded() {
    final current = _creditMonthKey(DateTime.now());
    if (_stadiaCreditMonth == current) return false;
    _stadiaCreditMonth = current;
    _stadiaCreditsUsedThisMonth = 0;
    return true;
  }

  Future<void> _persist() async {
    if (_manifest == null) return;
    final payload = <String, Object?>{
      'activeId': _activeId,
      'mode': _mode.name,
      'stadiaApiKeyProtected': _stadiaApiKeyProtected,
      'stadiaCreditMonth': _stadiaCreditMonth,
      'stadiaCreditsUsedThisMonth': _stadiaCreditsUsedThisMonth,
      'stadiaMonthlyCreditLimit': _stadiaMonthlyCreditLimit,
      'packages': _packages.map((item) => item.toJson()).toList(growable: false),
    };
    await _manifest!.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
  }
}

class _TileCoordinate {
  const _TileCoordinate(this.z, this.x, this.y);

  final int z;
  final int x;
  final int y;
}

class _DownloadedTile {
  const _DownloadedTile({required this.bytes, required this.expiresAt});

  final Uint8List bytes;
  final DateTime? expiresAt;
}

class _MbTilesInfo {
  const _MbTilesInfo({required this.bounds, this.minZoom, this.maxZoom});

  final OfflineMapBounds? bounds;
  final int? minZoom;
  final int? maxZoom;
}
