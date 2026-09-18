import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../models/rgb_frame.dart';

class MonitorLanStreamService extends ChangeNotifier {
  HttpServer? _server;
  Uint8List? _latestJpeg;
  DateTime? _lastFrameAt;
  String _accessKey = '';
  String? _baseAddress;
  String? _error;
  int _port = 8766;
  int _frameSequence = 0;
  int _connectedViewers = 0;
  bool _starting = false;
  bool _encoding = false;

  bool get running => _server != null;
  bool get starting => _starting;
  int get port => _port;
  String get accessKey => _accessKey;
  String? get baseAddress => _baseAddress;
  String? get error => _error;
  DateTime? get lastFrameAt => _lastFrameAt;
  int get connectedViewers => _connectedViewers;

  String? get viewerUrl {
    final base = _baseAddress;
    if (!running || base == null || _accessKey.isEmpty) return null;
    return buildViewerUrl(base, _accessKey);
  }

  static String buildViewerUrl(String baseAddress, String accessKey) {
    final base = baseAddress.endsWith('/')
        ? baseAddress.substring(0, baseAddress.length - 1)
        : baseAddress;
    return '$base/?key=${Uri.encodeQueryComponent(accessKey)}';
  }

  Future<bool> start({int port = 8766}) async {
    if (running) return true;
    if (_starting) return false;
    _starting = true;
    _error = null;
    _port = port.clamp(1024, 65535).toInt();
    notifyListeners();
    try {
      _accessKey = _generateKey();
      final localAddress = await _findPrivateIpv4Address();
      if (localAddress == null) {
        throw StateError(
          'Nenhum endereço IPv4 local foi encontrado. Conecte o aparelho ao Wi-Fi ou hotspot local.',
        );
      }
      final server = await HttpServer.bind(
        InternetAddress(localAddress),
        _port,
        shared: true,
      );
      _server = server;
      _baseAddress = 'http://$localAddress:$_port';
      unawaited(_serve(server));
      return true;
    } catch (error) {
      _error = 'Não foi possível abrir a transmissão na rede local: $error';
      await _closeServerOnly();
      return false;
    } finally {
      _starting = false;
      notifyListeners();
    }
  }

  Future<void> publishFrame(RgbFrame frame) async {
    if (!running || _encoding) return;
    _encoding = true;
    _lastFrameAt = frame.capturedAt;
    try {
      final jpeg = await compute<Map<String, Object>, Uint8List>(
        _encodeJpeg,
        <String, Object>{
          'width': frame.width,
          'height': frame.height,
          'bytes': Uint8List.fromList(frame.rgbBytes),
        },
      );
      if (!running) return;
      _latestJpeg = jpeg;
      _frameSequence++;
    } catch (_) {
      // Um quadro perdido não deve derrubar o monitor nem o servidor LAN.
    } finally {
      _encoding = false;
    }
  }

  Future<void> _serve(HttpServer server) async {
    try {
      await for (final request in server) {
        unawaited(_handleRequest(request));
      }
    } catch (error) {
      if (identical(_server, server)) {
        _error = 'A transmissão na rede local foi interrompida: $error';
        _server = null;
        notifyListeners();
      }
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final key = request.uri.queryParameters['key'] ??
        request.headers.value('x-vigia-key');
    if (key != _accessKey || _accessKey.isEmpty) {
      request.response
        ..statusCode = HttpStatus.unauthorized
        ..headers.contentType = ContentType.text
        ..write('Acesso não autorizado.');
      await request.response.close();
      return;
    }

    request.response.headers
      ..set(HttpHeaders.cacheControlHeader, 'no-store, no-cache, must-revalidate')
      ..set('Pragma', 'no-cache')
      ..set('X-Content-Type-Options', 'nosniff');

    switch (request.uri.path) {
      case '/':
        await _serveViewerPage(request);
        return;
      case '/status':
        await _serveStatus(request);
        return;
      case '/frame.jpg':
        await _serveSingleFrame(request);
        return;
      case '/stream.mjpg':
        await _serveMjpeg(request);
        return;
      default:
        request.response
          ..statusCode = HttpStatus.notFound
          ..headers.contentType = ContentType.text
          ..write('Não encontrado.');
        await request.response.close();
    }
  }

  Future<void> _serveViewerPage(HttpRequest request) async {
    final key = Uri.encodeQueryComponent(_accessKey);
    request.response.headers.contentType = ContentType.html;
    request.response.write('''<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<title>Vigia IA - Monitor local</title>
<style>
html,body{margin:0;background:#07111f;color:#edf5ff;font-family:system-ui,-apple-system,sans-serif;height:100%;}
body{display:flex;flex-direction:column;}
header{padding:14px 16px;background:#0d1b2d;border-bottom:1px solid #22344c;font-weight:800;}
main{flex:1;display:flex;align-items:center;justify-content:center;padding:10px;min-height:0;}
img{max-width:100%;max-height:100%;object-fit:contain;border-radius:12px;background:#000;}
footer{padding:10px 16px;color:#9fb0c7;font-size:13px;background:#0d1b2d;}
.online{color:#65d58a;}
</style>
</head>
<body>
<header>Vigia IA • <span class="online">transmissão local ativa</span></header>
<main><img src="/stream.mjpg?key=$key" alt="Monitor ao vivo"></main>
<footer>Esta página funciona apenas enquanto o monitoramento estiver ativo e o aparelho permanecer acessível na mesma rede local.</footer>
</body>
</html>''');
    await request.response.close();
  }

  Future<void> _serveStatus(HttpRequest request) async {
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(<String, Object?>{
      'online': running,
      'lastFrameAt': _lastFrameAt?.toIso8601String(),
      'viewers': _connectedViewers,
      'name': 'Vigia IA - monitor local',
    }));
    await request.response.close();
  }

