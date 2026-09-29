import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Situação da chave do Google Maps no aparelho.
class GoogleMapsKeyStatus {
  const GoogleMapsKeyStatus({
    required this.configured,
    required this.source,
    required this.masked,
  });

  static const GoogleMapsKeyStatus none = GoogleMapsKeyStatus(
    configured: false,
    source: 'none',
    masked: '',
  );

  final bool configured;

  /// `user` (digitada pelo usuário), `build` (embutida no APK) ou `none`.
  final String source;
  final String masked;

  bool get isUserKey => source == 'user';
}

/// Guarda a chave do Google Maps de cada usuário (criptografada no Android
/// Keystore) e informa se o mapa Google pode ser aberto com segurança.
///
/// Sem chave, o Maps SDK derruba o app ao criar o mapa. Por isso a tela de mapa
/// consulta [hasKey] antes de montar o `GoogleMap`.
class GoogleMapsKeyService extends ChangeNotifier {
  GoogleMapsKeyService._();

  static final GoogleMapsKeyService instance = GoogleMapsKeyService._();

  static const MethodChannel _channel = MethodChannel('vigiaia/native');

  GoogleMapsKeyStatus _status = GoogleMapsKeyStatus.none;
  bool _initialized = false;

  GoogleMapsKeyStatus get status => _status;
  bool get hasKey => _status.configured;
  bool get initialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    await refresh();
  }

  Future<void> refresh() async {
    _status = await _readStatus();
    _initialized = true;
    notifyListeners();
  }

  /// Salva a chave. Texto vazio remove a chave do usuário.
  Future<GoogleMapsKeyStatus> save(String value) async {
    if (!Platform.isAndroid) return _status;
    final result = await _channel.invokeMapMethod<String, Object?>(
      'setGoogleMapsApiKey',
      <String, Object?>{'value': value.trim()},
    );
    _status = _parse(result);
    _initialized = true;
    notifyListeners();
    return _status;
  }

  Future<String?> reveal() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('revealGoogleMapsApiKey');
    } catch (_) {
      return null;
    }
  }

  /// Validação leve de formato; só o Google confirma se a chave é válida.
  static String? validate(String value) {
    final text = value.trim();
    if (text.isEmpty) return 'Cole a chave da API.';
    if (RegExp(r'\s').hasMatch(text)) return 'A chave não pode conter espaços.';
    if (text.length < 30) return 'A chave parece curta demais.';
    if (!text.startsWith('AIza')) {
      return 'Chaves do Google costumam começar com "AIza". Confira se copiou a chave certa.';
    }
    return null;
  }

  Future<GoogleMapsKeyStatus> _readStatus() async {
    if (!Platform.isAndroid) return GoogleMapsKeyStatus.none;
    try {
      final result = await _channel
          .invokeMapMethod<String, Object?>('googleMapsKeyStatus');
      return _parse(result);
    } catch (_) {
      return GoogleMapsKeyStatus.none;
    }
  }

  GoogleMapsKeyStatus _parse(Map<String, Object?>? data) {
    if (data == null) return GoogleMapsKeyStatus.none;
    return GoogleMapsKeyStatus(
      configured: data['configured'] == true,
      source: (data['source'] as String?) ?? 'none',
      masked: (data['masked'] as String?) ?? '',
    );
  }
}
