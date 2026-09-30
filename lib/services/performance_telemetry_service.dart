import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../core/app_metadata.dart';
import 'native_platform_service.dart';

class PerformanceFrameSample {
  const PerformanceFrameSample({
    required this.timestamp,
    required this.imageSource,
    required this.detectorDiagnostics,
    required this.frameWidth,
    required this.frameHeight,
    required this.analysisWidth,
    required this.analysisHeight,
    required this.receivedFps,
    required this.analyzedFps,
    required this.framesReceived,
    required this.framesAnalyzed,
    required this.framesDroppedProcessing,
    required this.framesSkippedOptimization,
    required this.detectorRuns,
    required this.auxiliaryInferenceRuns,
    required this.expectedFrameIntervalMs,
    this.deviceManufacturer,
    this.deviceModel,
    this.androidVersion,
    this.androidSdk,
    this.sourceConversionMs,
    this.sourceTransportMs,
    this.controllerPreprocessMs,
    this.isolateTransferAndQueueMs,
    this.workerMaterializeMs,
    this.detectorImageBuildMs,
    this.resizeLetterboxMs,
    this.tensorBuildMs,
    this.liteRtMs,
    this.tensorTransferMs,
    this.alertContext = const <String, Object?>{},
    this.detectorPostprocessMs,
    this.primaryRoundTripMs,
    this.auxiliaryInferenceMs,
    this.appPostprocessMs,
    this.totalProcessingMs,
    this.endToEndMs,
    this.frameDelayMs,
    this.networkLatencyMs,
    this.cpuPercent,
    this.ramBytes,
    this.batteryTemperatureC,
    this.batteryPercent,
  });

  final DateTime timestamp;
  final String imageSource;
  final String detectorDiagnostics;
  final int frameWidth;
  final int frameHeight;
  final int analysisWidth;
  final int analysisHeight;
  final double receivedFps;
  final double analyzedFps;
  final int framesReceived;
  final int framesAnalyzed;
  final int framesDroppedProcessing;
  final int framesSkippedOptimization;
  final int detectorRuns;
  final int auxiliaryInferenceRuns;
  final int expectedFrameIntervalMs;
  final String? deviceManufacturer;
  final String? deviceModel;
  final String? androidVersion;
  final int? androidSdk;
  final double? sourceConversionMs;
  final double? sourceTransportMs;
  final double? controllerPreprocessMs;
  final double? isolateTransferAndQueueMs;
  final double? workerMaterializeMs;
  final double? detectorImageBuildMs;
  final double? resizeLetterboxMs;
  final double? tensorBuildMs;
  final double? liteRtMs;
  final double? tensorTransferMs;
  final Map<String, Object?> alertContext;
  final double? detectorPostprocessMs;
  final double? primaryRoundTripMs;
  final double? auxiliaryInferenceMs;
  final double? appPostprocessMs;
  final double? totalProcessingMs;
  final double? endToEndMs;
  final int? frameDelayMs;
  final int? networkLatencyMs;
  final double? cpuPercent;
  final int? ramBytes;
  final double? batteryTemperatureC;
  final int? batteryPercent;

