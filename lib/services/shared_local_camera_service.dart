import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/video_source_status.dart';
import '../models/rgb_frame.dart';
import 'error_log_service.dart';
import 'frame_converter.dart';

/// Mantém um único pipeline CameraX para todos os recursos que usam a câmera
/// local. Monitor e Modo Câmera recebem os mesmos frames, evitando tentar
/// vincular Preview/ImageCapture/ImageAnalysis duas vezes ao mesmo dispositivo.
class SharedLocalCameraService extends ChangeNotifier {
  SharedLocalCameraService._();

  static final SharedLocalCameraService instance = SharedLocalCameraService._();

  final StreamController<RgbFrame> _frames = StreamController<RgbFrame>.broadcast();
  final StreamController<VideoSourceStatus> _statuses =
      StreamController<VideoSourceStatus>.broadcast();
  final ErrorLogService _logs = ErrorLogService.instance;
  final Map<String, Duration> _consumers = <String, Duration>{};

  CameraController? _controller;
  CameraDescription? _description;
  DateTime _lastConvertedAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _converting = false;
  Future<void> _transitionTail = Future<void>.value();

  Stream<RgbFrame> get frames => _frames.stream;
  Stream<VideoSourceStatus> get statuses => _statuses.stream;
  CameraController? get controller => _controller;
  bool get running => _controller?.value.isInitialized == true;
  int get consumerCount => _consumers.length;

  Future<void> acquire({
    required String consumerId,
    required Duration analysisInterval,
  }) async {
    _consumers[consumerId] = _normalizeInterval(analysisInterval);
    await _enqueue(() async {
      if (_consumers.isEmpty || running) return;
      await _startUnlocked();
    });
  }

  Future<void> release(String consumerId) async {
    _consumers.remove(consumerId);
    await _enqueue(() async {
      if (_consumers.isNotEmpty) return;
      await _stopUnlocked(notifyStopped: true);
    });
  }

  /// Reinicia o pipeline físico mantendo os consumidores conectados aos mesmos
  /// streams. É usado pelo watchdog quando frames realmente congelam.
  Future<void> restartPipeline() async {
    await _enqueue(() async {
      if (_consumers.isEmpty) return;
      await _stopUnlocked(notifyStopped: false);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (_consumers.isNotEmpty) await _startUnlocked();
    });
  }

