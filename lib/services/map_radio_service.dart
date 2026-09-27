import 'dart:io';
import 'package:flutter/services.dart';

class MapRadioService {
  const MapRadioService._();
  static const MethodChannel _channel = MethodChannel('vigiaia/radio');

  static Future<void> play({required String name, required String url}) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      throw const FormatException('Informe a URL HTTP(S) direta do áudio.');
    }
    if (!Platform.isAndroid) throw const FormatException('Rádio disponível no Android.');
    await _channel.invokeMethod<bool>('play', <String, String>{
      'name': name.trim(), 'url': uri.toString(),
    });
  }

  static Future<void> stop() async {
    if (Platform.isAndroid) await _channel.invokeMethod<bool>('stop');
  }

  static Future<String> status() async {
    if (!Platform.isAndroid) return 'parado';
    final value = await _channel.invokeMethod<Map<Object?, Object?>>('status');
    return value?['state'] as String? ?? 'parado';
  }
}
