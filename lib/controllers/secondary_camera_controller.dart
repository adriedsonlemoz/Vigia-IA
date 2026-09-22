import 'dart:async';

import 'package:flutter/material.dart';

import '../core/video_source.dart';
import '../core/video_source_status.dart';
import '../models/remote_phone_status.dart';
import '../models/video_source_config.dart';
import '../sources/local_camera_source.dart';
import '../sources/remote_phone_camera_source.dart';
import '../sources/rtsp_camera_source.dart';

/// Mantém uma segunda visualização sem abrir outro pipeline de IA.
class SecondaryCameraController extends ChangeNotifier {
  SecondaryCameraController({required this.sourceConfig});

  final VideoSourceConfig sourceConfig;
  VideoSource? _source;
  StreamSubscription<VideoSourceStatus>? _statusSubscription;
  VideoSourceStatus _status = const VideoSourceStatus(VideoSourceState.idle);
  bool _initializing = false;
  bool _disposed = false;
  String? _error;

  VideoSourceStatus get status => _status;
  bool get initializing => _initializing;
  String? get error => _error;
  String get displayName => sourceConfig.displayName?.trim().isNotEmpty == true
      ? sourceConfig.displayName!.trim()
      : switch (sourceConfig.type) {
          VideoSourceType.localCamera => 'Câmera local',
          VideoSourceType.rtsp => 'Câmera RTSP',
          VideoSourceType.remotePhone => 'Celular remoto',
        };
  RemotePhoneStatus? get remoteStatus {
    final source = _source;
    return source is RemotePhoneCameraSource ? source.remoteStatus : null;
  }

  Widget buildPreview() => _source?.buildPreview() ?? const SizedBox.expand();

  Future<void> start() async {
    if (_disposed || _source != null || _initializing) return;
    _initializing = true;
    _error = null;
    _status = const VideoSourceStatus(VideoSourceState.connecting);
    notifyListeners();

    final source = switch (sourceConfig.type) {
      VideoSourceType.localCamera => LocalCameraSource(
          analysisInterval: sourceConfig.analysisInterval,
          emitFrames: false,
        ),
      VideoSourceType.rtsp => RtspCameraSource(
          url: sourceConfig.rtspUrl ?? '',
          analysisInterval: sourceConfig.analysisInterval,
          emitFrames: false,
        ),
      VideoSourceType.remotePhone => RemotePhoneCameraSource(
          baseUrl: sourceConfig.remoteBaseUrl ?? '',
          accessKey: sourceConfig.remoteAccessKey ?? '',
          analysisInterval: sourceConfig.analysisInterval,
          emitFrames: false,
        ),
    };
    _source = source;
    if (source is RemotePhoneCameraSource) {
      source.remoteStatusNotifier.addListener(_onRemoteStatusChanged);
    }
    _statusSubscription = source.statuses.listen((status) {
      if (_disposed) return;
      _status = status;
      notifyListeners();
    });
    try {
      await source.start();
    } catch (error) {
      _error = error.toString();
      _status = VideoSourceStatus(
        VideoSourceState.error,
        message: 'Não foi possível abrir a segunda câmera.',
      );
    } finally {
      _initializing = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _onRemoteStatusChanged() {
    if (!_disposed) notifyListeners();
  }

  Future<void> suspend() async {
    await _releaseSource();
  }

  Future<void> resume() => start();

  Future<void> _releaseSource() async {
    await _statusSubscription?.cancel();
    _statusSubscription = null;
    final source = _source;
    _source = null;
    if (source is RemotePhoneCameraSource) {
      source.remoteStatusNotifier.removeListener(_onRemoteStatusChanged);
    }
    if (source != null) await source.dispose();
    if (!_disposed) {
      _status = const VideoSourceStatus(VideoSourceState.stopped);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_releaseSource());
    super.dispose();
  }
}
