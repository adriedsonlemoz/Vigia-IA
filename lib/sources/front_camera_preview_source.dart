import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../core/video_source.dart';
import '../core/video_source_status.dart';
import '../models/rgb_frame.dart';

/// Fonte temporária de pré-visualização para testar a segunda câmera local.
///
/// Ela abre somente a câmera frontal, em baixa resolução e sem análise de IA.
/// A câmera principal continua sendo a única responsável pelos frames da IA.
/// Alguns aparelhos Android não permitem câmera frontal + traseira simultâneas;
/// nesse caso a inicialização falha de forma isolada e a câmera principal segue
/// funcionando normalmente.
class FrontCameraPreviewSource implements VideoSource {
  final StreamController<RgbFrame> _frames =
      StreamController<RgbFrame>.broadcast();
  final StreamController<VideoSourceStatus> _statuses =
      StreamController<VideoSourceStatus>.broadcast();

  CameraController? _controller;
  bool _started = false;
  bool _disposed = false;

  @override
  Stream<RgbFrame> get frames => _frames.stream;

  @override
  Stream<VideoSourceStatus> get statuses => _statuses.stream;

  @override
  Future<void> start() async {
    if (_disposed) throw StateError('Fonte frontal de teste já descartada.');
    if (_started) return;
    _started = true;
    _statuses.add(const VideoSourceStatus(VideoSourceState.connecting));

    CameraController? controller;
    try {
      final cameras = await availableCameras();
      final fronts = cameras.where(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );
      if (fronts.isEmpty) {
        throw StateError('Nenhuma câmera frontal disponível.');
      }

      controller = CameraController(
        fronts.first,
        ResolutionPreset.low,
        enableAudio: false,
      );
      _controller = controller;
      await controller.initialize();
      if (_disposed || !_started || !identical(_controller, controller)) {
        await controller.dispose();
        return;
      }
      _statuses.add(const VideoSourceStatus(VideoSourceState.streaming));
    } catch (_) {
      if (identical(_controller, controller)) _controller = null;
      if (controller != null) {
        try {
          await controller.dispose();
        } catch (_) {
          // A falha original é mais útil do que um segundo erro de descarte.
        }
      }
      _started = false;
      _statuses.add(
        const VideoSourceStatus(
          VideoSourceState.error,
          message: 'Câmera frontal indisponível em simultâneo.',
        ),
      );
      rethrow;
    }
  }

  @override
  Widget buildPreview() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: CameraPreview(controller, key: ObjectKey(controller)),
      ),
    );
  }

  @override
  Future<void> stop() async {
    if (!_started && _controller == null) return;
    _started = false;
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      try {
        await controller.dispose();
      } catch (_) {
        // O controlador pode ter sido invalidado pelo Android após uma falha
        // de câmera concorrente; a principal não deve ser afetada por isso.
      }
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
