import 'dart:convert';
import 'dart:io';

/// Minha Câmera Remote Protocol v1. Este cliente não altera o protocolo vigiaia://pair.
class McrpAddress {
  const McrpAddress(this.liveUrl);
  final Uri liveUrl;

  static McrpAddress parse(String raw) {
    var source = raw.trim();
    final candidate = Uri.tryParse(source);
    if (candidate?.scheme == 'mcrp' && candidate?.host == 'pair') {
      source = candidate!.queryParameters['url'] ?? '';
    }
    final uri = Uri.tryParse(source);
    if (uri == null || uri.scheme != 'http' || uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty || uri.fragment.isNotEmpty || uri.port != 8765 ||
        !RegExp(r'^/live/[0-9a-f]{32}$').hasMatch(uri.path) ||
        !_isLocalIpv4(uri.host)) {
      throw const FormatException('Informe o QR ou URL privada /live/ do Minha Câmera na rede local.');
    }
    return McrpAddress(uri);
  }

  static bool _isLocalIpv4(String host) {
    final parts = host.split('.');
    if (parts.length != 4 || parts.any((p) => p.isEmpty ||
        (p.length > 1 && p.startsWith('0')) || int.tryParse(p) == null ||
        int.parse(p) > 255 || int.parse(p) < 0)) {
      return false;
    }
    final a = int.parse(parts[0]); final b = int.parse(parts[1]);
    return a == 10 || (a == 172 && b >= 16 && b <= 31) ||
        (a == 192 && b == 168) || (a == 169 && b == 254) ||
        (a == 100 && b >= 64 && b <= 127);
  }

  String get token => liveUrl.pathSegments.last;
  Uri get h264 => liveUrl.replace(path: '/h264/$token');
  Uri control(String suffix) => liveUrl.replace(path: '/control/$token/$suffix');
  Uri get info => control('mcrp/info');
  Uri get status => control('status');
  Uri get media => control('mcrp/media');
  Uri mediaFile(String id) {
    if (!RegExp(r'^[A-Za-z0-9._-]{1,180}$').hasMatch(id)) {
      throw const FormatException('Identificador de mídia inválido.');
    }
    return control('mcrp/media/$id');
  }
}

class McrpMediaItem {
  const McrpMediaItem({required this.id, required this.name, required this.mime,
      required this.size, required this.modified});
  final String id, name, mime;
  final int size, modified;
  factory McrpMediaItem.fromJson(Map<String, dynamic> j) => McrpMediaItem(
    id: j['id'] as String? ?? '', name: j['name'] as String? ?? '',
    mime: j['mime'] as String? ?? '', size: (j['size'] as num?)?.toInt() ?? 0,
    modified: (j['modified'] as num?)?.toInt() ?? 0,
  );
}

class McrpClient {
  // Somente ausência explícita da rota de negociação habilita o modo legado.
  // 401/403, indisponibilidade de rede e protocolo desconhecido NÃO o habilitam.
  static bool supportsLegacyFallback(Object error) =>
      error is HttpException && error.message == 'MCRP HTTP 404';

  McrpClient(this.address);
  final McrpAddress address;
  final HttpClient _http = HttpClient()..connectionTimeout = const Duration(seconds: 4);
  void close() => _http.close(force: true);

  Future<HttpClientResponse> _get(Uri uri) async {
    final request = await _http.getUrl(uri);
    request.followRedirects = false;
    request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    final response = await request.close().timeout(const Duration(seconds: 8));
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw HttpException('MCRP HTTP ${response.statusCode}');
    }
    return response;
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response = await _get(uri);
    final bytes = <int>[];
    await for (final chunk in response.timeout(const Duration(seconds: 8))) {
      bytes.addAll(chunk);
      if (bytes.length > 1_000_000) throw const FormatException('Resposta MCRP excessiva.');
    }
    final result = jsonDecode(utf8.decode(bytes));
    if (result is! Map<String, dynamic> || result['protocol'] != 'mcrp' || result['version'] != 1) {
      throw const FormatException('Protocolo MCRP incompatível.');
    }
    return result;
  }

  Future<Map<String, dynamic>> info() => _getJson(address.info);
  Future<List<McrpMediaItem>> media() async {
    final json = await _getJson(address.media);
    final rows = json['items'];
    if (rows is! List) throw const FormatException('Lista de mídia inválida.');
    return rows.whereType<Map<String, dynamic>>().map(McrpMediaItem.fromJson).toList();
  }

  Future<Map<String, String>> status() async {
    final response = await _get(address.status);
    final headers = <String, String>{};
    for (final name in <String>['x-stream-codec', 'x-device-model', 'x-resolution',
      'x-battery-level', 'x-battery-temp-tenths', 'x-recording', 'x-recording-seconds',
      'x-transmission-seconds', 'x-eco', 'x-camera-facing', 'x-quality-profile', 'x-fps-target']) {
      final value = response.headers.value(name);
      if (value != null) headers[name] = value;
    }
    await response.drain<void>();
    return headers;
  }

  Future<void> command(String action) async {
    const actions = <String>{'record/start', 'record/stop', 'eco/enable', 'eco/disable',
      'camera/back', 'camera/front', 'photo', 'codec/mjpeg', 'codec/h264',
      'quality/360', 'quality/480', 'quality/720', 'quality/768', 'quality/1080',
      'fps/5', 'fps/10', 'fps/15', 'fps/24', 'fps/30'};
    if (!actions.contains(action)) throw const FormatException('Comando não permitido pelo cliente.');
    final uri = address.control(action);
    final request = await _http.postUrl(uri);
    request.followRedirects = false;
    request.contentLength = 0;
    final response = await request.close().timeout(const Duration(seconds: 8));
    final reason = response.headers.value('x-control-reason');
    await response.drain<void>();
    if (response.statusCode != HttpStatus.noContent) {
      throw StateError(reason == 'recording-active'
          ? 'Pare REC antes de alterar esta configuração.'
          : reason == 'unsupported-mode' ? 'Comando indisponível neste modo.'
          : 'Comando rejeitado (HTTP ${response.statusCode}).');
    }
  }

  Future<String> diagnostic() async {
    final response = await _get(address.control('diagnostic'));
    final data = <int>[];
    await for (final chunk in response.timeout(const Duration(seconds: 8))) {
      data.addAll(chunk);
      if (data.length > 250_000) break;
    }
    return utf8.decode(data, allowMalformed: true);
  }

  Future<File> download(McrpMediaItem item, Directory directory) async {
    await directory.create(recursive: true);
    final name = item.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = '${directory.path}/${DateTime.now().millisecondsSinceEpoch}_${name.isEmpty ? 'media.bin' : name}';
    final file = File(path);
    try {
      final response = await _get(address.mediaFile(item.id));
      final sink = file.openWrite();
      var received = 0;
      try {
        await for (final chunk in response.timeout(const Duration(seconds: 40))) {
          received += chunk.length;
          if (received > item.size + 4096 || received > 2 * 1024 * 1024 * 1024) {
            throw const FormatException('Arquivo excedeu o tamanho declarado.');
          }
          sink.add(chunk);
        }
      } finally { await sink.close(); }
      if (received != item.size) throw const FormatException('Download incompleto.');
      return file;
    } catch (_) {
      if (await file.exists()) await file.delete();
      rethrow;
    }
  }
}
