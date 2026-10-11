import 'dart:io';

import 'package:flutter/services.dart';

/// Trilhas persistidas no Android antes de invocar o player nativo.
/// Nunca envia a URL RTSP, credenciais ou parâmetros de autenticação.
class RtspDiagnosticsService {
  RtspDiagnosticsService._();

  static final RtspDiagnosticsService instance = RtspDiagnosticsService._();
  static const MethodChannel _channel = MethodChannel('vigiaia/native');

  static String safeHost(String? address) {
    final uri = Uri.tryParse(address ?? '');
    return uri?.scheme.toLowerCase() == 'rtsp' ? uri?.host ?? '' : '';
  }

  Future<void> mark(String stage, {String? address}) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('markRtspStage', <String, Object?>{
        'stage': stage,
        'host': safeHost(address),
      });
    } catch (_) {
      // Telemetria nunca pode impedir a abertura ou encerramento do vídeo.
    }
  }

  Future<Map<String, Object?>> capture() async {
    if (!Platform.isAndroid) return const <String, Object?>{};
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>(
        'getRtspDiagnostics',
      );
      return raw ?? const <String, Object?>{};
    } catch (_) {
      return const <String, Object?>{};
    }
  }
}