  Map<String, Object?> toJson() => <String, Object?>{
        'timestamp': timestamp.toIso8601String(),
        'imageSource': imageSource,
        'detectorDiagnostics': detectorDiagnostics,
        'frameWidth': frameWidth,
        'frameHeight': frameHeight,
        'analysisWidth': analysisWidth,
        'analysisHeight': analysisHeight,
        'receivedFps': receivedFps,
        'analyzedFps': analyzedFps,
        'framesReceived': framesReceived,
        'framesAnalyzed': framesAnalyzed,
        'framesDroppedProcessing': framesDroppedProcessing,
        'framesSkippedOptimization': framesSkippedOptimization,
        'detectorRuns': detectorRuns,
        'auxiliaryInferenceRuns': auxiliaryInferenceRuns,
        'expectedFrameIntervalMs': expectedFrameIntervalMs,
        'deviceManufacturer': deviceManufacturer,
        'deviceModel': deviceModel,
        'androidVersion': androidVersion,
        'androidSdk': androidSdk,
        'sourceConversionMs': sourceConversionMs,
        'sourceTransportMs': sourceTransportMs,
        'controllerPreprocessMs': controllerPreprocessMs,
        'isolateTransferAndQueueMs': isolateTransferAndQueueMs,
        'workerMaterializeMs': workerMaterializeMs,
        'detectorImageBuildMs': detectorImageBuildMs,
        'resizeLetterboxMs': resizeLetterboxMs,
        'tensorBuildMs': tensorBuildMs,
        'liteRtMs': liteRtMs,
        'tensorTransferMs': tensorTransferMs,
        'alertContext': alertContext,
        'detectorPostprocessMs': detectorPostprocessMs,
        'primaryRoundTripMs': primaryRoundTripMs,
        'auxiliaryInferenceMs': auxiliaryInferenceMs,
        'appPostprocessMs': appPostprocessMs,
        'totalProcessingMs': totalProcessingMs,
        'endToEndMs': endToEndMs,
        'frameDelayMs': frameDelayMs,
        'networkLatencyMs': networkLatencyMs,
        'cpuPercent': cpuPercent,
        'ramBytes': ramBytes,
        'batteryTemperatureC': batteryTemperatureC,
        'batteryPercent': batteryPercent,
      };
}

class PerformanceStageSummary {
  const PerformanceStageSummary({
    required this.count,
    required this.mean,
    required this.minimum,
    required this.maximum,
    required this.p50,
    required this.p90,
    required this.p95,
    required this.p99,
  });

  final int count;
  final double mean;
  final double minimum;
  final double maximum;
  final double p50;
  final double p90;
  final double p95;
  final double p99;

  factory PerformanceStageSummary.fromValues(Iterable<double?> raw) {
    final values = raw.whereType<double>().where((value) => value >= 0).toList()
      ..sort();
    if (values.isEmpty) {
      return const PerformanceStageSummary(
        count: 0,
        mean: 0,
        minimum: 0,
        maximum: 0,
        p50: 0,
        p90: 0,
        p95: 0,
        p99: 0,
      );
    }
    final total = values.fold<double>(0, (sum, value) => sum + value);
    double percentile(double ratio) {
      if (values.length == 1) return values.first;
      final index = ((values.length - 1) * ratio)
          .round()
          .clamp(0, values.length - 1)
          .toInt();
      return values[index];
    }
    return PerformanceStageSummary(
      count: values.length,
      mean: total / values.length,
      minimum: values.first,
      maximum: values.last,
      p50: percentile(0.50),
      p90: percentile(0.90),
      p95: percentile(0.95),
      p99: percentile(0.99),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'count': count,
        'meanMs': mean,
        'minMs': minimum,
        'maxMs': maximum,
        'p50Ms': p50,
        'p90Ms': p90,
        'p95Ms': p95,
        'p99Ms': p99,
      };
}

class PerformanceTelemetryReport {
  const PerformanceTelemetryReport({
    required this.generatedAt,
    required this.sessionStartedAt,
    required this.samples,
    required this.deepTraceSamples,
    required this.deepTraceStartedAt,
    required this.deepTraceEndedAt,
    this.alertEvents = const [],
    this.audioDiagnostics = const {},
  });

  final DateTime generatedAt;
  final DateTime? sessionStartedAt;
  final List<PerformanceFrameSample> samples;
  final List<PerformanceFrameSample> deepTraceSamples;
  final DateTime? deepTraceStartedAt;
  final DateTime? deepTraceEndedAt;
  final List<Map<String, Object?>> alertEvents;
  final Map<String, Object?> audioDiagnostics;

  List<PerformanceFrameSample> get analysisSamples =>
      deepTraceSamples.isNotEmpty ? deepTraceSamples : samples;

