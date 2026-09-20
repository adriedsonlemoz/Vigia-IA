import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_litert/flutter_litert.dart' hide Detection;
import 'package:image/image.dart' as img;

import '../models/detection.dart';
import '../models/rgb_frame.dart';
import 'detector_image_transform.dart';
import 'label_translator.dart';

part 'object_detection_worker.dart';

class ObjectDetectionService {
  static const _primaryModelAsset = 'assets/models/efficientdet_lite0.tflite';
  static const _fallbackModelAsset = 'assets/models/ssd_mobilenet_v1.tflite';
  static const _labelsAsset = 'assets/models/labelmap.txt';

  Isolate? _worker;
  ReceivePort? _responses;
  SendPort? _commands;
  StreamSubscription<dynamic>? _responseSubscription;
  Completer<void>? _ready;
  Completer<void>? _workerDone;
  final Map<int, Completer<List<Detection>>> _pending =
      <int, Completer<List<Detection>>>{};
  int _nextRequestId = 0;
  bool _disposed = false;
  String? _diagnostics;

  bool get isReady => _commands != null && !_disposed;
  String? get diagnostics => _diagnostics;

  Future<void> initialize() async {
    if (isReady) return;
    if (_disposed) throw StateError('Detector ja descartado.');

    final models = <Map<String, Object>>[];
    for (final entry in const <(String, String)>[
      ('EfficientDet-Lite0', _primaryModelAsset),
      ('SSD MobileNet V1', _fallbackModelAsset),
    ]) {
      final modelData = await rootBundle.load(entry.$2);
      if (modelData.lengthInBytes < 1024 * 1024) continue;
      final bytes = modelData.buffer.asUint8List(
        modelData.offsetInBytes,
        modelData.lengthInBytes,
      );
      models.add(<String, Object>{
        'name': entry.$1,
        'bytes': TransferableTypedData.fromList([bytes]),
      });
    }
    if (models.isEmpty) {
      throw StateError(
        'Modelos TensorFlow Lite ausentes. Execute tool/fetch_model.sh antes de compilar.',
      );
    }

    final labelsRaw = await rootBundle.loadString(_labelsAsset);
    final labels = labelsRaw
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    final responses = ReceivePort();
    final ready = Completer<void>();
    final workerDone = Completer<void>();
    _responses = responses;
    _ready = ready;
    _workerDone = workerDone;
    _responseSubscription = responses.listen(_handleWorkerMessage);

    _worker = await Isolate.spawn<Map<String, Object>>(
      _detectorWorkerMain,
      <String, Object>{
        'replyPort': responses.sendPort,
        'models': models,
        'labels': labels,
      },
      debugName: 'object-detector-worker',
    );

    try {
      await ready.future.timeout(const Duration(seconds: 15));
    } catch (_) {
      await dispose();
      rethrow;
    }
  }

  void _handleWorkerMessage(dynamic rawMessage) {
    if (rawMessage is! Map<Object?, Object?>) return;
    final message = rawMessage;
    final type = message['type'];

    if (type == 'ready') {
      final port = message['port'];
      if (port is! SendPort) {
        _ready?.completeError(
          StateError('Worker de deteccao retornou uma porta invalida.'),
        );
        return;
      }
      _commands = port;
      _diagnostics = message['diagnostics']?.toString();
      final ready = _ready;
      if (ready != null && !ready.isCompleted) ready.complete();
      return;
    }

    if (type == 'initError') {
      final ready = _ready;
      if (ready != null && !ready.isCompleted) {
        ready.completeError(StateError('${message['error']}'));
      }
      return;
    }

    if (type == 'disposed') {
      final done = _workerDone;
      if (done != null && !done.isCompleted) done.complete();
      return;
    }

    final id = message['id'];
    if (id is! int) return;
    final completer = _pending.remove(id);
    if (completer == null || completer.isCompleted) return;

    if (type == 'error') {
      completer.completeError(StateError('${message['error']}'));
      return;
    }

    if (type != 'result') {
      completer.completeError(StateError('Resposta desconhecida do detector.'));
      return;
    }

    try {
      final rawResults = message['results'];
      if (rawResults is! List<Object?>) {
        throw StateError('Resultados invalidos recebidos do detector.');
      }
      final detections = <Detection>[];
      for (final rawRow in rawResults) {
        if (rawRow is! List<Object?> || rawRow.length < 6) continue;
        final label = rawRow[0]! as String;
        detections.add(
          Detection(
            label: label,
            displayLabel: LabelTranslator.ptBr(label),
            confidence: (rawRow[1]! as num).toDouble(),
            box: NormalizedBox(
              yMin: (rawRow[2]! as num).toDouble(),
              xMin: (rawRow[3]! as num).toDouble(),
              yMax: (rawRow[4]! as num).toDouble(),
              xMax: (rawRow[5]! as num).toDouble(),
            ),
          ),
        );
      }
      completer.complete(List<Detection>.unmodifiable(detections));
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
    }
  }

  Future<List<Detection>> detect(
    RgbFrame frame, {
    required double threshold,
    required int maxResults,
    Set<String>? allowedLabels,
  }) async {
    final commands = _commands;
    if (commands == null || _disposed) {
      throw StateError('Detector nao inicializado.');
    }

    final id = _nextRequestId++;
    final completer = Completer<List<Detection>>();
    _pending[id] = completer;
    final request = <String, Object>{
      'type': 'detect',
      'id': id,
      'width': frame.width,
      'height': frame.height,
      'bytes': TransferableTypedData.fromList([frame.rgbBytes]),
      'threshold': threshold,
      'maxResults': maxResults,
    };
    if (allowedLabels != null) {
      request['allowedLabels'] = allowedLabels.toList(growable: false);
    }
    commands.send(request);
    return completer.future;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final commands = _commands;
    final worker = _worker;
    final workerDone = _workerDone;
    commands?.send(const <String, Object>{'type': 'dispose'});
    _commands = null;

    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Detector encerrado.'));
      }
    }
    _pending.clear();

    if (workerDone != null && !workerDone.isCompleted && commands != null) {
      try {
        await workerDone.future.timeout(const Duration(seconds: 2));
      } catch (_) {
        worker?.kill(priority: Isolate.immediate);
      }
    } else {
      worker?.kill(priority: Isolate.immediate);
    }

    await _responseSubscription?.cancel();
    _responseSubscription = null;
    _responses?.close();
    _responses = null;
    _worker = null;
    _workerDone = null;
  }
}
