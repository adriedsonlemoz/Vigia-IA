import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;

import '../core/video_source.dart';
import '../core/video_source_status.dart';
import '../models/remote_phone_status.dart';
import '../models/rgb_frame.dart';
import '../services/data_usage_service.dart';

class RemotePhoneCameraSource implements VideoSource {
  RemotePhoneCameraSource({
    required this.baseUrl,
    required this.accessKey,
    this.analysisInterval = const Duration(milliseconds: 800),
    this.emitFrames = true,
    this.deviceLabel = 'celular remoto',
  });

  final String baseUrl;
  final String accessKey;
  final Duration analysisInterval;
  final bool emitFrames;
  final String deviceLabel;
  final StreamController<RgbFrame> _frames = StreamController<RgbFrame>.broadcast();
  final StreamController<VideoSourceStatus> _statuses = StreamController<VideoSourceStatus>.broadcast();
  final ValueNotifier<Uint8List?> _latestJpeg = ValueNotifier<Uint8List?>(null);
  HttpClient? _client;
  Timer? _pollTimer;
  Timer? _statusTimer;
  bool _busy = false;
  bool _statusBusy = false;
  bool _analysisBusy = false;
  int _analysisGeneration = 0;
  DateTime? _lastAnalysisStartedAt;
  bool _disposed = false;
  bool _hasConnected = false;
  int _consecutiveFailures = 0;
  VideoSourceState? _lastPublishedState;
  String? _lastPublishedMessage;
  int? _lastFrameSequence;
  DateTime? _lastRemoteCapturedAt;
  int? _frameNetworkLatencyMs;
  double? _previewAspectRatio;
  DateTime _lastAspectRatioProbe = DateTime.fromMillisecondsSinceEpoch(0);
  final ValueNotifier<RemotePhoneStatus?> remoteStatusNotifier =
      ValueNotifier<RemotePhoneStatus?>(null);

  RemotePhoneStatus? get remoteStatus => remoteStatusNotifier.value;
  int? get frameNetworkLatencyMs => _frameNetworkLatencyMs;
  double? get previewAspectRatio => _previewAspectRatio;

  @override
  Stream<RgbFrame> get frames => _frames.stream;

  @override
  Stream<VideoSourceStatus> get statuses => _statuses.stream;