  Map<String, PerformanceStageSummary> get stageSummaries {
    final source = analysisSamples;
    return <String, PerformanceStageSummary>{
      'Conversão/decodificação da fonte': PerformanceStageSummary.fromValues(
        source.map((sample) => sample.sourceConversionMs),
      ),
      'Transporte da fonte': PerformanceStageSummary.fromValues(
        source.map((sample) => sample.sourceTransportMs),
      ),
      'Latência de rede': PerformanceStageSummary.fromValues(
        source.map((sample) => sample.networkLatencyMs?.toDouble()),
      ),
      'Fila + transferência entre isolates': PerformanceStageSummary.fromValues(
        source.map((sample) => sample.isolateTransferAndQueueMs),
      ),
      'Materialização no worker': PerformanceStageSummary.fromValues(
        source.map((sample) => sample.workerMaterializeMs),
      ),
      'Criação da imagem RGB no detector': PerformanceStageSummary.fromValues(
        source.map((sample) => sample.detectorImageBuildMs),
      ),
      'Resize + letterbox': PerformanceStageSummary.fromValues(
        source.map((sample) => sample.resizeLetterboxMs),
      ),
      'Montagem do tensor': PerformanceStageSummary.fromValues(
        source.map((sample) => sample.tensorBuildMs),
      ),
      'Transferência dos tensores + API Dart': PerformanceStageSummary.fromValues(
        source.map((sample) => sample.tensorTransferMs),
      ),
      'LiteRT / TFLite nativo': PerformanceStageSummary.fromValues(
        source.map((sample) => sample.liteRtMs),
      ),
      'Pós-processamento do detector': PerformanceStageSummary.fromValues(
        source.map((sample) => sample.detectorPostprocessMs),
      ),
      'Pré-processamento do Monitor': PerformanceStageSummary.fromValues(
        source.map((sample) => sample.controllerPreprocessMs),
      ),
      'Pós-processamento do Monitor': PerformanceStageSummary.fromValues(
        source.map((sample) => sample.appPostprocessMs),
      ),
      'Round-trip da inferência principal': PerformanceStageSummary.fromValues(
        source.map((sample) => sample.primaryRoundTripMs),
      ),
      'Processamento total': PerformanceStageSummary.fromValues(
        source.map((sample) => sample.totalProcessingMs),
      ),
      'Fim a fim': PerformanceStageSummary.fromValues(
        source.map((sample) => sample.endToEndMs),
      ),
    };
  }

  String get likelyBottleneck {
    const candidates = <String>{
      'Conversão/decodificação da fonte',
      'Transporte da fonte',
      'Latência de rede',
      'Fila + transferência entre isolates',
      'Resize + letterbox',
      'Montagem do tensor',
      'LiteRT / TFLite nativo',
      'Transferência dos tensores + API Dart',
      'Pós-processamento do detector',
      'Pré-processamento do Monitor',
      'Pós-processamento do Monitor',
    };
    String best = 'Sem amostras suficientes';
    double highest = -1;
    for (final entry in stageSummaries.entries) {
      if (!candidates.contains(entry.key) || entry.value.count == 0) continue;
      if (entry.value.p50 > highest) {
        highest = entry.value.p50;
        best = entry.key;
      }
    }
    return best;
  }

