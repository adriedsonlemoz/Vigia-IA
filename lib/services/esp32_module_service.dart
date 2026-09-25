import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/camera_endpoint.dart';
import '../models/esp32_module.dart';
import 'camera_registry_service.dart';
import 'native_platform_service.dart';

class Esp32ProbeResult {
  const Esp32ProbeResult(
    this.online, {
    this.message,
    required this.checkedAt,
    this.latency,
    this.protocolVersion,
    this.firmwareVersion,
    this.reportedCapabilities = const <Esp32Capability>{},
  });

  final bool online;
  final String? message;
  final DateTime checkedAt;
  final Duration? latency;
  final int? protocolVersion;
  final String? firmwareVersion;
  final Set<Esp32Capability> reportedCapabilities;
}

class Esp32ModuleService extends ChangeNotifier {
  Esp32ModuleService._();
  static final Esp32ModuleService instance = Esp32ModuleService._();

  final NativePlatformService _native = NativePlatformService.instance;
  final CameraRegistryService _cameraRegistry = CameraRegistryService.instance;
  final List<Esp32Module> _modules = <Esp32Module>[];
  File? _file;
  bool _initialized = false;
  Future<void>? _initializing;

  List<Esp32Module> get modules => List<Esp32Module>.unmodifiable(_modules);

  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    return _initializing ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      _modules.clear();
      await _cameraRegistry.initialize();
      final root = await getApplicationSupportDirectory();
      _file = File('${root.path}${Platform.pathSeparator}esp32_modules.json');
      if (await _file!.exists()) {
        try {
          final decoded = jsonDecode(await _file!.readAsString());
          if (decoded is List) {
            for (final raw in decoded.whereType<Map>()) {
              final map = raw.cast<String, dynamic>();
              final module = Esp32Module.fromJson(map);
              final protectedAddress = map['addressSecret'] as String?;
              final protectedKey = map['accessKeySecret'] as String?;
              _modules.add(
                module.copyWith(
                  address: await _native.unprotectSecret(protectedAddress) ??
                      module.address,
                  accessKey: await _native.unprotectSecret(protectedKey) ??
                      module.accessKey,
                ),
              );
            }
          }
        } catch (_) {}
      }