  @override
  Future<void> start() async {
    if (_disposed) return;
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host.isEmpty) {
      throw ArgumentError('Endereço do $deviceLabel inválido.');
    }
    _analysisGeneration++;
    _analysisBusy = false;
    _lastAnalysisStartedAt = null;
    _client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    _publishStatus(VideoSourceStatus(
      VideoSourceState.connecting,
      message: 'Conectando ao $deviceLabel…',
    ));
    unawaited(_poll());
    unawaited(_pollStatus());
    _statusTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_pollStatus()),
    );
  }

  Duration get _framePollInterval {
    // Preview não deve esperar a análise de IA, que tem cadência separada.
    final normalizedMs = analysisInterval.inMilliseconds.clamp(200, 250).toInt();
    return Duration(milliseconds: normalizedMs);
  }

  void _scheduleNextPoll([Duration? delay]) {
    if (_disposed || _client == null) return;
    _pollTimer?.cancel();
    _pollTimer = Timer(delay ?? _framePollInterval, () => unawaited(_poll()));
  }

  Future<void> _poll() async {
    if (_busy || _disposed || _client == null) return;
    _busy = true;
    final pollGeneration = _analysisGeneration;
    final startedAt = DateTime.now();
    try {
      final root = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
      final query = <String, String>{
        'key': accessKey,
        't': startedAt.millisecondsSinceEpoch.toString(),
        if (_lastFrameSequence != null) 'after': _lastFrameSequence.toString(),
      };
      final uri = Uri.parse('$root/frame.jpg').replace(queryParameters: query);
      final request = await _client!.getUrl(uri);
      request.headers
        ..set(HttpHeaders.cacheControlHeader, 'no-store')
        ..set(HttpHeaders.pragmaHeader, 'no-cache');
      final response = await request.close().timeout(const Duration(seconds: 5));
      if (response.statusCode == HttpStatus.noContent) {
        await response.drain<void>();
        if (pollGeneration != _analysisGeneration || _disposed) return;
        _frameNetworkLatencyMs =
            DateTime.now().difference(startedAt).inMilliseconds;
        _hasConnected = true;
        _consecutiveFailures = 0;
        _publishStatus(VideoSourceStatus(
          VideoSourceState.streaming,
          message: '${_sentenceCase(deviceLabel)} online',
        ));
        return;
      }
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      final capturedAt = DateTime.tryParse(
        response.headers.value('x-vigia-frame-captured-at') ?? '',
      );
      final sequence = int.tryParse(
        response.headers.value('x-vigia-frame-sequence') ?? '',
      );
      final bytes = await consolidateHttpClientResponseBytes(response);
      DataUsageService.instance.record(
        DataUsageModule.cameras,
        received: bytes.length,
      );
      if (pollGeneration != _analysisGeneration || _disposed) return;
      final receivedAt = DateTime.now();
      _frameNetworkLatencyMs = receivedAt.difference(startedAt).inMilliseconds;
      if (!emitFrames &&
          (_previewAspectRatio == null ||
              receivedAt.difference(_lastAspectRatioProbe) >=
                  const Duration(seconds: 2))) {
        _lastAspectRatioProbe = receivedAt;
        final ratio = _decodeJpegAspectRatio(bytes);
        if (ratio != null && ratio.isFinite && ratio > 0) {
          _previewAspectRatio = ratio;
        }
      }
      final isDuplicateSequence =
          sequence != null && _lastFrameSequence != null && sequence <= _lastFrameSequence!;
      final isDuplicateTimestamp = sequence == null &&
          capturedAt != null &&
          _lastRemoteCapturedAt != null &&
          !capturedAt.isAfter(_lastRemoteCapturedAt!);
      if (isDuplicateSequence || isDuplicateTimestamp) {
        _hasConnected = true;
        _consecutiveFailures = 0;
        _publishStatus(VideoSourceStatus(
          VideoSourceState.streaming,
          message: '${_sentenceCase(deviceLabel)} online',
        ));
        return;
      }
      final frameCapturedAt = capturedAt ?? receivedAt;
      _lastFrameSequence = sequence ?? _lastFrameSequence;
      _lastRemoteCapturedAt = frameCapturedAt;
      _latestJpeg.value = bytes;
      if (emitFrames && !_analysisBusy &&
          (_lastAnalysisStartedAt == null ||
              receivedAt.difference(_lastAnalysisStartedAt!) >= analysisInterval)) {
        _analysisBusy = true;
        _lastAnalysisStartedAt = receivedAt;
        unawaited(_emitAnalysisFrame(
          bytes,
          frameCapturedAt,
          _frameNetworkLatencyMs?.toDouble(),
          _analysisGeneration,
        ));
      }
      _hasConnected = true;
      _consecutiveFailures = 0;
      _publishStatus(VideoSourceStatus(
        VideoSourceState.streaming,
        message: '${_sentenceCase(deviceLabel)} online',
      ));
    } catch (error) {
      if (pollGeneration != _analysisGeneration || _disposed) return;
      _consecutiveFailures++;
      final state = _hasConnected || _consecutiveFailures <= 3
          ? VideoSourceState.reconnecting
          : VideoSourceState.error;
      final prefix = state == VideoSourceState.reconnecting
          ? 'Reconectando ao $deviceLabel'
          : '${_sentenceCase(deviceLabel)} offline';
      _publishStatus(VideoSourceStatus(state, message: '$prefix: $error'));
    } finally {
      _busy = false;
      _scheduleNextPoll();
    }
  }

  Future<void> _emitAnalysisFrame(
    Uint8List jpeg,
    DateTime capturedAt,
    double? transportMs,
    int generation,
  ) async {
    final decodeWatch = Stopwatch()..start();
    try {
      final decoded = await compute<Uint8List, Map<String, Object>?>(_decodeJpeg, jpeg);
      decodeWatch.stop();
      if (generation != _analysisGeneration || _disposed || _frames.isClosed) return;
      if (decoded != null) {
        _frames.add(RgbFrame(
          width: decoded['width']! as int,
          height: decoded['height']! as int,
          rgbBytes: decoded['bytes']! as Uint8List,
          capturedAt: capturedAt,
          sourceConversionMs: decodeWatch.elapsedMicroseconds / 1000.0,
          sourceTransportMs: transportMs,
        ));
      }
    } catch (_) {
      // Quadro isolado ilegível não bloqueia o preview nem próximas análises.
    } finally {
      if (generation == _analysisGeneration) _analysisBusy = false;
    }
  }

  void _publishStatus(VideoSourceStatus status) {
    if (_statuses.isClosed) return;
    if (_lastPublishedState == status.state &&
        _lastPublishedMessage == status.message) {
      return;
    }
    _lastPublishedState = status.state;
    _lastPublishedMessage = status.message;
    _statuses.add(status);
  }

  Future<void> _pollStatus() async {
    if (_statusBusy || _disposed || _client == null) return;
    _statusBusy = true;
    final startedAt = DateTime.now();
    try {
      final root = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;
      final request = await _client!.getUrl(Uri.parse('$root/status'));
      request.headers.set('x-monitor-key', accessKey);
      final response = await request.close().timeout(const Duration(seconds: 5));
      if (response.statusCode != HttpStatus.ok) return;
      final bytes = await consolidateHttpClientResponseBytes(response);
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) return;
      remoteStatusNotifier.value = RemotePhoneStatus.fromJson(
        Map<String, dynamic>.from(decoded),
        receivedAt: DateTime.now(),
        networkLatencyMs: DateTime.now().difference(startedAt).inMilliseconds,
      );
    } catch (_) {
      // Telemetria é complementar: uma falha de /status não derruba o vídeo.
    } finally {
      _statusBusy = false;
    }
  }

  @override
  Widget buildPreview() => ValueListenableBuilder<Uint8List?>(
        valueListenable: _latestJpeg,
        builder: (context, bytes, _) {
          if (bytes == null) {
            return Center(child: Text('Aguardando imagem do $deviceLabel…'));
          }
          return Center(
            child: Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true),
          );
        },
      );

  @override
  Future<void> stop() async {
    _analysisGeneration++;
    _analysisBusy = false;
    _lastAnalysisStartedAt = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _statusTimer?.cancel();
    _statusTimer = null;
    _client?.close(force: true);
    _client = null;
    _hasConnected = false;
    _consecutiveFailures = 0;
    _lastFrameSequence = null;
    _lastRemoteCapturedAt = null;
    _frameNetworkLatencyMs = null;
    _previewAspectRatio = null;
    _statusBusy = false;
    remoteStatusNotifier.value = null;
    _publishStatus(const VideoSourceStatus(VideoSourceState.stopped));
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
    _latestJpeg.dispose();
    remoteStatusNotifier.dispose();
    await _frames.close();
    await _statuses.close();
  }
}