  String toText() {
    final source = analysisSamples;
    final buffer = StringBuffer()
      ..writeln('Vigia IA - Relatório de desempenho')
      ..writeln('Versão: ${AppMetadata.version}+${AppMetadata.build}')
      ..writeln('Gerado em: ${generatedAt.toIso8601String()}')
      ..writeln('Sessão iniciada: ${sessionStartedAt?.toIso8601String() ?? 'indisponível'}')
      ..writeln(
        deepTraceSamples.isEmpty
            ? 'Amostra usada: telemetria normal (${source.length} frames)'
            : 'Amostra usada: diagnóstico profundo (${source.length} frames)',
      )
      ..writeln('Telemetria normal: ${samples.length}; diagnóstico profundo: ${deepTraceSamples.length} (subconjunto, não somar).')
      ..writeln('Gargalo provável pelos P50: $likelyBottleneck')
      ..writeln();

    if (source.isNotEmpty) {
      final first = source.first;
      final last = source.last;
      final deviceLabel = _deviceLabel(last);
      final androidLabel = _androidLabel(last);
      final sampleDuration = last.timestamp.difference(first.timestamp);
      buffer
        ..writeln('=== CONTEXTO ===')
        ..writeln('Fonte: ${last.imageSource}')
        ..writeln('Detector: ${last.detectorDiagnostics}')
        ..writeln('Aparelho: $deviceLabel')
        ..writeln('Android: $androidLabel')
        ..writeln('Resolução recebida: ${last.frameWidth}x${last.frameHeight}')
        ..writeln('Resolução analisada: ${last.analysisWidth}x${last.analysisHeight}')
        ..writeln('Intervalo alvo: ${last.expectedFrameIntervalMs} ms')
        ..writeln('FPS recebido (último): ${last.receivedFps.toStringAsFixed(2)}')
        ..writeln('FPS analisado (último): ${last.analyzedFps.toStringAsFixed(2)}')
        ..writeln('Frames recebidos: ${last.framesReceived}')
        ..writeln('Frames analisados: ${last.framesAnalyzed}')
        ..writeln('Descartados por IA ocupada: ${last.framesDroppedProcessing}')
        ..writeln('Ignorados por otimização: ${last.framesSkippedOptimization}')
        ..writeln('Janela da amostra: ${first.timestamp.toIso8601String()} -> ${last.timestamp.toIso8601String()}')
        ..writeln('Duração da amostra: ${_durationLabel(sampleDuration)}')
        ..writeln();
    }

    buffer.writeln('=== ETAPAS (ms) ===');
    for (final entry in stageSummaries.entries) {
      final value = entry.value;
      if (value.count == 0) continue;
      buffer.writeln(
        '${entry.key}: média ${value.mean.toStringAsFixed(1)} | '
        'min ${value.minimum.toStringAsFixed(1)} | max ${value.maximum.toStringAsFixed(1)} | '
        'P50 ${value.p50.toStringAsFixed(1)} | P90 ${value.p90.toStringAsFixed(1)} | '
        'P95 ${value.p95.toStringAsFixed(1)} | P99 ${value.p99.toStringAsFixed(1)}',
      );
    }

    if (source.isNotEmpty) {
      final occurrences = <String>[];
      for (final sample in source.reversed) {
        final total = sample.totalProcessingMs;
        final liteRt = sample.liteRtMs;
        final temperature = sample.batteryTemperatureC;
        if (total != null && total > sample.expectedFrameIntervalMs * 1.25) {
          occurrences.add(
            '${sample.timestamp.toIso8601String()} • pipeline ${total.toStringAsFixed(0)} ms para orçamento de ${sample.expectedFrameIntervalMs} ms',
          );
        } else if (liteRt != null &&
            liteRt > sample.expectedFrameIntervalMs * 0.70) {
          occurrences.add(
            '${sample.timestamp.toIso8601String()} • LiteRT ${liteRt.toStringAsFixed(0)} ms',
          );
        } else if (temperature != null && temperature >= 42) {
          occurrences.add(
            '${sample.timestamp.toIso8601String()} • temperatura ${temperature.toStringAsFixed(1)} °C',
          );
        }
        if (occurrences.length >= 30) break;
      }
      buffer
        ..writeln()
        ..writeln('=== OCORRÊNCIAS IMPORTANTES ===');
      if (occurrences.isEmpty) {
        buffer.writeln('Nenhuma ocorrência relevante na amostra.');
      } else {
        for (final occurrence in occurrences.reversed) {
          buffer.writeln(occurrence);
        }
      }

      final cpu = PerformanceStageSummary.fromValues(source.map((s) => s.cpuPercent));
      final temp = PerformanceStageSummary.fromValues(
        source.map((s) => s.batteryTemperatureC),
      );
      buffer
        ..writeln()
        ..writeln('=== RECURSOS ===')
        ..writeln(
          cpu.count == 0
              ? 'CPU do app: indisponível'
              : 'CPU do app: média ${cpu.mean.toStringAsFixed(1)}% | P95 ${cpu.p95.toStringAsFixed(1)}%',
        )
        ..writeln(
          temp.count == 0
              ? 'Temperatura: indisponível'
              : 'Temperatura: média ${temp.mean.toStringAsFixed(1)} °C | máx ${temp.maximum.toStringAsFixed(1)} °C',
        );
    }
    buffer
      ..writeln('\n=== ÁUDIO / DECISÃO DE ALERTA ===')
      ..writeln('Estado: ${audioDiagnostics['state'] ?? 'indisponível'}')
      ..writeln('Último resultado: ${audioDiagnostics['lastPlaybackResult'] ?? 'indisponível'}')
      ..writeln('Origem: ${audioDiagnostics['lastSource'] ?? 'indisponível'}')
      ..writeln('Fallback para áudio integrado: ${audioDiagnostics['lastPlaybackUsedFallback'] == true ? 'sim' : 'não'}')
      ..writeln('Motivo do fallback: ${audioDiagnostics['lastFallbackReason'] ?? 'nenhum'}')
      ..writeln('Erro: ${audioDiagnostics['lastErrorCode'] ?? 'nenhum'}')
      ..writeln('Detalhe: ${audioDiagnostics['lastError'] ?? 'nenhum'}')
      ..writeln('Etapa: ${audioDiagnostics['lastErrorPhase'] ?? 'indisponível'}')
      ..writeln('Foco de áudio: ${audioDiagnostics['lastFocusResultName'] ?? 'indisponível'}')
      ..writeln('Volume: ${audioDiagnostics['mediaVolume'] ?? '?'} / ${audioDiagnostics['mediaMaxVolume'] ?? '?'}')
      ..writeln('Diagnóstico Android completo: ${jsonEncode(audioDiagnostics)}')
      ..writeln('Última decisão: ${source.isEmpty ? '{}' : jsonEncode(source.last.alertContext)}');
    for (final event in alertEvents) { buffer.writeln(jsonEncode(event)); }
    return buffer.toString();
  }


