import 'device_telemetry.dart';
import 'remote_phone_status.dart';

part 'session_status_health_analyzer.dart';

enum SessionHealthState { healthy, attention, unstable, disconnected }

enum SessionBottleneck { none, network, capture, ai, device, unknown }

extension SessionHealthStateLabel on SessionHealthState {
  String get label => switch (this) {
        SessionHealthState.healthy => 'Saudável',
        SessionHealthState.attention => 'Atenção',
        SessionHealthState.unstable => 'Instável',
        SessionHealthState.disconnected => 'Desconectado',
      };
}

extension SessionBottleneckLabel on SessionBottleneck {
  String get label => switch (this) {
        SessionBottleneck.none => 'Nenhum',
        SessionBottleneck.network => 'Rede',
        SessionBottleneck.capture => 'Captura de vídeo',
        SessionBottleneck.ai => 'Processamento da IA',
        SessionBottleneck.device => 'Recursos do aparelho',
        SessionBottleneck.unknown => 'Ainda não identificado',
      };
}

class SessionHealthIssue {
  const SessionHealthIssue({
    required this.code,
    required this.title,
    required this.detail,
    required this.state,
    required this.bottleneck,
  });

  final String code;
  final String title;
  final String detail;
  final SessionHealthState state;
  final SessionBottleneck bottleneck;
}

class SessionHealthIncident {
  const SessionHealthIncident({
    required this.occurredAt,
    required this.state,
    required this.title,
    required this.detail,
  });

  final DateTime occurredAt;
  final SessionHealthState state;
  final String title;
  final String detail;
}

class SessionHealthSnapshot {
  const SessionHealthSnapshot({
    required this.state,
    required this.bottleneck,
    required this.issues,
    required this.frameAgeMs,
    required this.processingDropPercent,
    required this.expectedReceivedFps,
  });

  final SessionHealthState state;
  final SessionBottleneck bottleneck;
  final List<SessionHealthIssue> issues;
  final int? frameAgeMs;
  final double processingDropPercent;
  final double expectedReceivedFps;

  SessionHealthIssue? get primaryIssue {
    for (final issue in issues) {
      if (issue.state == state) return issue;
    }
    return issues.isEmpty ? null : issues.first;
  }

  String get summary => primaryIssue?.detail ??
      'Imagem, processamento e recursos estão dentro do esperado.';
}

class SessionStatusData {
  const SessionStatusData({
    required this.sampledAt,
    required this.imageSource,
    required this.aiDevice,
    required this.sourceConnection,
    required this.sourceOnline,
    required this.receivedFps,
    required this.analyzedFps,
    required this.framesReceived,
    required this.framesAnalyzed,
    required this.framesDropped,
    this.framesDroppedProcessing = 0,
    this.framesSkippedOptimization = 0,
    this.expectedFrameIntervalMs = 400,
    this.sourceConnecting = false,
    this.lastFrameReceivedAt,
    this.frameWidth,
    this.frameHeight,
    this.analysisWidth,
    this.analysisHeight,
    this.inferenceMs,
    this.sourceConversionMs,
    this.isolateTransferAndQueueMs,
    this.workerMaterializeMs,
    this.detectorImageBuildMs,
    this.resizeLetterboxMs,
    this.tensorBuildMs,
    this.liteRtMs,
    this.tensorTransferMs,
    this.detectorPostprocessMs,
    this.preprocessMs,
    this.primaryInferenceMs,
    this.auxiliaryInferenceMs,
    this.postprocessMs,
    this.totalProcessingMs,
    this.endToEndMs,
    this.detectorRuns = 0,
    this.auxiliaryInferenceRuns = 0,
    this.detailScansSkippedByBudget = 0,
    this.frameDelayMs,
    this.networkLatencyMs,
    this.localDevice,
    this.remotePhone,
    this.healthIncidents = const <SessionHealthIncident>[],
  });