      var migrated = false;
      for (final endpoint in _cameraRegistry.items.where(
        (item) => item.type == CameraEndpointType.esp32,
      )) {
        if (_modules.any((item) => item.id == endpoint.id)) continue;
        _modules.add(Esp32Module.fromLegacyCameraEndpoint(endpoint));
        migrated = true;
      }
      _initialized = true;
      if (migrated) await _persist();
      await _syncCameraRegistry();
      notifyListeners();
    } finally {
      _initializing = null;
    }
  }

  Future<void> save(Esp32Module module) async {
    await initialize();
    final normalized = module.copyWith(
      capabilities: Set<Esp32Capability>.unmodifiable(module.capabilities),
    );
    final index = _modules.indexWhere((item) => item.id == normalized.id);
    if (index < 0) {
      _modules.add(normalized);
    } else {
      _modules[index] = normalized;
    }
    await _persist();
    await _syncCameraEndpoint(normalized);
    notifyListeners();
  }

  Future<void> delete(String id) async {
    await initialize();
    _modules.removeWhere((item) => item.id == id);
    await _persist();
    final existing = _cameraRegistry.items.where(
      (item) => item.id == id && item.type == CameraEndpointType.esp32,
    );
    if (existing.isNotEmpty) await _cameraRegistry.delete(id);
    notifyListeners();
  }

  Future<Esp32ProbeResult> probe(Esp32Module module) async {
    final checkedAt = DateTime.now();
    if (!module.enabled) {
      return Esp32ProbeResult(
        false,
        message: 'Desativado',
        checkedAt: checkedAt,
      );
    }
    final address = module.address?.trim() ?? '';
    final uri = Uri.tryParse(address);
    if (uri == null ||
        uri.host.isEmpty ||
        !(uri.scheme == 'http' || uri.scheme == 'https')) {
      return Esp32ProbeResult(
        false,
        message: 'Endereço inválido',
        checkedAt: checkedAt,
      );
    }

    final root = _normalizedRoot(address);
    final stopwatch = Stopwatch()..start();
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    int? lastStatusCode;
    try {
      for (final path in const <String>[
        '/api/v1/status',
        '/status',
        '/api/v1/info',
        '/info',
      ]) {
        final target = Uri.parse('$root$path').replace(
          queryParameters: (module.accessKey ?? '').isEmpty
              ? null
              : <String, String>{'key': module.accessKey!},
        );
        final request = await client.getUrl(target);
        _applyAccessKey(request, module.accessKey);
        request.headers.set('accept', 'application/json');
        final response =
            await request.close().timeout(const Duration(seconds: 3));
        final body = await utf8.decoder
            .bind(response)
            .join()
            .timeout(const Duration(seconds: 3));
        lastStatusCode = response.statusCode;

        if (response.statusCode == HttpStatus.notFound ||
            response.statusCode == HttpStatus.methodNotAllowed) {
          continue;
        }
        if (response.statusCode == HttpStatus.unauthorized ||
            response.statusCode == HttpStatus.forbidden) {
          stopwatch.stop();
          return Esp32ProbeResult(
            false,
            message: 'Chave do módulo recusada',
            checkedAt: checkedAt,
            latency: stopwatch.elapsed,
          );
        }
        final online = response.statusCode >= 200 && response.statusCode < 300;
        if (!online) {
          stopwatch.stop();
          return Esp32ProbeResult(
            false,
            message: 'HTTP ${response.statusCode}',
            checkedAt: checkedAt,
            latency: stopwatch.elapsed,
          );
        }

        int? protocolVersion;
        String? firmwareVersion;
        final reportedCapabilities = <Esp32Capability>{};
        if (body.trim().isNotEmpty) {
          try {
            final decoded = jsonDecode(body);
            if (decoded is Map) {
              final rootMap = decoded.map(
                (key, value) => MapEntry(key.toString(), value),
              );
              final nestedInfo = rootMap['info'];
              final info = nestedInfo is Map
                  ? nestedInfo.map(
                      (key, value) => MapEntry(key.toString(), value),
                    )
                  : rootMap;
              protocolVersion =
                  (info['protocolVersion'] as num?)?.toInt() ??
                      (rootMap['protocolVersion'] as num?)?.toInt();
              firmwareVersion = info['firmwareVersion']?.toString() ??
                  info['firmware']?.toString() ??
                  rootMap['firmwareVersion']?.toString() ??
                  rootMap['firmware']?.toString();
              final rawCapabilities =
                  info['capabilities'] ?? rootMap['capabilities'];
              if (rawCapabilities is List) {
                for (final raw in rawCapabilities) {
                  final name = raw?.toString();
                  for (final capability in Esp32Capability.values) {
                    if (capability.name == name) {
                      reportedCapabilities.add(capability);
                    }
                  }
                }
              }
            }
          } catch (_) {
            // Firmware antigo pode responder apenas texto.
          }
        }
        stopwatch.stop();
        return Esp32ProbeResult(
          true,
          message: 'ESP32 online',
          checkedAt: checkedAt,
          latency: stopwatch.elapsed,
          protocolVersion: protocolVersion,
          firmwareVersion: firmwareVersion,
          reportedCapabilities:
              Set<Esp32Capability>.unmodifiable(reportedCapabilities),
        );
      }
      stopwatch.stop();
      return Esp32ProbeResult(
        false,
        message: lastStatusCode == null
            ? 'ESP32 offline'
            : 'Nenhum endpoint compatível (HTTP $lastStatusCode)',
        checkedAt: checkedAt,
        latency: stopwatch.elapsed,
      );
    } catch (_) {
      stopwatch.stop();
      return Esp32ProbeResult(
        false,
        message: 'ESP32 offline',
        checkedAt: checkedAt,
        latency: stopwatch.elapsed,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<Esp32ProbeResult> applyConfiguration(Esp32Module module) async {
    final checkedAt = DateTime.now();
    final address = module.address?.trim() ?? '';
    final uri = Uri.tryParse(address);
    if (uri == null ||
        uri.host.isEmpty ||
        !(uri.scheme == 'http' || uri.scheme == 'https')) {
      return Esp32ProbeResult(
        false,
        message: 'Endereço inválido',
        checkedAt: checkedAt,
      );
    }
    final root = _normalizedRoot(address);
    final stopwatch = Stopwatch()..start();
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    int? lastStatusCode;
    try {
      for (final path in const <String>['/api/v1/config', '/config']) {
        final target = Uri.parse('$root$path').replace(
          queryParameters: (module.accessKey ?? '').isEmpty
              ? null
              : <String, String>{'key': module.accessKey!},
        );
        final request = await client.postUrl(target);
        request.headers.contentType = ContentType.json;
        request.headers.set('accept', 'application/json');
        _applyAccessKey(request, module.accessKey);
        request.write(jsonEncode(module.toConfigurationJson()));
        final response =
            await request.close().timeout(const Duration(seconds: 5));
        await response.drain<void>();
        lastStatusCode = response.statusCode;

        if (response.statusCode == HttpStatus.notFound ||
            response.statusCode == HttpStatus.methodNotAllowed) {
          continue;
        }
        stopwatch.stop();
        final success =
            response.statusCode >= 200 && response.statusCode < 300;
        return Esp32ProbeResult(
          success,
          message: success
              ? 'Configuração aplicada no ESP32'
              : response.statusCode == HttpStatus.unauthorized ||
                      response.statusCode == HttpStatus.forbidden
                  ? 'Chave do módulo recusada'
                  : 'ESP32 recusou a configuração (HTTP ${response.statusCode})',
          checkedAt: checkedAt,
          latency: stopwatch.elapsed,
        );
      }
      stopwatch.stop();
      return Esp32ProbeResult(
        false,
        message: lastStatusCode == null
            ? 'Endpoint de configuração indisponível'
            : 'Nenhum endpoint de configuração compatível (HTTP $lastStatusCode)',
        checkedAt: checkedAt,
        latency: stopwatch.elapsed,
      );
    } catch (error) {
      stopwatch.stop();
      return Esp32ProbeResult(
        false,
        message: 'Não foi possível configurar o ESP32: $error',
        checkedAt: checkedAt,
        latency: stopwatch.elapsed,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, Esp32ProbeResult>> probeAll(
    Iterable<Esp32Module> modules,
  ) async {
    final entries = await Future.wait(
      modules.map((module) async {
        final result = await probe(module);
        return MapEntry<String, Esp32ProbeResult>(module.id, result);
      }),
    );
    return Map<String, Esp32ProbeResult>.fromEntries(entries);
  }

  String _normalizedRoot(String address) =>
      address.endsWith('/') ? address.substring(0, address.length - 1) : address;

  void _applyAccessKey(HttpClientRequest request, String? accessKey) {
    if ((accessKey ?? '').isNotEmpty) {
      request.headers.set('x-monitor-key', accessKey!);
    }
  }

  Future<void> _syncCameraRegistry() async {
    final moduleIds = _modules.map((item) => item.id).toSet();
    final staleEsp32 = _cameraRegistry.items
        .where(
          (item) =>
              item.type == CameraEndpointType.esp32 &&
              !moduleIds.contains(item.id),
        )
        .map((item) => item.id)
        .toList(growable: false);
    for (final id in staleEsp32) {
      await _cameraRegistry.delete(id);
    }
    for (final module in _modules) {
      await _syncCameraEndpoint(module);
    }
  }

  Future<void> _syncCameraEndpoint(Esp32Module module) async {
    final existing = _cameraRegistry.items.where(
      (item) => item.id == module.id && item.type == CameraEndpointType.esp32,
    );
    if (!module.cameraEnabled) {
      if (existing.isNotEmpty) await _cameraRegistry.delete(module.id);
      return;
    }
    await _cameraRegistry.save(module.toCameraEndpoint());
  }

  Future<void> _persist() async {
    final file = _file;
    if (file == null) return;
    final data = <Map<String, Object?>>[];
    for (final module in _modules) {
      final map = module.toJson();
      map['address'] = null;
      map['accessKey'] = null;
      if ((module.address ?? '').isNotEmpty) {
        map['addressSecret'] = await _native.protectSecret(module.address!);
      }
      if ((module.accessKey ?? '').isNotEmpty) {
        map['accessKeySecret'] = await _native.protectSecret(module.accessKey!);
      }
      data.add(map);
    }
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(data), flush: true);
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
  }
}
