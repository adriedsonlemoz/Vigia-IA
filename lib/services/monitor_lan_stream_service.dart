import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../models/device_telemetry.dart';
import '../models/rgb_frame.dart';

class MonitorLanStreamService extends ChangeNotifier {
  HttpServer? _server;
  Uint8List? _latestJpeg;
  DateTime? _lastFrameAt;
  DateTime? _lastEncodedAt;
  String _accessKey = '';
  String? _baseAddress;
  String? _error;
  int _port = 8766;
  int _frameSequence = 0;
  bool _starting = false;
  bool _encoding = false;
  double _streamFps = 0;
  int? _maxFps;
  DateTime? _lastPublishAttemptAt;
  Map<String, Object?>? _deviceTelemetry;
  bool _bikeModeEnabled = false;
  String? _bikeProfile;
  int _jpegMaxWidth = 960;
  int _jpegQuality = 76;
  Timer? _sessionCleanupTimer;
  final Map<String, DateTime> _sessions = <String, DateTime>{};
  int _lastReportedViewers = 0;

  static const Duration _activeViewerWindow = Duration(seconds: 15);
  static const Duration _sessionLifetime = Duration(hours: 1);
  static const Duration _frameFreshness = Duration(seconds: 5);

  bool get running => _server != null;
  bool get starting => _starting;
  int get port => _port;
  String get accessKey => _accessKey;
  String? get baseAddress => _baseAddress;
  String? get error => _error;
  DateTime? get lastFrameAt => _lastFrameAt;
  int get connectedViewers => _activeSessionCount(DateTime.now());
  int get frameSequence => _frameSequence;
  double get streamFps => _streamFps;
  int? get maxFps => _maxFps;

  void setMaxFps(int? value) {
    _maxFps = value?.clamp(1, 30).toInt();
    _lastPublishAttemptAt = null;
  }

  void updateDeviceTelemetry(DeviceTelemetrySnapshot? telemetry) {
    _deviceTelemetry = telemetry?.toJson();
  }

  void setBikeModeState({required bool enabled, required String profile}) {
    _bikeModeEnabled = enabled;
    _bikeProfile = enabled ? profile : null;
  }

  void setEncodingPolicy({required int maxWidth, required int quality}) {
    _jpegMaxWidth = maxWidth.clamp(320, 1280).toInt();
    _jpegQuality = quality.clamp(40, 90).toInt();
  }

  bool get framesFresh {
    final last = _lastFrameAt;
    if (last == null) return false;
    final age = DateTime.now().difference(last);
    return !age.isNegative && age <= _frameFreshness;
  }

  String? get viewerUrl {
    final base = _baseAddress;
    if (!running || base == null || _accessKey.isEmpty) return null;
    return buildViewerUrl(base, _accessKey);
  }

  static String buildViewerUrl(String baseAddress, String accessKey) {
    final base = baseAddress.endsWith('/')
        ? baseAddress.substring(0, baseAddress.length - 1)
        : baseAddress;
    return '$base/#key=${Uri.encodeComponent(accessKey)}';
  }

  static String buildManualViewerUrl(String baseAddress) =>
      baseAddress.endsWith('/') ? baseAddress : '$baseAddress/';

