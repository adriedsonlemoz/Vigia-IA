part of 'object_detection_service.dart';

Future<void> _detectorWorkerMain(Map<String, Object> bootstrap) async {
  final replyPort = bootstrap['replyPort']! as SendPort;
  _LoadedDetector? loaded;
  ReceivePort? commands;

  try {
    final labels = bootstrap['labels']! as List<String>;
    final yoloLabels = bootstrap['yoloLabels']! as List<String>;
    final rawModels = (bootstrap['models']! as List<Object?>)
        .cast<Map<String, Object>>();
    final failures = <String>[];
    final models = <(String, Uint8List)>[
      for (final model in rawModels)
        (model['name']! as String,
         (model['bytes']! as TransferableTypedData).materialize().asUint8List()),
    ];
    var modelIndex = 0;
    for (var i = 0; i < models.length; i++) {
      try {
        loaded = _loadDetector(models[i].$2, models[i].$1);
        modelIndex = i;
        break;
      } catch (error) {
        failures.add('$error');
      }
    }
    if (loaded == null) {
      throw StateError('Nenhum modelo compatível pôde ser iniciado. ${failures.join(' | ')}');
    }
    var activeDetector = loaded;
    final policy = DetectorRuntimePolicy();
    var switchPending = false;
    var switchReason = 'latência sustentada >1200ms';

    commands = ReceivePort();
    replyPort.send(<String, Object>{
      'type': 'ready',
      'port': commands.sendPort,
      'diagnostics': activeDetector.runtime.diagnostics,
    });

    await for (final rawMessage in commands) {
      if (rawMessage is! Map<Object?, Object?>) continue;
      final message = rawMessage;
      final type = message['type'];
      if (type == 'dispose') break;
      if (type != 'detect') continue;

      if (switchPending && modelIndex + 1 < models.length) {
        switchPending = false;
        final next = models[modelIndex + 1];
        try {
          final replacement = _loadDetector(next.$2, next.$1,
              reason: 'troca automática por $switchReason');
          activeDetector.close();
          loaded = replacement;
          activeDetector = replacement;
          modelIndex++;
        } catch (_) {
          // Mantém o modelo funcional se o modelo leve falhar na inicialização.
        }
      }
      final id = message['id']! as int;
      try {
        final width = message['width']! as int;
        final height = message['height']! as int;
        final threshold = (message['threshold']! as num).toDouble();
        final maxResults = message['maxResults']! as int;
        final allowedLabels = (message['allowedLabels'] as List<Object?>?)
            ?.whereType<String>()
            .toSet();
        final workerWatch = Stopwatch()..start();
        final transfer = message['bytes']! as TransferableTypedData;
        final materializeWatch = Stopwatch()..start();
        final rgbBytes = transfer.materialize().asUint8List();
        materializeWatch.stop();

        final payload = _runDetection(
          interpreter: activeDetector.interpreter,
          runtime: activeDetector.runtime,
          labels: activeDetector.runtime.isYolo ? yoloLabels : labels,
          rgbBytes: rgbBytes,
          width: width,
          height: height,
          threshold: threshold,
          maxResults: maxResults,
          allowedLabels: allowedLabels,
        );
        workerWatch.stop();
        switchPending = modelIndex + 1 < models.length &&
            policy.shouldUseLightModel(workerWatch.elapsedMicroseconds / 1000.0);
        if (switchPending) switchReason = 'latência sustentada >1200ms';
        replyPort.send(<String, Object>{
          'diagnostics': activeDetector.runtime.diagnostics,
          'type': 'result',
          'id': id,
          'results': payload.results,
          'timings': <String, double>{
            'workerMaterializeMs': materializeWatch.elapsedMicroseconds / 1000.0,
            'imageBuildMs': payload.imageBuildMs,
            'resizeLetterboxMs': payload.resizeLetterboxMs,
            'tensorBuildMs': payload.tensorBuildMs,
            'liteRtMs': payload.liteRtMs,
            'tensorTransferMs': payload.tensorTransferMs,
            'detectorPostprocessMs': payload.detectorPostprocessMs,
            'workerTotalMs': workerWatch.elapsedMicroseconds / 1000.0,
          },
        });
      } catch (error, stackTrace) {
        // Se o runtime/modelo falhar na inferência, troca na próxima amostra.
        switchPending = modelIndex + 1 < models.length;
        switchReason = 'erro de inferência';
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
    loaded?.close();
    replyPort.send(const <String, Object>{'type': 'disposed'});
  }
}

_DetectorRuntime _inspectInterpreter(Interpreter interpreter, String modelName) {
  final inputTensor = interpreter.getInputTensor(0);
  final inputShape = inputTensor.shape;
  final inputType = inputTensor.type;
  final isYolo = modelName.startsWith('YOLO26');
  final channelLast = inputShape.length == 4 && inputShape[3] == 3;
  final channelFirst = inputShape.length == 4 && inputShape[1] == 3;
  if (!channelLast && !channelFirst) {
    throw StateError('entrada [1,H,W,3] ou [1,3,H,W] esperada: $inputShape');
  }
  if (inputType != TensorType.uint8 && inputType != TensorType.float32) {
    throw StateError('tipo de entrada $inputType não suportado.');
  }
  final outputs = interpreter.getOutputTensors();
  final outputSummary = outputs.asMap().entries.map((entry) {
    return '${entry.key}:${entry.value.shape}/${entry.value.type}';
  }).join(', ');
  final inputWidth = channelLast ? inputShape[2] : inputShape[3];
  final inputHeight = channelLast ? inputShape[1] : inputShape[2];
  if (isYolo) {
    if (outputs.length != 1 || outputs.first.type != TensorType.float32) {
      throw StateError('YOLO26 requer uma saída float32; $outputSummary');
    }
    final shape = outputs.first.shape;
    if (shape.length != 3 || shape[0] != 1 ||
        !(shape[2] == 6 || shape[1] == 84 || shape[2] == 84)) {
      throw StateError('Formato YOLO26 incompatível: $outputSummary');
    }
    return _DetectorRuntime(
      inputWidth: inputWidth,
      inputHeight: inputHeight,
      inputType: inputType,
      maxDetections: shape[1] == 84 ? shape[2] : shape[1],
      isYolo: true,
      channelFirst: channelFirst,
      yoloRows: shape[1],
      yoloColumns: shape[2],
      diagnostics: 'modelo=$modelName; entrada=$inputShape/$inputType; '
          'saida=$outputSummary; formato=YOLO26; letterbox RGB/255',
    );
  }
  if (outputs.length != 4) {
    throw StateError('Esperadas 4 saídas DetectionPostProcess: $outputSummary');
  }
  final boxesShape = outputs[0].shape;
  if (boxesShape.length != 3 || boxesShape.last != 4) {
    throw StateError('saída de caixas não reconhecida: $outputSummary');
  }
  return _DetectorRuntime(
    inputWidth: inputWidth,
    inputHeight: inputHeight,
    inputType: inputType,
    maxDetections: boxesShape[1],
    channelFirst: channelFirst,
    diagnostics: 'modelo=$modelName; entrada=$inputShape/$inputType; '
        'saidas=$outputSummary; maxDetections=${boxesShape[1]}; '
        'preprocessamento=letterbox bilinear; buffers=reutilizados',
  );
}

_WorkerDetectionPayload _runDetection({
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
  final resizeWatch = Stopwatch()..start();
  final transform = runtime.input.fill(rgbBytes, width, height);
  resizeWatch.stop();
  final bridgeWatch = Stopwatch()..start();
  interpreter.runForMultipleInputs(<Object>[runtime.input.bytes.buffer], runtime.output);
  bridgeWatch.stop();
  final nativeMs = interpreter.lastInferenceDurationMicroseconds / 1000.0;
  final transferMs = math.max(0.0, bridgeWatch.elapsedMicroseconds / 1000.0 - nativeMs);

  final postprocessWatch = Stopwatch()..start();
  final List<List<Object>> limited;
  if (runtime.isYolo) {
    limited = YoloDetectionDecoder.decode(
      output: runtime.yoloOutput!.first,
      tensorWidth: runtime.inputWidth,
      tensorHeight: runtime.inputHeight,
      transform: transform,
      labels: labels,
      threshold: threshold,
      maxResults: maxResults,
      allowedLabels: allowedLabels,
    );
  } else {
    final boxList = runtime.boxes!.first;
    final classList = runtime.classes!.first;
    final scoreList = runtime.scores!.first;
    final reportedCount = runtime.count.first.round();
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
    limited = results.length > maxResults ? results.sublist(0, maxResults) : results;
  }
  postprocessWatch.stop();
  return _WorkerDetectionPayload(
    results: limited,
    imageBuildMs: 0,
    resizeLetterboxMs: resizeWatch.elapsedMicroseconds / 1000.0,
    tensorBuildMs: 0,
    liteRtMs: nativeMs,
    tensorTransferMs: transferMs,
    detectorPostprocessMs: postprocessWatch.elapsedMicroseconds / 1000.0,
  );
}

class _WorkerDetectionPayload {
  const _WorkerDetectionPayload({
    required this.results,
    required this.imageBuildMs,
    required this.resizeLetterboxMs,
    required this.tensorBuildMs,
    required this.liteRtMs,
    required this.tensorTransferMs,
    required this.detectorPostprocessMs,
  });

  final List<List<Object>> results;
  final double imageBuildMs;
  final double resizeLetterboxMs;
  final double tensorBuildMs;
  final double liteRtMs;
  final double tensorTransferMs;
  final double detectorPostprocessMs;
}

class _DetectorRuntime {
  _DetectorRuntime({
    required this.inputWidth,
    required this.inputHeight,
    required this.inputType,
    required this.maxDetections,
    required this.diagnostics,
    this.isYolo = false,
    this.channelFirst = false,
    this.yoloRows = 0,
    this.yoloColumns = 0,
  }) : input = DetectorInputBuffer(inputWidth, inputHeight,
           floatingPoint: inputType == TensorType.float32,
           normalization: isYolo
               ? DetectorPixelNormalization.zeroToOne
               : DetectorPixelNormalization.minusOneToOne,
           channelFirst: channelFirst,
           padding: isYolo ? 114 : 0) {
    if (isYolo) {
      yoloOutput = <List<List<double>>>[
        List.generate(yoloRows, (_) => List<double>.filled(yoloColumns, 0.0)),
      ];
      output = <int, Object>{0: yoloOutput!};
    } else {
      boxes = [List.generate(maxDetections, (_) => List<double>.filled(4, 0))];
      classes = [List<double>.filled(maxDetections, 0)];
      scores = [List<double>.filled(maxDetections, 0)];
      output = <int, Object>{0: boxes!, 1: classes!, 2: scores!, 3: count};
    }
  }

  final int inputWidth;
  final int inputHeight;
  final TensorType inputType;
  final int maxDetections;
  final String diagnostics;
  final bool isYolo;
  final bool channelFirst;
  final int yoloRows;
  final int yoloColumns;
  final DetectorInputBuffer input;
  List<List<List<double>>>? yoloOutput;
  List<List<List<double>>>? boxes;
  List<List<double>>? classes;
  List<List<double>>? scores;
  final List<double> count = [0];
  late final Map<int, Object> output;
}
