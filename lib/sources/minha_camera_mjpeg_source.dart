import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;

import '../core/video_source.dart';
import '../core/video_source_status.dart';
import '../models/rgb_frame.dart';
import '../models/remote_phone_status.dart';
import '../services/mcrp_client.dart';
import '../services/minha_camera_telemetry.dart';
import '../services/data_usage_service.dart';
import '../services/minha_camera_live_url.dart';
import '../services/minha_camera_mjpeg_parser.dart';

/// Receptor somente de leitura do MJPEG do Minha Câmera 1.4.35.
/// O A3 transmite; o detector já existente do Vigia analisa no aparelho receptor.
class MinhaCameraMjpegSource implements VideoSource {
  MinhaCameraMjpegSource({
    required this.liveUrl,
    this.analysisInterval = const Duration(milliseconds: 800),
    this.emitFrames = true,
  });

  final String liveUrl;
  final Duration analysisInterval;
  final bool emitFrames;
  final StreamController<RgbFrame> _frames = StreamController<RgbFrame>.broadcast();
  final StreamController<VideoSourceStatus> _statuses = StreamController<VideoSourceStatus>.broadcast();
  final ValueNotifier<Uint8List?> _preview = ValueNotifier<Uint8List?>(null);
  HttpClient? _client;
  Timer? _retry;
  Timer? _telemetryTimer;
  McrpClient? _telemetryClient;
  bool _telemetryBusy = false;
  final ValueNotifier<RemotePhoneStatus?> remoteStatusNotifier =
      ValueNotifier<RemotePhoneStatus?>(null);
  RemotePhoneStatus? get remoteStatus => remoteStatusNotifier.value;
  bool _disposed = false;
  bool _decoding = false;
  int _generation = 0;
  int _failures = 0;
  DateTime? _lastPreview;
  DateTime? _lastAnalysis;
  VideoSourceState? _state;
  String? _message;

  @override
  Stream<RgbFrame> get frames => _frames.stream;
  @override
  Stream<VideoSourceStatus> get statuses => _statuses.stream;

  void _status(VideoSourceState state, String message) {
    if (_statuses.isClosed || (_state == state && _message == message)) return;
    _state = state;
    _message = message;
    _statuses.add(VideoSourceStatus(state, message: message));
  }

