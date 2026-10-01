import 'dart:io';
import 'package:flutter/services.dart';

import 'radio_stream_resolver.dart';

class MapRadioService {
  const MapRadioService._();
  static const MethodChannel _channel = MethodChannel('vigiaia/radio');

  static Future<void> play({
    required String name,
    required String url,
    double volume = 0.8,
    int bitrateKbps = 0,
  }) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      throw const FormatException('Informe a URL HTTP(S) direta do áudio.');
    }
    if (!Platform.isAndroid) throw const FormatException('Rádio disponível no Android.');
    // Playlists .pls/.m3u são convertidas no endereço direto do stream; o player
    // nativo só toca streams.
    final resolved = await RadioStreamResolver.resolve(uri.toString());
    final streamUri = Uri.tryParse(resolved);
    if (streamUri == null ||
        (streamUri.scheme != 'https' && streamUri.scheme != 'http') ||
        streamUri.host.isEmpty) {
      throw const FormatException('Informe a URL HTTP(S) direta do áudio.');
    }
    await _channel.invokeMethod<bool>('play', <String, Object>{
      'name': name.trim(),
      'url': streamUri.toString(),
      'volume': volume.clamp(0.0, 1.0).toDouble(),
      'bitrate': bitrateKbps.clamp(0, 1024).toInt(),
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
        bitrateKbps: 0, estimatedBytes: 0, nowPlaying: '',
      );
    }
    final value = await _channel.invokeMethod<Map<Object?, Object?>>('status');
    return MapRadioPlaybackStatus(
      state: value?['state'] as String? ?? 'parado',
      station: value?['station'] as String? ?? '',
      url: value?['url'] as String? ?? '',
      volume: (value?['volume'] as num?)?.toDouble() ?? 0.8,
      bitrateKbps: (value?['bitrate'] as num?)?.toInt() ?? 0,
      estimatedBytes: (value?['estimatedBytes'] as num?)?.toInt() ?? 0,
      nowPlaying: value?['nowPlaying'] as String? ?? '',
    );
  }
}

class MapRadioPlaybackStatus {
  const MapRadioPlaybackStatus({
    required this.state,
    required this.station,
    required this.url,
    required this.volume,
    required this.bitrateKbps,
    required this.estimatedBytes,
    this.nowPlaying = '',
  });

  final String state;
  final String station;
  final String url;
  final double volume;
  final int bitrateKbps;
  final int estimatedBytes;

  /// Música/artista informados pelo stream (metadados ICY); vazio se não houver.
  final String nowPlaying;
}