  static String _deviceLabel(PerformanceFrameSample sample) {
    final manufacturer = sample.deviceManufacturer?.trim();
    final model = sample.deviceModel?.trim();
    final parts = <String>[
      if (manufacturer != null && manufacturer.isNotEmpty) manufacturer,
      if (model != null && model.isNotEmpty) model,
    ];
    return parts.isEmpty ? 'indisponível' : parts.join(' ');
  }

  static String _androidLabel(PerformanceFrameSample sample) {
    final version = sample.androidVersion?.trim();
    final base = version == null || version.isEmpty ? 'indisponível' : version;
    final sdk = sample.androidSdk;
    return sdk == null ? base : '$base (SDK $sdk)';
  }

  static String _durationLabel(Duration duration) {
    if (duration.isNegative) return '0 s';
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) return '${hours}h ${minutes}min ${seconds}s';
    if (minutes > 0) return '${minutes}min ${seconds}s';
    return '${seconds}s';
  }

  String toJsonText() => const JsonEncoder.withIndent('  ').convert(
        <String, Object?>{
          'app': <String, Object?>{
            'name': AppMetadata.name,
            'version': AppMetadata.version,
            'build': AppMetadata.build,
          },
          'schemaVersion': 3,
          'audioDiagnostics': audioDiagnostics,
          'alertEvents': alertEvents,
          'summaryScope': deepTraceSamples.isEmpty ? 'normal' : 'deepTraceSubset',
          'generatedAt': generatedAt.toIso8601String(),
          'sessionStartedAt': sessionStartedAt?.toIso8601String(),
          'deepTraceStartedAt': deepTraceStartedAt?.toIso8601String(),
          'deepTraceEndedAt': deepTraceEndedAt?.toIso8601String(),
          'likelyBottleneck': likelyBottleneck,
          'summaries': stageSummaries.map(
            (key, value) => MapEntry(key, value.toJson()),
          ),
          'samples': samples.map((sample) => sample.toJson()).toList(),
          'deepTraceSamples': deepTraceSamples
              .map((sample) => sample.toJson())
              .toList(),
        },
      );

