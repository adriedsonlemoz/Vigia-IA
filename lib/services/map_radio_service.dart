import 'dart:io';
import 'package:flutter/services.dart';

class MapRadioService {
  const MapRadioService._();
  static const MethodChannel _channel = MethodChannel('vigiaia/radio');

  static Future<void> play({
    required String name,
    required String url,
    double volume = 0.8,
  }) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      throw const FormatException('Informe a URL HTTP(S) direta do áudio.');
    }
    if (!Platform.isAndroid) throw const FormatException('Rádio disponível no Android.');
    await _channel.invokeMethod<bool>('play', <String, Object>{
      'name': name.trim(),
      'url': uri.toString(),
      'volume': volume.clamp(0.0, 1.0).toDouble(),
    });
  }

  static Future<void> pause() async {
    if (Platform.isAndroid) await _channel.invokeMethod<bool>('pause');
  }

  static Future<void> resume() async {
    if (Platform.isAndroid) await _channel.invokeMethod<bool>('resume');
  }

  static Future<void> setVolume(double volume) async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod<bool>('setVolume', <String, double>{
        'volume': volume.clamp(0.0, 1.0).toDouble(),
      });
    }
  }

  static Future<void> stop() async {
    if (Platform.isAndroid) await _channel.invokeMethod<bool>('stop');
  }

  static Future<String> status() async {
    return (await statusDetails()).state;
  }

  static Future<MapRadioPlaybackStatus> statusDetails() async {
    if (!Platform.isAndroid) {
      return const MapRadioPlaybackStatus(
        state: 'parado', station: '', url: '', volume: 0.8,
      );
    }
    final value = await _channel.invokeMethod<Map<Object?, Object?>>('status');
    return MapRadioPlaybackStatus(
      state: value?['state'] as String? ?? 'parado',
      station: value?['station'] as String? ?? '',
      url: value?['url'] as String? ?? '',
      volume: (value?['volume'] as num?)?.toDouble() ?? 0.8,
    );
  }
}

class MapRadioPlaybackStatus {
  const MapRadioPlaybackStatus({
    required this.state,
    required this.station,
    required this.url,
    required this.volume,
  });

  final String state;
  final String station;
  final String url;
  final double volume;
}