  final DateTime sampledAt;
  final String imageSource;
  final String aiDevice;
  final String sourceConnection;
  final bool sourceOnline;
  final bool sourceConnecting;
  final double receivedFps;
  final double analyzedFps;
  final int framesReceived;
  final int framesAnalyzed;
  final int framesDropped;
  final int framesDroppedProcessing;
  final int framesSkippedOptimization;
  final int expectedFrameIntervalMs;
  final DateTime? lastFrameReceivedAt;
  final int? frameWidth;
  final int? frameHeight;
  final int? analysisWidth;
  final int? analysisHeight;
  final double? inferenceMs;
  final double? sourceConversionMs;
  final double? isolateTransferAndQueueMs;
  final double? workerMaterializeMs;
  final double? detectorImageBuildMs;
  final double? resizeLetterboxMs;
  final double? tensorBuildMs;
  final double? liteRtMs;
  final double? tensorTransferMs;
  final double? detectorPostprocessMs;
  final double? preprocessMs;
  final double? primaryInferenceMs;
  final double? auxiliaryInferenceMs;
  final double? postprocessMs;
  final double? totalProcessingMs;
  final double? endToEndMs;
  final int detectorRuns;
  final int auxiliaryInferenceRuns;
  final int detailScansSkippedByBudget;
  final int? frameDelayMs;
  final int? networkLatencyMs;
  final DeviceTelemetrySnapshot? localDevice;
  final RemotePhoneStatus? remotePhone;
  final List<SessionHealthIncident> healthIncidents;

  String get frameResolution => frameWidth == null || frameHeight == null
      ? '—'
      : '$frameWidth×$frameHeight';

  String get analysisResolution => analysisWidth == null || analysisHeight == null
      ? '—'
      : '$analysisWidth×$analysisHeight';

  int? get frameAgeMs {
    final last = lastFrameReceivedAt;
    if (last == null) return null;
    final age = sampledAt.difference(last).inMilliseconds;
    return age < 0 ? 0 : age;
  }

  double get expectedReceivedFps => expectedFrameIntervalMs <= 0
      ? 0
      : 1000 / expectedFrameIntervalMs;

  double get processingDropPercent => framesReceived <= 0
      ? 0
      : framesDroppedProcessing * 100 / framesReceived;

  double get processingBudgetUsagePercent {
    final total = totalProcessingMs;
    if (total == null || expectedFrameIntervalMs <= 0) return 0;
    return total * 100 / expectedFrameIntervalMs;
  }

  double? get processingHeadroomMs {
    final total = totalProcessingMs;
    if (total == null) return null;
    return expectedFrameIntervalMs - total;
  }

  String get pipelineHotspot {
    final stages = <String, double?>{
      'Conversão/decodificação da fonte': sourceConversionMs,
      'Pré-processamento do Monitor': preprocessMs,
      'Fila/transferência do isolate': isolateTransferAndQueueMs,
      'Resize + letterbox': resizeLetterboxMs,
      'Montagem do tensor': tensorBuildMs,
      'LiteRT / TFLite': liteRtMs,
      'Transferência dos tensores': tensorTransferMs,
      'Pós-processamento do detector': detectorPostprocessMs,
      'Inferências auxiliares': auxiliaryInferenceMs,
      'Pós-processamento do Monitor': postprocessMs,
    };
    String? label;
    double highest = -1;
    for (final entry in stages.entries) {
      final value = entry.value;
      if (value != null && value > highest) {
        label = entry.key;
        highest = value;
      }
    }
    return label ?? '—';
  }

  SessionHealthSnapshot get health => SessionHealthAnalyzer.evaluate(this);

  String get compactVideoSummary {
    final received = receivedFps > 0 ? receivedFps.toStringAsFixed(1) : '0,0';
    final analyzed = analyzedFps > 0 ? analyzedFps.toStringAsFixed(1) : '0,0';
    final delay = frameDelayMs == null ? 'atraso —' : 'atraso $frameDelayMs ms';
    return '$frameResolution • $received FPS recebidos • $analyzed FPS analisados • $delay';
  }
}
