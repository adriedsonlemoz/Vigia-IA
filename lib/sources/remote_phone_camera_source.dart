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
  });

  final String baseUrl;
  final String accessKey;
  final Duration analysisInterval;
  final StreamController<RgbFrame> _frames = StreamController<RgbFrame>.broadcast();
  final StreamController<VideoSourceStatus> _statuses = StreamController<VideoSourceStatus>.broadcast();
  final ValueNotifier<Uint8List?> _latestJpeg = ValueNotifier<Uint8List?>(null);
  HttpClient? _client;
  Timer? _timer;
  Timer? _statusTimer;
  bool _busy = false;
  bool _statusBusy = false;
  bool _disposed = false;
  bool _hasConnected = false;
  int _consecutiveFailures = 0;
  final ValueNotifier<RemotePhoneStatus?> remoteStatusNotifier =
      ValueNotifier<RemotePhoneStatus?>(null);

  RemotePhoneStatus? get remoteStatus => remoteStatusNotifier.value;

  @override
  Stream<RgbFrame> get frames => _frames.stream;

  @override
  Stream<VideoSourceStatus> get statuses => _statuses.stream;

  @override
  Future<void> start() async {
    if (_disposed) return;
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host.isEmpty) {
      throw ArgumentError('Endereço do celular remoto inválido.');
    }
    _client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    _statuses.add(const VideoSourceStatus(VideoSourceState.connecting, message: 'Conectando ao celular remoto…'));
    await _poll();
    unawaited(_pollStatus());
    _timer = Timer.periodic(analysisInterval, (_) => unawaited(_poll()));
    _statusTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_pollStatus()),
    );
  }

  Future<void> _poll() async {
    if (_busy || _disposed) return;
    _busy = true;
    try {
      final root = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
      final uri = Uri.parse('$root/frame.jpg').replace(queryParameters: <String, String>{'key': accessKey});
      final request = await _client!.getUrl(uri);
      final response = await request.close().timeout(const Duration(seconds: 5));
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      final bytes = await consolidateHttpClientResponseBytes(response);
      _latestJpeg.value = bytes;
      final decoded = await compute<Uint8List, Map<String, Object>?>(_decodeJpeg, bytes);
      if (decoded != null && !_frames.isClosed) {
        _frames.add(RgbFrame(
          width: decoded['width']! as int,
          height: decoded['height']! as int,
          rgbBytes: decoded['bytes']! as Uint8List,
          capturedAt: DateTime.now(),
        ));
      }
      _hasConnected = true;
      _consecutiveFailures = 0;
      if (!_statuses.isClosed) {
        _statuses.add(const VideoSourceStatus(
          VideoSourceState.streaming,
          message: 'Celular remoto online',
        ));
      }
    } catch (error) {
      _consecutiveFailures++;
      if (!_statuses.isClosed) {
        final state = _hasConnected || _consecutiveFailures <= 3
            ? VideoSourceState.reconnecting
            : VideoSourceState.error;
        final prefix = state == VideoSourceState.reconnecting
            ? 'Reconectando ao celular remoto'
            : 'Celular remoto offline';
        _statuses.add(VideoSourceStatus(state, message: '$prefix: $error'));
      }
    } finally {
      _busy = false;
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
        Map<String, dynamic>.from(decoded as Map),
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
          if (bytes == null) return const Center(child: Text('Aguardando imagem do celular…'));
          return Center(
            child: Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true),
          );
        },
      );

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _statusTimer?.cancel();
    _statusTimer = null;
    _client?.close(force: true);
    _client = null;
    _hasConnected = false;
    _consecutiveFailures = 0;
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