  Widget buildPreview() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(child: CameraPreview(controller));
  }

  Future<void> _startUnlocked() async {
    _statuses.add(const VideoSourceStatus(VideoSourceState.connecting));
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      const status = VideoSourceStatus(
        VideoSourceState.error,
        message: 'Nenhuma câmera disponível no dispositivo.',
      );
      _statuses.add(status);
      throw StateError('Nenhuma câmera disponível.');
    }

    final back = cameras.where(
      (camera) => camera.lensDirection == CameraLensDirection.back,
    );
    _description = back.isNotEmpty ? back.first : cameras.first;

    final controller = CameraController(
      _description!,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    _controller = controller;
    try {
      await controller.initialize();
      if (!identical(_controller, controller) || _consumers.isEmpty) {
        await _safeDisposeController(controller);
        return;
      }
      await controller.startImageStream(_onCameraImage);
      _lastConvertedAt = DateTime.fromMillisecondsSinceEpoch(0);
      _statuses.add(const VideoSourceStatus(VideoSourceState.streaming));
      notifyListeners();
    } catch (error) {
      if (identical(_controller, controller)) _controller = null;
      await _safeDisposeController(controller);
      _statuses.add(VideoSourceStatus(
        VideoSourceState.error,
        message: 'Não foi possível iniciar a câmera: $error',
      ));
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _onCameraImage(CameraImage image) async {
    if (_converting || _consumers.isEmpty) return;
    final now = DateTime.now();
    if (now.difference(_lastConvertedAt) < _minimumInterval) return;
    _lastConvertedAt = now;
    _converting = true;

    try {
      final controller = _controller;
      final description = _description;
      if (controller == null || description == null) return;
      final rotation = _rotationForFrame(
        sensorOrientation: description.sensorOrientation,
        deviceOrientation: controller.value.deviceOrientation,
        frontCamera: description.lensDirection == CameraLensDirection.front,
      );
      final data = CameraFrameData(
        width: image.width,
        height: image.height,
        rotationDegrees: rotation,
        isBgra: image.format.group == ImageFormatGroup.bgra8888,
        mirrorHorizontally:
            description.lensDirection == CameraLensDirection.front,
        planes: image.planes
            .map(
              (plane) => CameraPlaneData(
                bytes: Uint8List.fromList(plane.bytes),
                bytesPerRow: plane.bytesPerRow,
                bytesPerPixel: plane.bytesPerPixel ?? 1,
              ),
            )
            .toList(growable: false),
      );
      final converted = await FrameConverter.fromCamera(data);
      if (_consumers.isNotEmpty && !_frames.isClosed) _frames.add(converted);
    } catch (error, stackTrace) {
      // Um quadro inválido isolado não significa que a câmera física caiu.
      // O watchdog de frames decide se o pipeline realmente ficou offline.
      unawaited(
        _logs.recordException(
          source: 'Câmera local',
          error: error,
          stackTrace: stackTrace,
          message: 'Falha não fatal ao converter um frame da câmera compartilhada.',
          level: ErrorLogLevel.warning,
        ),
      );
    } finally {
      _converting = false;
    }
  }

  Duration get _minimumInterval {
    if (_consumers.isEmpty) return const Duration(milliseconds: 400);
    return _consumers.values.reduce(
      (current, next) => next < current ? next : current,
    );
  }

  Duration _normalizeInterval(Duration value) => Duration(
        milliseconds: value.inMilliseconds.clamp(250, 5000).toInt(),
      );

  Future<void> _stopUnlocked({required bool notifyStopped}) async {
    final controller = _controller;
    _controller = null;
    _description = null;
    _lastConvertedAt = DateTime.fromMillisecondsSinceEpoch(0);
    if (controller != null) {
      try {
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
      } catch (_) {
        // O CameraX pode já ter encerrado o stream durante uma recuperação.
      }
      await _safeDisposeController(controller);
    }
    if (notifyStopped) {
      _statuses.add(const VideoSourceStatus(VideoSourceState.stopped));
    }
    notifyListeners();
  }

  Future<void> _safeDisposeController(CameraController controller) async {
    try {
      await controller.dispose();
    } on PlatformException catch (error, stackTrace) {
      final details = '${error.code} ${error.message ?? ''}'.toLowerCase();
      if (details.contains('releasefluttersurfacetexture') ||
          details.contains('has not yet been initialized')) {
        // A inicialização falhou antes de existir uma surface de preview. Nesse
        // caso o dispose do CameraX também pode responder com IllegalStateException;
        // é apenas consequência da falha original e não merece um segundo alerta.
        return;
      }
      unawaited(
        _logs.recordException(
          source: 'Câmera local',
          error: error,
          stackTrace: stackTrace,
          message: 'Falha não fatal ao liberar a câmera compartilhada.',
          level: ErrorLogLevel.warning,
        ),
      );
    } catch (error, stackTrace) {
      unawaited(
        _logs.recordException(
          source: 'Câmera local',
          error: error,
          stackTrace: stackTrace,
          message: 'Falha não fatal ao liberar a câmera compartilhada.',
          level: ErrorLogLevel.warning,
        ),
      );
    }
  }

  int _rotationForFrame({
    required int sensorOrientation,
    required DeviceOrientation deviceOrientation,
    required bool frontCamera,
  }) {
    const deviceDegrees = <DeviceOrientation, int>{
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeLeft: 90,
      DeviceOrientation.portraitDown: 180,
      DeviceOrientation.landscapeRight: 270,
    };
    final degrees = deviceDegrees[deviceOrientation] ?? 0;
    if (frontCamera) return (sensorOrientation + degrees) % 360;
    return (sensorOrientation - degrees + 360) % 360;
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final completer = Completer<void>();
    final previous = _transitionTail;
    _transitionTail = () async {
      try {
        await previous;
      } catch (_) {}
      try {
        await operation();
        if (!completer.isCompleted) completer.complete();
      } catch (error, stackTrace) {
        if (!completer.isCompleted) completer.completeError(error, stackTrace);
      }
    }();
    return completer.future;
  }
}