  Future<bool> start({int port = 8766}) async {
    if (running) return true;
    if (_starting) return false;
    _starting = true;
    _error = null;
    _port = port.clamp(1024, 65535).toInt();
    notifyListeners();
    try {
      _accessKey = _generateKey(16);
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
      _sessionCleanupTimer?.cancel();
      _sessionCleanupTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _pruneSessions(notify: true),
      );
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
    final cap = _maxFps;
    if (cap != null) {
      final previousAttempt = _lastPublishAttemptAt;
      final minimumInterval = Duration(microseconds: (1000000 / cap).round());
      if (previousAttempt != null &&
          frame.capturedAt.difference(previousAttempt) < minimumInterval) {
        return;
      }
      _lastPublishAttemptAt = frame.capturedAt;
    }
    _encoding = true;
    try {
      final jpeg = await compute<Map<String, Object>, Uint8List>(
        _encodeJpeg,
        <String, Object>{
          'width': frame.width,
          'height': frame.height,
          'bytes': Uint8List.fromList(frame.rgbBytes),
          'maxWidth': _jpegMaxWidth,
          'quality': _jpegQuality,
        },
      );
      if (!running) return;
      final previous = _lastEncodedAt;
      final now = DateTime.now();
      if (previous != null) {
        final elapsedMs = now.difference(previous).inMilliseconds;
        if (elapsedMs > 0) {
          final instant = 1000 / elapsedMs;
          _streamFps = _streamFps == 0
              ? instant
              : (_streamFps * 0.75 + instant * 0.25);
        }
      }
      _lastEncodedAt = now;
      _latestJpeg = jpeg;
      _lastFrameAt = frame.capturedAt;
      _frameSequence++;
      notifyListeners();
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
    request.response.headers
      ..set(HttpHeaders.cacheControlHeader, 'no-store, no-cache, must-revalidate')
      ..set('Pragma', 'no-cache')
      ..set('X-Content-Type-Options', 'nosniff')
      ..set('Referrer-Policy', 'no-referrer');

    final path = request.uri.path;
    if (path == '/') {
      await _serveViewerPage(request);
      return;
    }
    if (path == '/session') {
      await _createBrowserSession(request);
      return;
    }

    final session = _authorizedSession(request);
    if (session == null) {
      request.response
        ..statusCode = HttpStatus.unauthorized
        ..headers.contentType = ContentType.text
        ..write('Acesso não autorizado.');
      await request.response.close();
      return;
    }
    _touchSession(session);

    switch (path) {
      case '/status':
        await _serveStatus(request);
        return;
      case '/frame.jpg':
        await _serveSingleFrame(request);
        return;
      default:
        request.response
          ..statusCode = HttpStatus.notFound
          ..headers.contentType = ContentType.text
          ..write('Não encontrado.');
        await request.response.close();
    }
  }

  Future<void> _createBrowserSession(HttpRequest request) async {
    if (request.method != 'POST') {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      await request.response.close();
      return;
    }
    final key = request.headers.value('x-vigia-key') ?? '';
    if (_accessKey.isEmpty || key != _accessKey) {
      request.response
        ..statusCode = HttpStatus.unauthorized
        ..headers.contentType = ContentType.text
        ..write('Chave inválida.');
      await request.response.close();
      return;
    }
    final session = _generateKey(32).toLowerCase();
    final now = DateTime.now();
    _sessions[session] = now;
    _pruneSessions(notify: true);
    request.response.cookies.add(
      Cookie('vigia_session', session)
        ..httpOnly = true
        ..sameSite = SameSite.strict
        ..path = '/'
        ..maxAge = _sessionLifetime.inSeconds,
    );
    request.response.statusCode = HttpStatus.noContent;
    await request.response.close();
  }

  String? _authorizedSession(HttpRequest request) {
    final cookie = request.cookies
        .where((item) => item.name == 'vigia_session')
        .map((item) => item.value)
        .firstOrNull;
    if (cookie != null && _sessionIsValid(cookie, DateTime.now())) return cookie;

    // Mantém compatibilidade para clientes técnicos que enviam a chave em
    // header, sem recolocar o segredo na URL.
    final headerKey = request.headers.value('x-vigia-key');
    if (headerKey == _accessKey && _accessKey.isNotEmpty) {
      final transient = 'header-${request.connectionInfo?.remoteAddress.address ?? 'client'}';
      _sessions[transient] = DateTime.now();
      return transient;
    }
    return null;
  }

  bool _sessionIsValid(String session, DateTime now) {
    final last = _sessions[session];
    if (last == null) return false;
    return now.difference(last) <= _sessionLifetime;
  }

  void _touchSession(String session) {
    _sessions[session] = DateTime.now();
    _pruneSessions(notify: true);
  }

  void _pruneSessions({required bool notify}) {
    final now = DateTime.now();
    _sessions.removeWhere((_, lastSeen) => now.difference(lastSeen) > _sessionLifetime);
    final viewers = _activeSessionCount(now);
    if (notify && viewers != _lastReportedViewers) {
      _lastReportedViewers = viewers;
      notifyListeners();
    }
  }

  int _activeSessionCount(DateTime now) => _sessions.values
      .where((lastSeen) => now.difference(lastSeen) <= _activeViewerWindow)
      .length;

  Future<void> _serveViewerPage(HttpRequest request) async {
    request.response.headers.contentType = ContentType.html;
    request.response.write('''<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<title>Vigia IA - Monitor local</title>
<style>
:root{color-scheme:dark}*{box-sizing:border-box}html,body{margin:0;background:#07111f;color:#edf5ff;font-family:system-ui,-apple-system,sans-serif;height:100%;}body{display:flex;flex-direction:column;min-height:100dvh}header{padding:14px 16px;background:#0d1b2d;border-bottom:1px solid #22344c;font-weight:800;display:flex;gap:8px;align-items:center;flex-wrap:wrap}.state{color:#fbbf24}.state.ok{color:#65d58a}.state.bad{color:#ff7b86}main{flex:1;display:flex;align-items:center;justify-content:center;padding:10px;min-height:0;position:relative}img{display:none;max-width:100%;max-height:100%;object-fit:contain;border-radius:12px;background:#000}.empty{text-align:center;color:#aebed2;max-width:520px;padding:24px}.metrics{font-size:12px;color:#9fb0c7;font-weight:600}footer{padding:10px 16px;color:#9fb0c7;font-size:13px;background:#0d1b2d}.auth{display:none;width:min(420px,calc(100% - 32px));margin:auto;padding:18px;border:1px solid #28405d;border-radius:16px;background:#0d1b2d}.auth input{width:100%;margin:12px 0;padding:12px;border-radius:12px;border:1px solid #38516f;background:#07111f;color:#fff;font-size:16px}.auth button{width:100%;padding:12px;border:0;border-radius:12px;background:#39c982;color:#06150e;font-weight:900}.error{color:#ff8b95;font-size:13px;min-height:18px}
</style>
</head>
<body>
<header><span>Vigia IA</span><span>•</span><span id="state" class="state">conectando…</span><span id="metrics" class="metrics"></span></header>
<main>
  <div id="empty" class="empty">Conectando ao monitor local…</div>
  <img id="frame" alt="Monitor ao vivo">
  <form id="auth" class="auth"><strong>Chave da sessão</strong><div>Digite a chave exibida no Vigia IA.</div><input id="key" autocomplete="off" autocapitalize="characters" spellcheck="false" placeholder="Chave"><button type="submit">CONECTAR</button><div id="authError" class="error"></div></form>
</main>
<footer>Funciona somente na mesma rede local. O estado verde aparece apenas quando imagens recentes estão chegando.</footer>
<script>
const state=document.getElementById('state'),metrics=document.getElementById('metrics'),img=document.getElementById('frame'),empty=document.getElementById('empty'),auth=document.getElementById('auth'),keyInput=document.getElementById('key'),authError=document.getElementById('authError');let lastSeq=-1,timer=null;
function setState(text,kind=''){state.textContent=text;state.className='state '+kind}
function showAuth(msg=''){auth.style.display='block';img.style.display='none';empty.style.display='none';authError.textContent=msg;setState('autenticação necessária','bad');metrics.textContent=''}
async function createSession(key){const r=await fetch('/session',{method:'POST',headers:{'X-Vigia-Key':key},cache:'no-store'});if(!r.ok)throw new Error('Chave inválida.');history.replaceState(null,'',location.pathname);auth.style.display='none';authError.textContent='';await poll()}
async function poll(){try{const r=await fetch('/status',{cache:'no-store'});if(r.status===401){showAuth();return}if(!r.ok)throw new Error('status');const s=await r.json();metrics.textContent=Number(s.fps||0).toFixed(1)+' FPS • '+(s.viewers||0)+' cliente(s)';if(s.framesActive){setState('imagem ao vivo','ok');empty.style.display='none';if(s.sequence!==lastSeq){lastSeq=s.sequence;img.onload=()=>{img.style.display='block'};img.onerror=()=>{img.style.display='none';empty.style.display='block';empty.textContent='O quadro não pôde ser carregado.'};img.src='/frame.jpg?v='+encodeURIComponent(s.sequence)}}else{img.style.display='none';empty.style.display='block';empty.textContent=s.lastFrameAt?'Imagem interrompida. Aguardando novos frames…':'Aguardando o primeiro frame do monitor…';setState(s.lastFrameAt?'imagem interrompida':'aguardando imagem',s.lastFrameAt?'bad':'')} }catch(e){img.style.display='none';empty.style.display='block';empty.textContent='Conexão com o Vigia IA perdida. Tentando reconectar…';setState('sem conexão','bad');metrics.textContent=''}finally{clearTimeout(timer);timer=setTimeout(poll,900)}}
auth.addEventListener('submit',async e=>{e.preventDefault();authError.textContent='';try{await createSession(keyInput.value.trim())}catch(err){showAuth('Chave inválida. Confira no Vigia IA.')}});
(async()=>{const hash=new URLSearchParams(location.hash.replace(/^#/,''));const query=new URLSearchParams(location.search);const key=hash.get('key')||query.get('key');if(key){try{await createSession(key);return}catch(e){showAuth('A chave automática não foi aceita.')}}poll()})();
</script>
</body>
</html>''');
    await request.response.close();
  }

  Future<void> _serveStatus(HttpRequest request) async {
    final now = DateTime.now();
    final last = _lastFrameAt;
    final framesActive = last != null &&
        !now.difference(last).isNegative &&
        now.difference(last) <= _frameFreshness;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(<String, Object?>{
      'serverActive': running,
      'framesActive': framesActive,
      'lastFrameAt': last?.toIso8601String(),
      'sequence': _frameSequence,
      'fps': framesActive ? _streamFps : 0,
      'viewers': connectedViewers,
      'device': _deviceTelemetry,
      'bikeMode': _bikeModeEnabled,
      'bikeProfile': _bikeProfile,
      'name': 'Vigia IA - monitor local',
    }));
    await request.response.close();
  }

