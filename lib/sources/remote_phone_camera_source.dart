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
  bool _disposed = false;
  bool _hasConnected = false;
  int _consecutiveFailures = 0;
  int? _lastFrameSequence;
  DateTime? _lastRemoteCapturedAt;
  int? _frameNetworkLatencyMs;
  final ValueNotifier<RemotePhoneStatus?> remoteStatusNotifier =
      ValueNotifier<RemotePhoneStatus?>(null);

  RemotePhoneStatus? get remoteStatus => remoteStatusNotifier.value;
  int? get frameNetworkLatencyMs => _frameNetworkLatencyMs;

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
    _client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    _statuses.add(VideoSourceStatus(
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
    final normalizedMs = analysisInterval.inMilliseconds.clamp(250, 400).toInt();
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
        _frameNetworkLatencyMs =
            DateTime.now().difference(startedAt).inMilliseconds;
        _hasConnected = true;
        _consecutiveFailures = 0;
        if (!_statuses.isClosed) {
          _statuses.add(VideoSourceStatus(
            VideoSourceState.streaming,
            message: '${_sentenceCase(deviceLabel)} online',
          ));
        }
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
      final receivedAt = DateTime.now();
      _frameNetworkLatencyMs = receivedAt.difference(startedAt).inMilliseconds;
      _latestJpeg.value = bytes;
      final isDuplicateSequence =
          sequence != null && _lastFrameSequence != null && sequence <= _lastFrameSequence!;
      final isDuplicateTimestamp = sequence == null &&
          capturedAt != null &&
          _lastRemoteCapturedAt != null &&
          !capturedAt.isAfter(_lastRemoteCapturedAt!);
      if (isDuplicateSequence || isDuplicateTimestamp) {
        _hasConnected = true;
        _consecutiveFailures = 0;
        if (!_statuses.isClosed) {
          _statuses.add(VideoSourceStatus(
            VideoSourceState.streaming,
            message: '${_sentenceCase(deviceLabel)} online',
          ));
        }
        return;
      }
      final frameCapturedAt = capturedAt ?? receivedAt;
      _lastFrameSequence = sequence ?? _lastFrameSequence;
      _lastRemoteCapturedAt = frameCapturedAt;
      if (emitFrames) {
        final decodeWatch = Stopwatch()..start();
        final decoded = await compute<Uint8List, Map<String, Object>?>(_decodeJpeg, bytes);
        decodeWatch.stop();
        if (decoded != null && !_frames.isClosed) {
          _frames.add(RgbFrame(
            width: decoded['width']! as int,
            height: decoded['height']! as int,
            rgbBytes: decoded['bytes']! as Uint8List,
            capturedAt: frameCapturedAt,
            sourceConversionMs: decodeWatch.elapsedMicroseconds / 1000.0,
            sourceTransportMs: _frameNetworkLatencyMs?.toDouble(),
          ));
        }
      }
      _hasConnected = true;
      _consecutiveFailures = 0;
      if (!_statuses.isClosed) {
        _statuses.add(VideoSourceStatus(
          VideoSourceState.streaming,
          message: '${_sentenceCase(deviceLabel)} online',
        ));
      }
    } catch (error) {
      _consecutiveFailures++;
      if (!_statuses.isClosed) {
        final state = _hasConnected || _consecutiveFailures <= 3
            ? VideoSourceState.reconnecting
            : VideoSourceState.error;
        final prefix = state == VideoSourceState.reconnecting
            ? 'Reconectando ao $deviceLabel'
            : '${_sentenceCase(deviceLabel)} offline';
        _statuses.add(VideoSourceStatus(state, message: '$prefix: $error'));
      }
    } finally {
      _busy = false;
      _scheduleNextPoll();
    }
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
    _statusBusy = false;
    remoteStatusNotifier.value = null;
    if (!_statuses.isClosed) {
      _statuses.add(const VideoSourceStatus(VideoSourceState.stopped));
    }
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
    'bytes': Uint8List.fromList(rgb),
  };
}