  Future<void> _serveSingleFrame(HttpRequest request) async {
    final jpeg = _latestJpeg;
    if (jpeg == null) {
      request.response
        ..statusCode = HttpStatus.serviceUnavailable
        ..headers.contentType = ContentType.text
        ..write('Aguardando quadro do monitor.');
    } else {
      request.response.headers.contentType = ContentType('image', 'jpeg');
      request.response.add(jpeg);
    }
    await request.response.close();
  }

  Future<void> _serveMjpeg(HttpRequest request) async {
    final response = request.response;
    response.headers
      ..set(
        HttpHeaders.contentTypeHeader,
        'multipart/x-mixed-replace; boundary=vigiaframe',
      )
      ..set(HttpHeaders.connectionHeader, 'close');

    _connectedViewers++;
    notifyListeners();
    var sentSequence = -1;
    try {
      while (running) {
        final jpeg = _latestJpeg;
        final sequence = _frameSequence;
        if (jpeg != null && sequence != sentSequence) {
          response.add(utf8.encode(
            '--vigiaframe\r\n'
            'Content-Type: image/jpeg\r\n'
            'Content-Length: ${jpeg.length}\r\n\r\n',
          ));
          response.add(jpeg);
          response.add(const <int>[13, 10]);
          await response.flush();
          sentSequence = sequence;
        }
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
    } catch (_) {
      // Navegador fechou a conexão ou a rede foi interrompida.
    } finally {
      _connectedViewers = max(0, _connectedViewers - 1);
      notifyListeners();
      try {
        await response.close();
      } catch (_) {}
    }
  }

  Future<void> stop() async {
    await _closeServerOnly();
    _latestJpeg = null;
    _lastFrameAt = null;
    _baseAddress = null;
    _accessKey = '';
    _frameSequence = 0;
    _connectedViewers = 0;
    _error = null;
    notifyListeners();
  }

  Future<void> _closeServerOnly() async {
    final server = _server;
    _server = null;
    if (server != null) {
      try {
        await server.close(force: true);
      } catch (_) {}
    }
  }

  Future<String?> _findPrivateIpv4Address() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    String? bestAddress;
    var bestScore = -1000;
    for (final interface in interfaces) {
      final interfaceName = interface.name.toLowerCase();
      if (interfaceName.contains('tun') ||
          interfaceName.contains('vpn') ||
          interfaceName.contains('rmnet') ||
          interfaceName.contains('ccmni')) {
        continue;
      }
      for (final address in interface.addresses) {
        final value = address.address;
        if (address.isLoopback || !_isPrivateIpv4(value)) continue;
        final score = _addressScore(interface.name, value);
        if (bestAddress == null || score > bestScore) {
          bestAddress = value;
          bestScore = score;
        }
      }
    }
    return bestAddress;
  }

  int _addressScore(String interfaceName, String value) {
    final name = interfaceName.toLowerCase();
    var score = 0;
    if (value.startsWith('192.168.')) score += 8;
    if (value.startsWith('172.')) score += 6;
    if (value.startsWith('10.')) score += 4;
    if (name.contains('wlan') || name.contains('wifi') || name.startsWith('ap')) {
      score += 30;
    }
    if (name.contains('eth')) score += 20;
    if (name.contains('tun') || name.contains('vpn')) score -= 50;
    if (name.contains('rmnet') || name.contains('ccmni')) score -= 30;
    return score;
  }

  bool _isPrivateIpv4(String value) {
    final parts = value.split('.').map(int.tryParse).toList(growable: false);
    if (parts.length != 4 || parts.any((part) => part == null)) return false;
    final a = parts[0]!;
    final b = parts[1]!;
    return a == 10 ||
        (a == 172 && b >= 16 && b <= 31) ||
        (a == 192 && b == 168) ||
        (a == 100 && b >= 64 && b <= 127);
  }

  String _generateKey() {
    final random = Random.secure();
    return List<String>.generate(
      16,
      (_) => random.nextInt(36).toRadixString(36),
    ).join().toUpperCase();
  }

  bool get likelyPermissionError {
    final value = (_error ?? '').toLowerCase();
    return value.contains('operation not permitted') ||
        value.contains('permission denied') ||
        value.contains('eperm');
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
  return Uint8List.fromList(img.encodeJpg(image, quality: 76));
}