  String toCsv() {
    const columns = <String>[
      'timestamp',
      'source',
      'frame',
      'analysis',
      'receivedFps',
      'analyzedFps',
      'sourceConversionMs',
      'sourceTransportMs',
      'controllerPreprocessMs',
      'isolateTransferAndQueueMs',
      'workerMaterializeMs',
      'detectorImageBuildMs',
      'resizeLetterboxMs',
      'tensorBuildMs',
      'liteRtMs',
      'tensorTransferMs',
      'detectorPostprocessMs',
      'primaryRoundTripMs',
      'auxiliaryInferenceMs',
      'appPostprocessMs',
      'totalProcessingMs',
      'endToEndMs',
      'frameDelayMs',
      'networkLatencyMs',
      'cpuPercent',
      'ramBytes',
      'batteryTemperatureC',
      'batteryPercent',
      'framesReceived',
      'framesAnalyzed',
      'framesDroppedProcessing',
      'framesSkippedOptimization',
      'detectorRuns',
      'auxiliaryInferenceRuns',
      'expectedFrameIntervalMs',
    ];
    String esc(Object? value) {
      final text = value?.toString() ?? '';
      if (!text.contains(',') && !text.contains('"') && !text.contains('\n')) {
        return text;
      }
      return '"${text.replaceAll('"', '""')}"';
    }
    final buffer = StringBuffer()..writeln(columns.join(','));
    for (final sample in analysisSamples) {
      buffer.writeln(<Object?>[
        sample.timestamp.toIso8601String(),
        sample.imageSource,
        '${sample.frameWidth}x${sample.frameHeight}',
        '${sample.analysisWidth}x${sample.analysisHeight}',
        sample.receivedFps,
        sample.analyzedFps,
        sample.sourceConversionMs,
        sample.sourceTransportMs,
        sample.controllerPreprocessMs,
        sample.isolateTransferAndQueueMs,
        sample.workerMaterializeMs,
        sample.detectorImageBuildMs,
        sample.resizeLetterboxMs,
        sample.tensorBuildMs,
        sample.liteRtMs,
        sample.tensorTransferMs,
        sample.detectorPostprocessMs,
        sample.primaryRoundTripMs,
        sample.auxiliaryInferenceMs,
        sample.appPostprocessMs,
        sample.totalProcessingMs,
        sample.endToEndMs,
        sample.frameDelayMs,
        sample.networkLatencyMs,
        sample.cpuPercent,
        sample.ramBytes,
        sample.batteryTemperatureC,
        sample.batteryPercent,
        sample.framesReceived,
        sample.framesAnalyzed,
        sample.framesDroppedProcessing,
        sample.framesSkippedOptimization,
        sample.detectorRuns,
        sample.auxiliaryInferenceRuns,
        sample.expectedFrameIntervalMs,
      ].map(esc).join(','));
    }
    return buffer.toString();
  }
}

class PerformanceTelemetryService extends ChangeNotifier {
  PerformanceTelemetryService._();

  static final PerformanceTelemetryService instance =
      PerformanceTelemetryService._();

  static const int _maxRollingSamples = 600;
  static const int _maxDeepSamples = 900;

