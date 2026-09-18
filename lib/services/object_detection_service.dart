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
  }) async {
    final commands = _commands;
    if (commands == null || _disposed) {
      throw StateError('Detector nao inicializado.');
    }

    final id = _nextRequestId++;
    final completer = Completer<List<Detection>>();
    _pending[id] = completer;
    commands.send(<String, Object>{
      'type': 'detect',
      'id': id,
      'width': frame.width,
      'height': frame.height,
      'bytes': TransferableTypedData.fromList([frame.rgbBytes]),
      'threshold': threshold,
      'maxResults': maxResults,
    });
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

Future<void> _detectorWorkerMain(Map<String, Object> bootstrap) async {
  final replyPort = bootstrap['replyPort']! as SendPort;
  Interpreter? interpreter;
  ReceivePort? commands;

  try {
    final labels = bootstrap['labels']! as List<String>;
    final rawModels = (bootstrap['models']! as List<Object?>)
        .cast<Map<String, Object>>();
    final failures = <String>[];
    _DetectorRuntime? runtime;

    for (final model in rawModels) {
      final name = model['name']! as String;
      final transfer = model['bytes']! as TransferableTypedData;
      final modelBytes = transfer.materialize().asUint8List();
      Interpreter? candidate;
      try {
        final options = InterpreterOptions()..threads = 4;
        candidate = Interpreter.fromBuffer(modelBytes, options: options);
        final inspected = _inspectInterpreter(candidate, name);
        interpreter = candidate;
        runtime = inspected;
        break;
      } catch (error) {
        candidate?.close();
        failures.add('$name: $error');
      }
    }

    final activeInterpreter = interpreter;
    final activeRuntime = runtime;
    if (activeInterpreter == null || activeRuntime == null) {
      throw StateError(
        'Nenhum modelo de detecção compatível pôde ser iniciado. ${failures.join(' | ')}',
      );
    }

    commands = ReceivePort();
    replyPort.send(<String, Object>{
      'type': 'ready',
      'port': commands.sendPort,
      'diagnostics': activeRuntime.diagnostics,
    });

    await for (final rawMessage in commands) {
      if (rawMessage is! Map<Object?, Object?>) continue;
      final message = rawMessage;
      final type = message['type'];
      if (type == 'dispose') break;
      if (type != 'detect') continue;

      final id = message['id']! as int;
      try {
        final width = message['width']! as int;
        final height = message['height']! as int;
        final threshold = (message['threshold']! as num).toDouble();
        final maxResults = message['maxResults']! as int;
        final transfer = message['bytes']! as TransferableTypedData;
        final rgbBytes = transfer.materialize().asUint8List();

        final results = _runDetection(
          interpreter: activeInterpreter,
          runtime: activeRuntime,
          labels: labels,
          rgbBytes: rgbBytes,
          width: width,
          height: height,
          threshold: threshold,
          maxResults: maxResults,
        );
        replyPort.send(<String, Object>{
          'type': 'result',
          'id': id,
          'results': results,
        });
      } catch (error, stackTrace) {
        replyPort.send(<String, Object>{
          'type': 'error',
          'id': id,
          'error': '$error\n$stackTrace',
        });
      }
    }
  } catch (error, stackTrace) {
    replyPort.send(<String, Object>{
      'type': 'initError',
      'error': '$error\n$stackTrace',
    });
  } finally {
    commands?.close();
    interpreter?.close();
    replyPort.send(const <String, Object>{'type': 'disposed'});
  }
}

_DetectorRuntime _inspectInterpreter(Interpreter interpreter, String modelName) {
  final inputTensor = interpreter.getInputTensor(0);
  final inputShape = inputTensor.shape;
  final inputType = inputTensor.type;
  if (inputShape.length != 4 || inputShape.last != 3) {
    throw StateError(
      'entrada esperada [1,H,W,3], encontrada $inputShape.',
    );
  }
  if (inputType != TensorType.uint8 && inputType != TensorType.float32) {
    throw StateError('tipo de entrada $inputType não suportado.');
  }

  final outputs = interpreter.getOutputTensors();
  final outputSummary = outputs.asMap().entries.map((entry) {
    return '${entry.key}:${entry.value.shape}/${entry.value.type}';
  }).join(', ');
  if (outputs.length != 4) {
    throw StateError(
      'são esperadas 4 saídas DetectionPostProcess. Encontradas ${outputs.length}: $outputSummary',
    );
  }
  final boxesShape = outputs[0].shape;
  if (boxesShape.length != 3 || boxesShape.last != 4) {
    throw StateError(
      'saída de caixas não reconhecida. Saídas: $outputSummary',
    );
  }

  return _DetectorRuntime(
    inputWidth: inputShape[2],
    inputHeight: inputShape[1],
    inputType: inputType,
    maxDetections: boxesShape[1],
    diagnostics: 'modelo=$modelName; entrada=$inputShape/$inputType; '
        'saidas=$outputSummary; maxDetections=${boxesShape[1]}; '
        'preprocessamento=letterbox',
  );
}

List<List<Object>> _runDetection({
  required Interpreter interpreter,
  required _DetectorRuntime runtime,
  required List<String> labels,
  required Uint8List rgbBytes,
  required int width,
  required int height,
  required double threshold,
  required int maxResults,
}) {
  final source = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: rgbBytes.buffer,
    numChannels: 3,
    order: img.ChannelOrder.rgb,
  );
  final transform = DetectorImageTransform.fit(
    sourceWidth: width,
    sourceHeight: height,
    inputWidth: runtime.inputWidth,
    inputHeight: runtime.inputHeight,
  );
  final resized = img.copyResize(
    source,
    width: transform.resizedWidth,
    height: transform.resizedHeight,
    interpolation: img.Interpolation.linear,
  );
  final letterboxed = img.Image(
    width: runtime.inputWidth,
    height: runtime.inputHeight,
    numChannels: 3,
  );
  img.compositeImage(
    letterboxed,
    resized,
    dstX: transform.offsetX,
    dstY: transform.offsetY,
  );

  late final Object batchedInput;
  if (runtime.inputType == TensorType.uint8) {
    final matrix = List<List<List<int>>>.generate(
      runtime.inputHeight,
      (y) => List<List<int>>.generate(
        runtime.inputWidth,
        (x) {
          final pixel = letterboxed.getPixel(x, y);
          return <int>[
            pixel.r.toInt().clamp(0, 255).toInt(),
            pixel.g.toInt().clamp(0, 255).toInt(),
            pixel.b.toInt().clamp(0, 255).toInt(),
          ];
        },
        growable: false,
      ),
      growable: false,
    );
    batchedInput = <List<List<List<int>>>>[matrix];
  } else {
    final matrix = List<List<List<double>>>.generate(
      runtime.inputHeight,
      (y) => List<List<double>>.generate(
        runtime.inputWidth,
        (x) {
          final pixel = letterboxed.getPixel(x, y);
          return <double>[
            (pixel.r.toDouble() - 127.5) / 127.5,
            (pixel.g.toDouble() - 127.5) / 127.5,
            (pixel.b.toDouble() - 127.5) / 127.5,
          ];
        },
        growable: false,
      ),
      growable: false,
    );
    batchedInput = <List<List<List<double>>>>[matrix];
  }

  final boxes = <List<List<double>>>[
    List.generate(
      runtime.maxDetections,
      (_) => List<double>.filled(4, 0.0),
      growable: false,
    ),
  ];
  final classes = <List<double>>[
    List<double>.filled(runtime.maxDetections, 0.0),
  ];
  final scores = <List<double>>[
    List<double>.filled(runtime.maxDetections, 0.0),
  ];
  final count = <double>[0.0];
  final output = <int, Object>{0: boxes, 1: classes, 2: scores, 3: count};

  interpreter.runForMultipleInputs(<Object>[batchedInput], output);

  final boxList = boxes.first;
  final classList = classes.first;
  final scoreList = scores.first;
  final reportedCount = count.first.round();
  final candidateCount = reportedCount > 0 ? reportedCount : runtime.maxDetections;
  final usableCount = math.min(
    math.min(candidateCount, runtime.maxDetections),
    math.min(classList.length, scoreList.length),
  );

  final results = <List<Object>>[];
  for (var i = 0; i < usableCount; i++) {
    final score = scoreList[i].toDouble();
    if (score < threshold) continue;
    final classIndex = classList[i].round();
    if (classIndex < 0 || classIndex >= labels.length) continue;
    final label = labels[classIndex];
    if (label == '???') continue;
    final boxValues = boxList[i];
    if (boxValues.length < 4) continue;

    final mapped = transform.mapBoxFromInput(
      NormalizedBox(
        yMin: boxValues[0].toDouble().clamp(0.0, 1.0).toDouble(),
        xMin: boxValues[1].toDouble().clamp(0.0, 1.0).toDouble(),
        yMax: boxValues[2].toDouble().clamp(0.0, 1.0).toDouble(),
        xMax: boxValues[3].toDouble().clamp(0.0, 1.0).toDouble(),
      ),
    );
    if (mapped == null) continue;

    results.add(<Object>[
      label,
      score,
      mapped.yMin,
      mapped.xMin,
      mapped.yMax,
      mapped.xMax,
    ]);
  }

  results.sort((a, b) => (b[1] as double).compareTo(a[1] as double));
  if (results.length > maxResults) return results.sublist(0, maxResults);
  return results;
}

class _DetectorRuntime {
  const _DetectorRuntime({
    required this.inputWidth,
    required this.inputHeight,
    required this.inputType,
    required this.maxDetections,
    required this.diagnostics,
  });

  final int inputWidth;
  final int inputHeight;
  final TensorType inputType;
  final int maxDetections;
  final String diagnostics;
}