  Future<void> _serveSingleFrame(HttpRequest request) async {
    final jpeg = _latestJpeg;
    if (jpeg == null || !framesFresh) {
      request.response
        ..statusCode = HttpStatus.serviceUnavailable
        ..headers.contentType = ContentType.text
        ..write('Aguardando quadro recente do monitor.');
    } else {
      request.response.headers.contentType = ContentType('image', 'jpeg');
      request.response.add(jpeg);
    }
    await request.response.close();
  }

  Future<void> stop() async {
    await _closeServerOnly();
    _sessionCleanupTimer?.cancel();
    _sessionCleanupTimer = null;
    _sessions.clear();
    _latestJpeg = null;
    _lastFrameAt = null;
    _lastEncodedAt = null;
    _baseAddress = null;
    _accessKey = '';
    _frameSequence = 0;
    _streamFps = 0;
    _lastPublishAttemptAt = null;
    _deviceTelemetry = null;
    _lastReportedViewers = 0;
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

  String _generateKey(int length) {
    final random = Random.secure();
    return List<String>.generate(
      length,
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
  final maxWidth = data['maxWidth']! as int;
  final quality = data['quality']! as int;
  if (image.width > maxWidth) image = img.copyResize(image, width: maxWidth);
  return Uint8List.fromList(img.encodeJpg(image, quality: quality));
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