  final List<PerformanceFrameSample> _samples = <PerformanceFrameSample>[];
  final List<PerformanceFrameSample> _deepTraceSamples =
      <PerformanceFrameSample>[];
  final List<Map<String, Object?>> _alertEvents = [];
  Map<String, Object?> _audioDiagnostics = {};
  DateTime? _sessionStartedAt;
  DateTime? _deepTraceStartedAt;
  DateTime? _deepTraceEndsAt;
  DateTime? _deepTraceEndedAt;
  Timer? _deepTraceTimer;

  DateTime? get sessionStartedAt => _sessionStartedAt;
  DateTime? get deepTraceEndsAt => _deepTraceEndsAt;
  bool get deepTraceActive {
    final endsAt = _deepTraceEndsAt;
    return endsAt != null && DateTime.now().isBefore(endsAt);
  }
  int get sampleCount => _samples.length;
  int get deepTraceSampleCount => _deepTraceSamples.length;

  void resetSession() {
    _samples.clear();
    _alertEvents.clear();
    _audioDiagnostics = {};
    _deepTraceSamples.clear();
    _sessionStartedAt = DateTime.now();
    _deepTraceStartedAt = null;
    _deepTraceEndsAt = null;
    _deepTraceEndedAt = null;
    _deepTraceTimer?.cancel();
    _deepTraceTimer = null;
    notifyListeners();
  }

  void record(PerformanceFrameSample sample) {
    _sessionStartedAt ??= sample.timestamp;
    _samples.add(sample);
    if (_samples.length > _maxRollingSamples) {
      _samples.removeRange(0, _samples.length - _maxRollingSamples);
    }
    if (deepTraceActive && _deepTraceSamples.length < _maxDeepSamples) {
      _deepTraceSamples.add(sample);
    }
    notifyListeners();
  }

  void recordAlertEvent(Map<String, Object?> event) {
    _alertEvents.add(Map<String, Object?>.unmodifiable(event));
    if (_alertEvents.length > 100) _alertEvents.removeAt(0);
  }

  Future<void> refreshAudioDiagnostics() async {
    _audioDiagnostics = await NativePlatformService.instance.audioDiagnostics();
  }

  void startDeepTrace(Duration duration) {
    final normalized = Duration(
      seconds: duration.inSeconds.clamp(10, 120).toInt(),
    );
    _deepTraceTimer?.cancel();
    _deepTraceSamples.clear();
    final startedAt = DateTime.now();
    _deepTraceStartedAt = startedAt;
    _deepTraceEndsAt = startedAt.add(normalized);
    _deepTraceEndedAt = null;
    _deepTraceTimer = Timer(normalized, () {
      _deepTraceEndedAt = DateTime.now();
      _deepTraceEndsAt = null;
      notifyListeners();
    });
    notifyListeners();
  }

  void stopDeepTrace() {
    if (_deepTraceStartedAt == null) return;
    _deepTraceTimer?.cancel();
    _deepTraceTimer = null;
    _deepTraceEndedAt = DateTime.now();
    _deepTraceEndsAt = null;
    notifyListeners();
  }

  PerformanceTelemetryReport createReport() => PerformanceTelemetryReport(
        generatedAt: DateTime.now(),
        alertEvents: List.unmodifiable(_alertEvents),
        audioDiagnostics: Map.unmodifiable(_audioDiagnostics),
        sessionStartedAt: _sessionStartedAt,
        samples: List<PerformanceFrameSample>.unmodifiable(_samples),
        deepTraceSamples:
            List<PerformanceFrameSample>.unmodifiable(_deepTraceSamples),
        deepTraceStartedAt: _deepTraceStartedAt,
        deepTraceEndedAt: _deepTraceEndedAt ?? _deepTraceEndsAt,
      );

  Future<String?> exportToDownloads() async {
    await refreshAudioDiagnostics();
    final report = createReport();
    final bytes = _buildReportZip(report);
    return NativePlatformService.instance.saveBytesToDownloads(
      fileName: 'vigiaia_desempenho_${_stamp(report.generatedAt)}.zip',
      mimeType: 'application/zip',
      bytes: bytes,
    );
  }

