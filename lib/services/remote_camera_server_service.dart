import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;

import '../models/rgb_frame.dart';
import 'background_monitor_service.dart';
import '../sources/local_camera_source.dart';

class RemoteCameraServerService extends ChangeNotifier {
  RemoteCameraServerService._();

  static final RemoteCameraServerService instance = RemoteCameraServerService._();

  LocalCameraSource? _source;
  StreamSubscription<RgbFrame>? _subscription;
  HttpServer? _server;
  Uint8List? _latestJpeg;
  DateTime? _lastFrameAt;
  DateTime? _lastNotificationUpdateAt;
  String _accessKey = '';
  int _port = 8765;
  String? _address;
  String? _error;
  bool _starting = false;

  bool get running => _server != null && _source != null;
  bool get starting => _starting;
  String? get address => _address;
  String get accessKey => _accessKey;
  String? get error => _error;
  DateTime? get lastFrameAt => _lastFrameAt;
  int get port => _port;

  Widget buildPreview() => _source?.buildPreview() ?? const SizedBox.expand();

  Future<void> start({int port = 8765}) async {
    if (running || _starting) return;
    _starting = true;
    _error = null;
    _port = port.clamp(1024, 65535).toInt();
    notifyListeners();
    try {
      final foregroundStarted = await BackgroundMonitorService.acquire(
        owner: BackgroundMonitorService.cameraModeOwner,
        usesCamera: true,
        statusText: 'Modo Câmera ativo • preparando transmissão local.',
      );
      if (!foregroundStarted) {
        throw StateError('O Android não permitiu iniciar o serviço de câmera em primeiro plano.');
      }
      _accessKey = _generateKey();
      final source = LocalCameraSource(
        analysisInterval: const Duration(milliseconds: 400),
      );
      _source = source;
      _subscription = source.frames.listen(_onFrame);
      await source.start();
      final server = await HttpServer.bind(InternetAddress.anyIPv4, _port, shared: true);
      _server = server;
      _address = await _findLocalAddress();
      unawaited(_serve(server));
    } catch (error) {
      _error = 'Não foi possível iniciar o modo Câmera: $error';
      await stop();
    } finally {
      _starting = false;
      notifyListeners();
    }
  }

  Future<void> _onFrame(RgbFrame frame) async {
    _lastFrameAt = frame.capturedAt;
    final lastUpdate = _lastNotificationUpdateAt;
    if (lastUpdate == null ||
        frame.capturedAt.difference(lastUpdate) >= const Duration(seconds: 5)) {
      _lastNotificationUpdateAt = frame.capturedAt;
      unawaited(
        BackgroundMonitorService.updateStatus(
          'Modo Câmera ativo • transmissão local recebendo imagens.',
        ),
      );
    }
    try {
      _latestJpeg = await compute<Map<String, Object>, Uint8List>(
        _encodeJpeg,
        <String, Object>{
          'width': frame.width,
          'height': frame.height,
          'bytes': Uint8List.fromList(frame.rgbBytes),
        },
      );
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _serve(HttpServer server) async {
    await for (final request in server) {
      try {
        final key = request.uri.queryParameters['key'] ?? request.headers.value('x-monitor-key');
        if (key != _accessKey) {
          request.response
            ..statusCode = HttpStatus.unauthorized
            ..write('unauthorized');
          await request.response.close();
          continue;
        }
        final path = request.uri.path;
        if (path == '/status') {
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode(<String, Object?>{
            'online': running,
            'lastFrameAt': _lastFrameAt?.toIso8601String(),
            'name': 'Vigia IA - câmera remota',
          }));
        } else if (path == '/frame.jpg') {
          final jpeg = _latestJpeg;
          if (jpeg == null) {
            request.response.statusCode = HttpStatus.serviceUnavailable;
            request.response.write('frame unavailable');
          } else {
            request.response.headers.contentType = ContentType('image', 'jpeg');
            request.response.add(jpeg);
          }
        } else {
          request.response
            ..statusCode = HttpStatus.notFound
            ..write('not found');
        }
      } catch (_) {
        request.response.statusCode = HttpStatus.internalServerError;
      } finally {
        await request.response.close();
      }
    }
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _source?.dispose();
    } catch (_) {}
    _source = null;
    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
    _latestJpeg = null;
    _lastFrameAt = null;
    _lastNotificationUpdateAt = null;
    _address = null;
    _accessKey = '';
    await BackgroundMonitorService.release(BackgroundMonitorService.cameraModeOwner);
    notifyListeners();
  }

  Future<String?> _findLocalAddress() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    String? bestAddress;
    var bestScore = -1000;
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        final value = address.address;
        if (address.isLoopback || value.startsWith('169.254.')) continue;
        final score = _addressScore(interface.name, value);
        if (bestAddress == null || score > bestScore) {
          bestAddress = value;
          bestScore = score;
        }
      }
    }
    return bestAddress == null ? null : 'http://$bestAddress:$_port';
  }

  int _addressScore(String interfaceName, String value) {
    final name = interfaceName.toLowerCase();
    var score = _isPrivateIpv4(value) ? 40 : 0;
    if (value.startsWith('192.168.')) score += 3;
    if (value.startsWith('172.')) score += 2;
    if (value.startsWith('10.')) score += 1;
    if (name.contains('wlan') || name.contains('wifi') || name.startsWith('ap')) {
      score += 30;
    }
    if (name.contains('tun') || name.contains('vpn')) score -= 40;
    if (name.contains('rmnet') || name.contains('ccmni')) score -= 20;
    return score;
  }

  bool _isPrivateIpv4(String value) {
    final parts = value.split('.').map(int.tryParse).toList(growable: false);
    if (parts.length != 4 || parts.any((part) => part == null)) return false;
    final a = parts[0]!;
    final b = parts[1]!;
    return a == 10 ||
        (a == 172 && b >= 16 && b <= 31) ||
        (a == 192 && b == 168);
  }

  String _generateKey() {
    final random = Random.secure();
    return List<String>.generate(12, (_) => random.nextInt(36).toRadixString(36)).join().toUpperCase();
  }
}

Uint8List _encodeJpeg(Map<String, Object> data) {
  final width = data['width']! as int;
  final height = data['height']! as int;
  final bytes = data['bytes']! as Uint8List;
  var image = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: bytes.buffer,
    bytesOffset: bytes.offsetInBytes,
    numChannels: 3,
    order: img.ChannelOrder.rgb,
  );
  if (image.width > 960) image = img.copyResize(image, width: 960);
  return Uint8List.fromList(img.encodeJpg(image, quality: 78));
}
