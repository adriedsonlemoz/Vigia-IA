import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/camera_endpoint.dart';
import 'native_platform_service.dart';

class CameraProbeResult {
  const CameraProbeResult(
    this.online, {
    this.message,
    required this.checkedAt,
    this.latency,
  });

  final bool online;
  final String? message;
  final DateTime checkedAt;
  final Duration? latency;
}

class CameraRegistryService {
  CameraRegistryService._();
  static final CameraRegistryService instance = CameraRegistryService._();

  final NativePlatformService _native = NativePlatformService.instance;
  final List<CameraEndpoint> _items = <CameraEndpoint>[];
  File? _file;
  bool _initialized = false;

  List<CameraEndpoint> get items => List<CameraEndpoint>.unmodifiable(_items);

  Future<void> initialize() async {
    if (_initialized) return;
    final root = await getApplicationSupportDirectory();
    _file = File('${root.path}${Platform.pathSeparator}camera_registry.json');
    if (await _file!.exists()) {
      try {
        final decoded = jsonDecode(await _file!.readAsString());
        if (decoded is List) {
          for (final raw in decoded.whereType<Map>()) {
            final map = raw.cast<String, dynamic>();
            final endpoint = CameraEndpoint.fromJson(map);
            final protectedAddress = map['addressSecret'] as String?;
            final protectedKey = map['accessKeySecret'] as String?;
            _items.add(
              endpoint.copyWith(
                address: await _native.unprotectSecret(protectedAddress) ?? endpoint.address,
                accessKey: await _native.unprotectSecret(protectedKey) ?? endpoint.accessKey,
              ),
            );
          }
        }
      } catch (_) {}
    }
    _initialized = true;
  }

  Future<void> save(CameraEndpoint endpoint) async {
    await initialize();
    final index = _items.indexWhere((item) => item.id == endpoint.id);
    if (index < 0) {
      _items.add(endpoint);
    } else {
      _items[index] = endpoint;
    }
    await _persist();
  }

  Future<void> delete(String id) async {
    await initialize();
    _items.removeWhere((item) => item.id == id);
    await _persist();
  }

  Future<CameraProbeResult> probe(CameraEndpoint endpoint) async {
    final checkedAt = DateTime.now();
    if (!endpoint.enabled) {
      return CameraProbeResult(
        false,
        message: 'Desativada',
        checkedAt: checkedAt,
      );
    }
    if (endpoint.type == CameraEndpointType.local) {
      return CameraProbeResult(
        true,
        message: 'Disponível neste aparelho',
        checkedAt: checkedAt,
        latency: Duration.zero,
      );
    }
    final address = endpoint.address?.trim() ?? '';
    final uri = Uri.tryParse(address);
    if (uri == null || uri.host.isEmpty) {
      return CameraProbeResult(
        false,
        message: 'Endereço inválido',
        checkedAt: checkedAt,
      );
    }
    final stopwatch = Stopwatch()..start();
    if (endpoint.type == CameraEndpointType.rtsp) {
      try {
        final socket = await Socket.connect(
          uri.host,
          uri.hasPort ? uri.port : 554,
          timeout: const Duration(seconds: 2),
        );
        socket.destroy();
        stopwatch.stop();
        return CameraProbeResult(
          true,
          message: 'Host RTSP acessível',
          checkedAt: checkedAt,
          latency: stopwatch.elapsed,
        );
      } catch (_) {
        stopwatch.stop();
        return CameraProbeResult(
          false,
          message: 'Sem resposta do RTSP',
          checkedAt: checkedAt,
          latency: stopwatch.elapsed,
        );
      }
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    try {
      final root = address.endsWith('/')
          ? address.substring(0, address.length - 1)
          : address;
      final status = Uri.parse('$root/status').replace(
        queryParameters: <String, String>{'key': endpoint.accessKey ?? ''},
      );
      final request = await client.getUrl(status);
      final response = await request.close().timeout(const Duration(seconds: 3));
      await response.drain<void>();
      stopwatch.stop();
      final online = response.statusCode == HttpStatus.ok;
      return CameraProbeResult(
        online,
        message: online ? 'Celular online' : 'HTTP ${response.statusCode}',
        checkedAt: checkedAt,
        latency: stopwatch.elapsed,
      );
    } catch (_) {
      stopwatch.stop();
      return CameraProbeResult(
        false,
        message: 'Celular offline',
        checkedAt: checkedAt,
        latency: stopwatch.elapsed,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, CameraProbeResult>> probeAll(
    Iterable<CameraEndpoint> endpoints,
  ) async {
    final entries = await Future.wait(
      endpoints.map((endpoint) async {
        final result = await probe(endpoint);
        return MapEntry<String, CameraProbeResult>(endpoint.id, result);
      }),
    );
    return Map<String, CameraProbeResult>.fromEntries(entries);
  }

  Future<void> _persist() async {
    final file = _file;
    if (file == null) return;
    final data = <Map<String, Object?>>[];
    for (final item in _items) {
      final map = item.toJson();
      map['address'] = null;
      map['accessKey'] = null;
      if ((item.address ?? '').isNotEmpty) map['addressSecret'] = await _native.protectSecret(item.address!);
      if ((item.accessKey ?? '').isNotEmpty) map['accessKeySecret'] = await _native.protectSecret(item.accessKey!);
      data.add(map);
    }
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(data), flush: true);
    if (await file.exists()) await file.delete();
    await temp.rename(file.path);
  }
}
