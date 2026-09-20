import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vlc_player/vlc_player.dart';

import '../core/video_source.dart';
import '../core/video_source_status.dart';
import '../models/rgb_frame.dart';
import '../services/error_log_service.dart';
import '../services/frame_converter.dart';

class RtspCameraSource implements VideoSource {
  RtspCameraSource({
    required this.url,
    required this.analysisInterval,
  });

  final String url;
  final Duration analysisInterval;
  final _frames = StreamController<RgbFrame>.broadcast();
  final _statuses = StreamController<VideoSourceStatus>.broadcast();
  final ErrorLogService _logs = ErrorLogService.instance;

  VlcPlayerController? _controller;
  Timer? _snapshotTimer;
  bool _snapshotInFlight = false;
  bool _disposed = false;
  DateTime _lastSuccessfulFrame = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastReconnect = DateTime.fromMillisecondsSinceEpoch(0);

  VlcPlayerController? get controller => _controller;

  @override
  Stream<RgbFrame> get frames => _frames.stream;

  @override
  Stream<VideoSourceStatus> get statuses => _statuses.stream;

  VlcMediaSource get _mediaSource => VlcMediaSource(
        uri: Uri.parse(url),
        mediaOptions: const <String>[
          ':network-caching=500',
          ':rtsp-tcp',
          ':no-audio',
        ],
      );

  @override
  Future<void> start() async {
    if (_disposed) throw StateError('Fonte RTSP ja descartada.');
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme.toLowerCase() != 'rtsp' || uri.host.isEmpty) {
      throw FormatException('Informe uma URL RTSP valida.');
    }
    if (_controller != null) return;

    _statuses.add(const VideoSourceStatus(
      VideoSourceState.connecting,
      message: 'Conectando ao stream RTSP...',
    ));

    final controller = VlcPlayerController(
      mediaSource: _mediaSource,
      autoPlay: true,
      options: const <String>['--no-audio'],
      eventThrottleInterval: const Duration(milliseconds: 250),
    );
    _controller = controller;
    _lastSuccessfulFrame = DateTime.now();
    controller.addListener(_onPlayerChanged);

    _snapshotTimer = Timer.periodic(analysisInterval, (_) {
      unawaited(_captureSnapshot());
    });
  }

  void _onPlayerChanged() {
    final value = _controller?.value;
    if (value == null || _statuses.isClosed) return;
    if (value.hasError) {
      _statuses.add(VideoSourceStatus(
        VideoSourceState.error,
        message: value.errorDescription ?? 'Falha no stream RTSP.',
      ));
      unawaited(_attemptReconnect());
      return;
    }
    if (value.isPlaying) {
      _statuses.add(const VideoSourceStatus(VideoSourceState.streaming));
    } else if (value.isBuffering) {
      _statuses.add(const VideoSourceStatus(
        VideoSourceState.connecting,
        message: 'Bufferizando stream RTSP...',
      ));
    }
  }

  Future<void> _captureSnapshot() async {
    if (_snapshotInFlight || _disposed) return;
    final controller = _controller;
    if (controller == null || !controller.isAttached) return;

    _snapshotInFlight = true;
    try {
      final bytes = await controller.takeSnapshot(width: 640);
      if (bytes.isEmpty) {
        throw StateError('Snapshot RTSP vazio.');
      }
      final frame = await FrameConverter.fromEncoded(
        bytes,
        capturedAt: DateTime.now(),
      );
      _lastSuccessfulFrame = DateTime.now();
      if (!_frames.isClosed) _frames.add(frame);
    } catch (error, stackTrace) {
      final staleFor = DateTime.now().difference(_lastSuccessfulFrame);
      if (staleFor > const Duration(seconds: 6)) {
        unawaited(
          _logs.recordException(
            source: 'RTSP',
            error: error,
            stackTrace: stackTrace,
            message: 'Frames RTSP deixaram de chegar; reconexão iniciada.',
            context: <String, Object?>{'host': Uri.tryParse(url)?.host ?? ''},
            level: ErrorLogLevel.warning,
          ),
        );
        await _attemptReconnect();
      }
    } finally {
      _snapshotInFlight = false;
    }
  }

  Future<void> _attemptReconnect() async {
    final controller = _controller;
    if (controller == null || !controller.isAttached || _disposed) return;
    final now = DateTime.now();
    if (now.difference(_lastReconnect) < const Duration(seconds: 5)) return;
    _lastReconnect = now;
    if (!_statuses.isClosed) {
      _statuses.add(const VideoSourceStatus(
        VideoSourceState.reconnecting,
        message: 'Reconectando ao RTSP...',
      ));
    }
    try {
      await controller.setMedia(_mediaSource, autoPlay: true);
    } catch (error, stackTrace) {
      if (!_statuses.isClosed) {
        _statuses.add(VideoSourceStatus(
          VideoSourceState.error,
          message: 'Reconexao RTSP falhou: $error',
        ));
      }
      unawaited(
        _logs.recordException(
          source: 'RTSP',
          error: error,
          stackTrace: stackTrace,
          message: 'Falha ao reconectar o stream RTSP.',
          context: <String, Object?>{'host': Uri.tryParse(url)?.host ?? ''},
        ),
      );
    }
  }

  @override
  Widget buildPreview() {
    final controller = _controller;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return VlcPlayer(
      controller: controller,
      fit: VlcVideoFit.contain,
    );
  }

  @override
  Future<void> stop() async {
    _snapshotTimer?.cancel();
    _snapshotTimer = null;
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.removeListener(_onPlayerChanged);
      try {
        if (controller.isAttached) await controller.stop();
      } catch (error, stackTrace) {
        unawaited(
          _logs.recordException(
            source: 'RTSP',
            error: error,
            stackTrace: stackTrace,
            message: 'Aviso ao interromper o stream RTSP.',
            context: <String, Object?>{'host': Uri.tryParse(url)?.host ?? ''},
            level: ErrorLogLevel.warning,
          ),
        );
      }
      controller.dispose();
    }
    if (!_statuses.isClosed) {
      _statuses.add(const VideoSourceStatus(VideoSourceState.stopped));
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
    await _frames.close();
    await _statuses.close();
  }
}