  @override
  Future<void> start() async {
    if (_disposed) return;
    if (MinhaCameraLiveUrl.parse(liveUrl) == null) {
      throw const FormatException('QR do Minha Câmera inválido ou fora da rede local.');
    }
    await stop();
    final generation = _generation;
    _client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5)
      ..autoUncompress = false;
    _status(VideoSourceState.connecting, 'Conectando ao Minha Câmera…');
    // A leitura de /status é opcional. Nenhuma falha de telemetria interrompe MJPEG.
    try {
      _telemetryClient = McrpClient(McrpAddress.parse(liveUrl));
      unawaited(_pollTelemetry(generation));
      _telemetryTimer = Timer.periodic(const Duration(seconds: 5),
          (_) => unawaited(_pollTelemetry(generation)));
    } on FormatException {
      // Endereço MJPEG válido, mas sem suporte ao contrato MCRP v1.
    }
    unawaited(_receive(generation));
  }

  Future<void> _receive(int generation) async {
    if (_disposed || generation != _generation) return;
    final client = _client;
    if (client == null) return;
    final parser = MinhaCameraMjpegParser();
    try {
      final request = await client.getUrl(MinhaCameraLiveUrl.parse(liveUrl)!);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      final response = await request.close().timeout(const Duration(seconds: 7));
      if (response.statusCode == HttpStatus.conflict) {
        await response.drain<void>();
        _status(VideoSourceState.error,
            'Minha Câmera está em H.264. Selecione MJPEG no transmissor.');
        return;
      }
      if (response.statusCode != HttpStatus.ok ||
          !(response.headers.contentType?.mimeType.toLowerCase() ==
              'multipart/x-mixed-replace')) {
        await response.drain<void>();
        throw const FormatException('Resposta MJPEG incompatível.');
      }
      var receivedAny = false;
      await for (final chunk in response.timeout(const Duration(seconds: 9))) {
        if (_disposed || generation != _generation) return;
        DataUsageService.instance.record(DataUsageModule.cameras, received: chunk.length);
        for (final jpeg in parser.add(chunk)) {
          if (_disposed || generation != _generation) return;
          receivedAny = true;
          _failures = 0;
          _status(VideoSourceState.streaming, emitFrames
              ? 'Minha Câmera online • IA no Vigia'
              : 'Minha Câmera online • somente vídeo');
          final now = DateTime.now();
          if (_lastPreview == null ||
              now.difference(_lastPreview!) >= const Duration(milliseconds: 100)) {
            _lastPreview = now;
            _preview.value = jpeg;
          }
          if (emitFrames && !_decoding &&
              (_lastAnalysis == null || now.difference(_lastAnalysis!) >= analysisInterval)) {
            _decoding = true;
            _lastAnalysis = now;
            unawaited(_emitRgb(jpeg, now, generation));
          }
        }
      }
      if (!receivedAny) throw const FormatException('Fluxo sem quadros JPEG.');
      throw const SocketException('Transmissão encerrada.');
    } catch (_) {
      if (_disposed || generation != _generation) return;
      _failures++;
      _status(VideoSourceState.reconnecting,
          'Reconectando ao Minha Câmera na rede local…');
      _retry?.cancel();
      _retry = Timer(Duration(seconds: (_failures * 2).clamp(2, 12).toInt()),
          () => unawaited(_receive(generation)));
    }
  }

  Future<void> _pollTelemetry(int generation) async {
    final client = _telemetryClient;
    if (_telemetryBusy || client == null || _disposed || generation != _generation) {
      return;
    }
    _telemetryBusy = true;
    final watch = Stopwatch()..start();
    try {
      final headers = await client.status();
      if (_disposed || generation != _generation) return;
      // Uma resposta sem esses campos não justifica atribuir dados fictícios.
      remoteStatusNotifier.value = MinhaCameraTelemetry.fromHeaders(
        headers,
        networkLatencyMs: watch.elapsedMilliseconds,
      );
    } catch (_) {
      // O vídeo funciona independentemente da API de telemetria.
      if (generation == _generation && remoteStatusNotifier.value != null &&
          remoteStatusNotifier.value!.isStale()) {
        remoteStatusNotifier.value = null;
      }
    } finally {
      _telemetryBusy = false;
    }
  }

  Future<void> _emitRgb(Uint8List jpeg, DateTime capturedAt, int generation) async {
    final stopwatch = Stopwatch()..start();
    try {
      final decoded = await compute<Uint8List, Map<String, Object>?>(
        _decodeMinhaCameraJpeg, jpeg,
      );
      if (_disposed || generation != _generation || _frames.isClosed || decoded == null) return;
      _frames.add(RgbFrame(
        width: decoded['width']! as int,
        height: decoded['height']! as int,
        rgbBytes: decoded['bytes']! as Uint8List,
        capturedAt: capturedAt,
        sourceConversionMs: stopwatch.elapsedMicroseconds / 1000.0,
      ));
    } catch (_) {
      // JPEG corrompido isolado não derruba o stream nem o preview.
    } finally {
      if (generation == _generation) _decoding = false;
    }
  }

  @override
  Widget buildPreview() => ValueListenableBuilder<Uint8List?>(
        valueListenable: _preview,
        builder: (context, bytes, _) => bytes == null
            ? const Center(child: Text('Aguardando vídeo do Minha Câmera…'))
            : Center(child: Image.memory(
                bytes, fit: BoxFit.contain, gaplessPlayback: true,
                filterQuality: FilterQuality.low,
              )),
      );

  @override
  Future<void> stop() async {
    _generation++;
    _retry?.cancel();
    _retry = null;
    _telemetryTimer?.cancel();
    _telemetryTimer = null;
    _telemetryClient?.close();
    _telemetryClient = null;
    remoteStatusNotifier.value = null;
    _client?.close(force: true);
    _client = null;
    _decoding = false;
    _lastPreview = null;
    _lastAnalysis = null;
    _preview.value = null;
    _failures = 0;
    _status(VideoSourceState.stopped, 'Minha Câmera desconectada');
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    await stop();
    _disposed = true;
    _preview.dispose();
    remoteStatusNotifier.dispose();
    await _frames.close();
    await _statuses.close();
  }
}

Map<String, Object>? _decodeMinhaCameraJpeg(Uint8List jpeg) {
  final image = img.decodeJpg(jpeg);
  if (image == null) return null;
  return <String, Object>{
    'width': image.width,
    'height': image.height,
    'bytes': image.getBytes(order: img.ChannelOrder.rgb),
  };
}
