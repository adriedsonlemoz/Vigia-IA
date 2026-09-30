import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/video_source.dart';
import '../core/video_source_status.dart';
import '../models/rgb_frame.dart';
import '../services/shared_local_camera_service.dart';

class LocalCameraSource implements VideoSource {
  LocalCameraSource({
    required this.analysisInterval,
    this.emitFrames = true,
  })
      : _consumerId = 'local-camera-${++_nextConsumerId}';

  static int _nextConsumerId = 0;

  final Duration analysisInterval;
  final bool emitFrames;
  final String _consumerId;
  final SharedLocalCameraService _shared = SharedLocalCameraService.instance;
  final StreamController<RgbFrame> _frames = StreamController<RgbFrame>.broadcast();
  final StreamController<VideoSourceStatus> _statuses =
      StreamController<VideoSourceStatus>.broadcast();

  StreamSubscription<RgbFrame>? _frameSubscription;
  StreamSubscription<VideoSourceStatus>? _statusSubscription;
  DateTime _lastForwardedAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _started = false;
  bool _disposed = false;

  double? get previewAspectRatio {
    final controller = _shared.controller;
    if (controller == null || !controller.value.isInitialized) return null;
    final base = controller.value.aspectRatio;
    if (!base.isFinite || base <= 0) return null;
    final orientation = controller.value.deviceOrientation;
    final portrait = orientation == DeviceOrientation.portraitUp ||
        orientation == DeviceOrientation.portraitDown;
    return portrait ? 1 / base : base;
  }

  @override
  Stream<RgbFrame> get frames => _frames.stream;

  @override
  Stream<VideoSourceStatus> get statuses => _statuses.stream;

  @override
  Future<void> start() async {
    if (_disposed) throw StateError('Fonte de câmera já descartada.');
    if (_started) return;
    _started = true;
    _lastForwardedAt = DateTime.fromMillisecondsSinceEpoch(0);
    if (emitFrames) {
      _frameSubscription = _shared.frames.listen(_onSharedFrame);
    }
    _statusSubscription = _shared.statuses.listen((status) {
      if (!_statuses.isClosed) _statuses.add(status);
    });
    try {
      await _shared.acquire(
        consumerId: _consumerId,
        analysisInterval: analysisInterval,
      );
      if (!_statuses.isClosed && _shared.running) {
        _statuses.add(const VideoSourceStatus(VideoSourceState.streaming));
      }
    } catch (_) {
      _started = false;
      await _frameSubscription?.cancel();
      await _statusSubscription?.cancel();
      _frameSubscription = null;
      _statusSubscription = null;
      await _shared.release(_consumerId);
      rethrow;
    }
  }

  void _onSharedFrame(RgbFrame frame) {
    if (!_started || _disposed) return;
    if (frame.capturedAt.difference(_lastForwardedAt) < analysisInterval) return;
    _lastForwardedAt = frame.capturedAt;
    if (!_frames.isClosed) _frames.add(frame);
  }

  @override
  Widget buildPreview() => _shared.buildPreview();

  @override
  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    await _frameSubscription?.cancel();
    await _statusSubscription?.cancel();
    _frameSubscription = null;
    _statusSubscription = null;
    await _shared.release(_consumerId);
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
