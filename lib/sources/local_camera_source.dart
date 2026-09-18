import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/video_source.dart';
import '../core/video_source_status.dart';
import '../models/rgb_frame.dart';
import '../services/error_log_service.dart';
import '../services/frame_converter.dart';

class LocalCameraSource implements VideoSource {
  LocalCameraSource({required this.analysisInterval});

  final Duration analysisInterval;
  final _frames = StreamController<RgbFrame>.broadcast();
  final _statuses = StreamController<VideoSourceStatus>.broadcast();
  final ErrorLogService _logs = ErrorLogService.instance;

  CameraController? _controller;
  CameraDescription? _description;
  DateTime _lastFrameAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _converting = false;
  bool _disposed = false;

  CameraController? get controller => _controller;

  @override
  Stream<RgbFrame> get frames => _frames.stream;

  @override
  Stream<VideoSourceStatus> get statuses => _statuses.stream;

  @override
  Future<void> start() async {
    if (_disposed) throw StateError('Fonte de camera ja descartada.');
    if (_controller?.value.isInitialized == true) return;

    _statuses.add(const VideoSourceStatus(VideoSourceState.connecting));
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      _statuses.add(const VideoSourceStatus(
        VideoSourceState.error,
        message: 'Nenhuma camera disponivel no dispositivo.',
      ));
      throw StateError('Nenhuma camera disponivel.');
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
    await controller.initialize();
    if (_disposed || _controller != controller) {
      await _safeDisposeController(controller);
      return;
    }
    await controller.startImageStream(_onCameraImage);
    if (!_statuses.isClosed) {
      _statuses.add(const VideoSourceStatus(VideoSourceState.streaming));
    }
  }

  Future<void> _onCameraImage(CameraImage image) async {
    if (_converting || _disposed) return;
    final now = DateTime.now();
    if (now.difference(_lastFrameAt) < analysisInterval) return;
    _lastFrameAt = now;
    _converting = true;

    try {
      final controller = _controller;
      final description = _description;
      if (controller == null || description == null) return;
      final orientation = controller.value.deviceOrientation;
      final rotation = _rotationForFrame(
        sensorOrientation: description.sensorOrientation,
        deviceOrientation: orientation,
        frontCamera: description.lensDirection == CameraLensDirection.front,
      );
      final data = CameraFrameData(
        width: image.width,
        height: image.height,
        rotationDegrees: rotation,
        isBgra: image.format.group == ImageFormatGroup.bgra8888,
        mirrorHorizontally:
            description.lensDirection == CameraLensDirection.front,
        planes: image.planes.map((plane) {
          return CameraPlaneData(
            bytes: Uint8List.fromList(plane.bytes),
            bytesPerRow: plane.bytesPerRow,
            bytesPerPixel: plane.bytesPerPixel ?? 1,
          );
        }).toList(growable: false),
      );
      final converted = await FrameConverter.fromCamera(data);
      if (!_frames.isClosed && !_disposed) _frames.add(converted);
    } catch (error, stackTrace) {
      if (!_statuses.isClosed) {
        _statuses.add(VideoSourceStatus(
          VideoSourceState.error,
          message: 'Falha ao preparar frame da camera: $error',
        ));
      }
      unawaited(
        _logs.recordException(
          source: 'Câmera local',
          error: error,
          stackTrace: stackTrace,
          message: 'Falha ao converter um frame da câmera.',
        ),
      );
    } finally {
      _converting = false;
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
    if (frontCamera) {
      return (sensorOrientation + degrees) % 360;
    }
    return (sensorOrientation - degrees + 360) % 360;
  }

  @override
  Widget buildPreview() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    // CameraPreview ja aplica a proporcao correta e inverte o aspect ratio
    // automaticamente em retrato. Nao envolver em outro AspectRatio evita
    // distorcao/alongamento da imagem.
    return Center(child: CameraPreview(controller));
  }

  @override
  Future<void> stop() async {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      try {
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
      } catch (error, stackTrace) {
        unawaited(
          _logs.recordException(
            source: 'Câmera local',
            error: error,
            stackTrace: stackTrace,
            message: 'Aviso ao interromper o stream da câmera.',
            level: ErrorLogLevel.warning,
          ),
        );
      }
      await _safeDisposeController(controller);
    }
    if (!_statuses.isClosed) {
      _statuses.add(const VideoSourceStatus(VideoSourceState.stopped));
    }
  }

  Future<void> _safeDisposeController(CameraController controller) async {
    try {
      await controller.dispose();
    } on PlatformException catch (error, stackTrace) {
      unawaited(
        _logs.recordException(
          source: 'Câmera local',
          error: error,
          stackTrace: stackTrace,
          message: 'A câmera foi liberada pelo Android antes do preview.',
          level: ErrorLogLevel.warning,
        ),
      );
    } catch (error, stackTrace) {
      unawaited(
        _logs.recordException(
          source: 'Câmera local',
          error: error,
          stackTrace: stackTrace,
          message: 'Falha não fatal ao liberar a câmera.',
          level: ErrorLogLevel.warning,
        ),
      );
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