  Future<String?> exportWithPicker() async {
    await refreshAudioDiagnostics();
    final report = createReport();
    final bytes = _buildReportZip(report);
    return NativePlatformService.instance.saveBytesWithPicker(
      fileName: 'vigiaia_desempenho_${_stamp(report.generatedAt)}.zip',
      mimeType: 'application/zip',
      bytes: bytes,
    );
  }

  Uint8List _buildReportZip(PerformanceTelemetryReport report) {
    final entries = <String, Uint8List>{
      'resumo.txt': Uint8List.fromList(utf8.encode(report.toText())),
      'telemetria.json': Uint8List.fromList(utf8.encode(report.toJsonText())),
      'telemetria.csv': Uint8List.fromList(utf8.encode(report.toCsv())),
    };
    return _StoredZipWriter.encode(entries);
  }

  String _stamp(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}${two(value.month)}${two(value.day)}-'
        '${two(value.hour)}${two(value.minute)}${two(value.second)}';
  }
}

class _StoredZipWriter {
  const _StoredZipWriter._();

  static Uint8List encode(Map<String, Uint8List> entries) {
    final output = BytesBuilder(copy: false);
    final central = BytesBuilder(copy: false);
    var offset = 0;
    var count = 0;
    for (final entry in entries.entries) {
      final name = Uint8List.fromList(utf8.encode(entry.key));
      final data = entry.value;
      final crc = _crc32(data);
      final local = BytesBuilder(copy: false)
        ..add(_u32(0x04034b50))
        ..add(_u16(20))
        ..add(_u16(0))
        ..add(_u16(0))
        ..add(_u16(0))
        ..add(_u16(0))
        ..add(_u32(crc))
        ..add(_u32(data.length))
        ..add(_u32(data.length))
        ..add(_u16(name.length))
        ..add(_u16(0))
        ..add(name)
        ..add(data);
      final localBytes = local.takeBytes();
      output.add(localBytes);

      central
        ..add(_u32(0x02014b50))
        ..add(_u16(20))
        ..add(_u16(20))
        ..add(_u16(0))
        ..add(_u16(0))
        ..add(_u16(0))
        ..add(_u16(0))
        ..add(_u32(crc))
        ..add(_u32(data.length))
        ..add(_u32(data.length))
        ..add(_u16(name.length))
        ..add(_u16(0))
        ..add(_u16(0))
        ..add(_u16(0))
        ..add(_u16(0))
        ..add(_u32(0))
        ..add(_u32(offset))
        ..add(name);
      offset += localBytes.length;
      count++;
    }
    final centralBytes = central.takeBytes();
    output.add(centralBytes);
    output
      ..add(_u32(0x06054b50))
      ..add(_u16(0))
      ..add(_u16(0))
      ..add(_u16(count))
      ..add(_u16(count))
      ..add(_u32(centralBytes.length))
      ..add(_u32(offset))
      ..add(_u16(0));
    return output.takeBytes();
  }

  static Uint8List _u16(int value) {
    final data = ByteData(2)..setUint16(0, value, Endian.little);
    return data.buffer.asUint8List();
  }

  static Uint8List _u32(int value) {
    final data = ByteData(4)..setUint32(0, value, Endian.little);
    return data.buffer.asUint8List();
  }

  static int _crc32(Uint8List bytes) {
    var crc = 0xffffffff;
    for (final byte in bytes) {
      var value = (crc ^ byte) & 0xff;
      for (var bit = 0; bit < 8; bit++) {
        value = (value & 1) != 0
            ? (value >> 1) ^ 0xedb88320
            : value >> 1;
      }
      crc = (crc >> 8) ^ value;
    }
    return (crc ^ 0xffffffff) & 0xffffffff;
  }
}
