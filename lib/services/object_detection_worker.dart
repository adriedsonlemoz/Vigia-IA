part of 'object_detection_service.dart';

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
        final allowedLabels = (message['allowedLabels'] as List<Object?>?)
            ?.whereType<String>()
            .toSet();
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
          allowedLabels: allowedLabels,
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
  Set<String>? allowedLabels,
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
    if (allowedLabels != null && !allowedLabels.contains(label)) continue;
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
