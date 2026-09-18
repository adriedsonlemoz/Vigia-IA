class RemoteCameraPairingData {
  const RemoteCameraPairingData({
    required this.address,
    required this.accessKey,
    this.name = 'Celular remoto',
  });

  final String address;
  final String accessKey;
  final String name;
}

class RemoteCameraPairingService {
  const RemoteCameraPairingService._();

  static const String scheme = 'vigiaia';
  static const String host = 'pair';
  static const String version = '1';
  static const String type = 'phone';

  static String encode(RemoteCameraPairingData data) {
    final address = _normalizeAddress(data.address);
    final key = data.accessKey.trim();
    _validateAddress(address);
    _validateKey(key);
    return Uri(
      scheme: scheme,
      host: host,
      queryParameters: <String, String>{
        'v': version,
        'type': type,
        'address': address,
        'key': key,
        'name': data.name.trim().isEmpty ? 'Celular remoto' : data.name.trim(),
      },
    ).toString();
  }

  static RemoteCameraPairingData decode(String rawValue) {
    final raw = rawValue.trim();
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        uri.scheme.toLowerCase() != scheme ||
        uri.host.toLowerCase() != host) {
      throw const FormatException('QR não pertence ao Vigia IA.');
    }
    if (uri.queryParameters['v'] != version ||
        uri.queryParameters['type'] != type) {
      throw const FormatException('Versão de pareamento não suportada.');
    }

    final address = _normalizeAddress(uri.queryParameters['address'] ?? '');
    final key = (uri.queryParameters['key'] ?? '').trim();
    final name = (uri.queryParameters['name'] ?? '').trim();
    _validateAddress(address);
    _validateKey(key);

    return RemoteCameraPairingData(
      address: address,
      accessKey: key,
      name: name.isEmpty ? 'Celular remoto' : name,
    );
  }

  static String _normalizeAddress(String value) {
    var normalized = value.trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  static void _validateAddress(String value) {
    final uri = Uri.tryParse(value);
    final valid = uri != null &&
        (uri.scheme.toLowerCase() == 'http' || uri.scheme.toLowerCase() == 'https') &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        (uri.path.isEmpty || uri.path == '/');
    if (!valid) {
      throw const FormatException('Endereço local do celular inválido.');
    }
  }

  static void _validateKey(String value) {
    if (!RegExp(r'^[A-Za-z0-9]{8,64}$').hasMatch(value)) {
      throw const FormatException('Chave de sessão inválida.');
    }
  }
}