String _sentenceCase(String value) {
  if (value.isEmpty) return value;
  return '${value[0].toUpperCase()}${value.substring(1)}';
}

Map<String, Object>? _decodeJpeg(Uint8List bytes) {
  final image = img.decodeJpg(bytes);
  if (image == null) return null;
  final rgb = image.getBytes(order: img.ChannelOrder.rgb);
  return <String, Object>{
    'width': image.width,
    'height': image.height,
    'bytes': rgb,
  };
}


double? _decodeJpegAspectRatio(Uint8List bytes) {
  // Lê dimensões SOF do JPEG sem descomprimir todos os pixels.
  if (bytes.length < 4 || bytes[0] != 0xff || bytes[1] != 0xd8) return null;
  var i = 2;
  while (i + 3 < bytes.length) {
    if (bytes[i] != 0xff) return null;
    while (i < bytes.length && bytes[i] == 0xff) {
      i++;
    }
    if (i >= bytes.length) return null;
    final marker = bytes[i++];
    if (marker == 0xd9 || marker == 0xda) return null;
    if (marker == 0x01 || (marker >= 0xd0 && marker <= 0xd7)) continue;
    if (i + 1 >= bytes.length) return null;
    final length = (bytes[i] << 8) | bytes[i + 1];
    if (length < 2 || i + length > bytes.length) return null;
    final isSof = (marker >= 0xc0 && marker <= 0xc3) ||
        (marker >= 0xc5 && marker <= 0xc7) ||
        (marker >= 0xc9 && marker <= 0xcb) ||
        (marker >= 0xcd && marker <= 0xcf);
    if (isSof) {
      if (length < 7) return null;
      final height = (bytes[i + 3] << 8) | bytes[i + 4];
      final width = (bytes[i + 5] << 8) | bytes[i + 6];
      return width > 0 && height > 0 ? width / height : null;
    }
    i += length;
  }
  return null;
}
