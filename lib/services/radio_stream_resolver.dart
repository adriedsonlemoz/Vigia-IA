import 'dart:convert';
import 'dart:io';

/// Resolve URLs de playlist (`.pls` e `.m3u`) para o endereço direto do stream.
///
/// O player nativo toca o stream direto (MP3/AAC/Ogg/HLS), mas não interpreta
/// playlists de texto. Muitas estações do catálogo publicam esse tipo de link.
class RadioStreamResolver {
  const RadioStreamResolver._();

  static const int _maxPlaylistBytes = 64 * 1024;

  /// `true` quando a URL parece uma playlist de texto (e não um stream).
  /// `.m3u8` é HLS e é tocado diretamente pelo player.
  static bool looksLikePlaylist(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    final path = uri.path.toLowerCase();
    return path.endsWith('.pls') || path.endsWith('.m3u');
  }

  /// Extrai a primeira URL HTTP(S) de um conteúdo PLS ou M3U.
  static String? parsePlaylist(String body) {
    for (final rawLine in const LineSplitter().convert(body)) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#') || line.startsWith('[')) continue;
      final lower = line.toLowerCase();
      final String candidate;
      if (lower.startsWith('http://') || lower.startsWith('https://')) {
        candidate = line;
      } else {
        final separator = line.indexOf('=');
        if (separator <= 0) continue;
        final key = lower.substring(0, separator).trim();
        if (!key.startsWith('file')) continue;
        candidate = line.substring(separator + 1).trim();
      }
      final uri = Uri.tryParse(candidate);
      if (uri == null ||
          (uri.scheme != 'http' && uri.scheme != 'https') ||
          uri.host.isEmpty) {
        continue;
      }
      return uri.toString();
    }
    return null;
  }

  /// Devolve a URL direta do stream. Se não for playlist, ou se a playlist não
  /// puder ser lida, devolve a URL original.
  static Future<String> resolve(
    String url, {
    HttpClient? client,
    int maxDepth = 2,
  }) async {
    var current = url.trim();
    if (!looksLikePlaylist(current)) return current;
    final http = client ?? HttpClient();
    try {
      for (var depth = 0;
          depth < maxDepth && looksLikePlaylist(current);
          depth++) {
        String? body;
        try {
          body = await _fetchText(http, Uri.parse(current));
        } catch (_) {
          body = null;
        }
        if (body == null) break;
        final next = parsePlaylist(body);
        if (next == null) break;
        current = next;
      }
      return current;
    } finally {
      if (client == null) http.close(force: true);
    }
  }

  static Future<String> _fetchText(HttpClient client, Uri uri) async {
    final request =
        await client.getUrl(uri).timeout(const Duration(seconds: 8));
    request.headers.set(HttpHeaders.userAgentHeader, 'VigiaIA-Radio');
    final response = await request.close().timeout(const Duration(seconds: 10));
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw HttpException('Playlist respondeu ${response.statusCode}.');
    }
    final bytes = <int>[];
    await for (final chunk in response.timeout(const Duration(seconds: 10))) {
      bytes.addAll(chunk);
      if (bytes.length > _maxPlaylistBytes) break;
    }
    return utf8.decode(bytes, allowMalformed: true);
  }
}
