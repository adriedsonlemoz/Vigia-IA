/// QR do Minha Câmera 1.4.35: URL MJPEG privada, sem redirecionamento.
/// Rejeita servidores públicos, DNS, credenciais e qualquer rota arbitrária.
class MinhaCameraLiveUrl {
  const MinhaCameraLiveUrl._();

  static final RegExp _pattern = RegExp(
    r'^http://([0-9]{1,3}\.){3}[0-9]{1,3}:[0-9]{1,5}/live/[0-9a-f]{32}$',
  );

  static Uri? parse(String input) {
    final value = input.trim();
    if (value.length < 35 || value.length > 160 || !_pattern.hasMatch(value)) {
      return null;
    }
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'http' || uri.userInfo.isNotEmpty ||
        !uri.hasPort || uri.port < 1 || uri.port > 65535 ||
        uri.hasQuery || uri.hasFragment) {
      return null;
    }
    // Use o host textual: Uri pode normalizar zeros à esquerda em IPv4.
    final rawHost = value.substring('http://'.length, value.indexOf(':', 'http://'.length));
    final parts = rawHost.split('.');
    if (parts.length != 4) return null;
    final octets = <int>[];
    for (final part in parts) {
      if (part.length > 1 && part.startsWith('0')) return null;
      final octet = int.tryParse(part);
      if (octet == null || octet < 0 || octet > 255) return null;
      octets.add(octet);
    }
    final local = octets[0] == 10 ||
        (octets[0] == 172 && octets[1] >= 16 && octets[1] <= 31) ||
        (octets[0] == 192 && octets[1] == 168) ||
        (octets[0] == 169 && octets[1] == 254) ||
        (octets[0] == 100 && octets[1] >= 64 && octets[1] <= 127);
    return local ? uri : null;
  }

  static bool isValid(String? input) => input != null && parse(input) != null;

  static String? accessToken(String? input) {
    final uri = input == null ? null : parse(input);
    return uri?.pathSegments.last;
  }
}
