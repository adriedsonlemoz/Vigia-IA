import 'device_telemetry.dart';
import 'remote_phone_status.dart';

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
      'Pré-processamento': preprocessMs,
      'Inferência principal': primaryInferenceMs,
      'Inferências auxiliares': auxiliaryInferenceMs,
      'Pós-processamento': postprocessMs,
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

class SessionHealthAnalyzer {
  const SessionHealthAnalyzer._();

  static SessionHealthSnapshot evaluate(SessionStatusData data) {
    final issues = <SessionHealthIssue>[];
    final expectedInterval = data.expectedFrameIntervalMs.clamp(250, 5000);
    final staleAfterMs = (expectedInterval * 4).clamp(2500, 8000);
    final frozenAfterMs = (expectedInterval * 8).clamp(5000, 15000);
    final frameAge = data.frameAgeMs;

    if (!data.sourceOnline) {
      issues.add(
        SessionHealthIssue(
          code: data.sourceConnecting ? 'source_reconnecting' : 'source_offline',
          title: data.sourceConnecting ? 'Fonte reconectando' : 'Fonte desconectada',
          detail: data.sourceConnecting
              ? 'A sessão está tentando recuperar a fonte de imagem.'
              : 'Não há imagem ativa chegando à sessão.',
          state: data.sourceConnecting
              ? SessionHealthState.attention
              : SessionHealthState.disconnected,
          bottleneck: SessionBottleneck.capture,
        ),
      );
    }

    if (data.sourceOnline && frameAge != null && frameAge >= frozenAfterMs) {
      issues.add(
        SessionHealthIssue(
          code: 'frame_frozen',
          title: 'Imagem sem atualização',
          detail: 'O último frame tem ${_durationLabel(frameAge)} de idade. A imagem pode estar congelada.',
          state: SessionHealthState.unstable,
          bottleneck: data.networkLatencyMs == null
              ? SessionBottleneck.capture
              : SessionBottleneck.network,
        ),
      );
    } else if (data.sourceOnline && frameAge != null && frameAge >= staleAfterMs) {
      issues.add(
        SessionHealthIssue(
          code: 'frame_stale',
          title: 'Frame atrasado',
          detail: 'Nenhum frame novo chegou há ${_durationLabel(frameAge)}.',
          state: SessionHealthState.attention,
          bottleneck: data.networkLatencyMs == null
              ? SessionBottleneck.capture
              : SessionBottleneck.network,
        ),
      );
    }

    final networkLatency = data.networkLatencyMs;
    if (networkLatency != null && networkLatency >= 1000) {
      issues.add(
        SessionHealthIssue(
          code: 'network_latency_critical',
          title: 'Latência de rede muito alta',
          detail: 'A comunicação com a fonte está levando $networkLatency ms.',
          state: SessionHealthState.unstable,
          bottleneck: SessionBottleneck.network,
        ),
      );
    } else if (networkLatency != null && networkLatency >= 400) {
      issues.add(
        SessionHealthIssue(
          code: 'network_latency_high',
          title: 'Latência de rede elevada',
          detail: 'A comunicação com a fonte está levando $networkLatency ms.',
          state: SessionHealthState.attention,
          bottleneck: SessionBottleneck.network,
        ),
      );
    }

    final frameDelay = data.frameDelayMs;
    if (frameDelay != null && frameDelay >= 2000) {
      issues.add(
        SessionHealthIssue(
          code: 'frame_delay_critical',
          title: 'Imagem muito atrasada',
          detail: 'O frame chega cerca de ${_durationLabel(frameDelay)} depois da captura.',
          state: SessionHealthState.unstable,
          bottleneck: data.networkLatencyMs == null
              ? SessionBottleneck.capture
              : SessionBottleneck.network,
        ),
      );
    } else if (frameDelay != null && frameDelay >= 750) {
      issues.add(
        SessionHealthIssue(
          code: 'frame_delay_high',
          title: 'Atraso da imagem elevado',
          detail: 'O frame chega cerca de ${_durationLabel(frameDelay)} depois da captura.',
          state: SessionHealthState.attention,
          bottleneck: data.networkLatencyMs == null
              ? SessionBottleneck.capture
              : SessionBottleneck.network,
        ),
      );
    }

    final expectedFps = data.expectedReceivedFps;
    if (data.sourceOnline &&
        data.framesReceived >= 5 &&
        expectedFps > 0 &&
        data.receivedFps > 0 &&
        data.receivedFps < expectedFps * 0.45) {
      issues.add(
        SessionHealthIssue(
          code: 'received_fps_low',
          title: 'FPS recebido abaixo do esperado',
          detail: 'Chegam ${data.receivedFps.toStringAsFixed(1)} FPS para uma meta aproximada de ${expectedFps.toStringAsFixed(1)} FPS.',
          state: SessionHealthState.attention,
          bottleneck: data.networkLatencyMs == null
              ? SessionBottleneck.capture
              : SessionBottleneck.network,
        ),
      );
    }

    final inference = data.inferenceMs;
    if (inference != null && inference >= expectedInterval * 2.5) {
      issues.add(
        SessionHealthIssue(
          code: 'inference_critical',
          title: 'IA não acompanha a entrada',
          detail: 'A inferência leva ${inference.toStringAsFixed(0)} ms, muito acima do intervalo de $expectedInterval ms.',
          state: SessionHealthState.unstable,
          bottleneck: SessionBottleneck.ai,
        ),
      );
    } else if (inference != null && inference >= expectedInterval * 1.25) {
      issues.add(
        SessionHealthIssue(
          code: 'inference_high',
          title: 'Inferência lenta',
          detail: 'A inferência leva ${inference.toStringAsFixed(0)} ms para um intervalo de $expectedInterval ms.',
          state: SessionHealthState.attention,
          bottleneck: SessionBottleneck.ai,
        ),
      );
    }

    final totalProcessing = data.totalProcessingMs;
    if (totalProcessing != null && totalProcessing >= expectedInterval * 1.5) {
      issues.add(
        SessionHealthIssue(
          code: 'pipeline_budget_critical',
          title: 'Pipeline acima do orçamento',
          detail: 'O processamento completo levou ${totalProcessing.toStringAsFixed(0)} ms para um orçamento de $expectedInterval ms.',
          state: SessionHealthState.unstable,
          bottleneck: SessionBottleneck.ai,
        ),
      );
    } else if (totalProcessing != null &&
        totalProcessing >= expectedInterval * 0.95) {
      issues.add(
        SessionHealthIssue(
          code: 'pipeline_budget_high',
          title: 'Pipeline perto do limite',
          detail: 'O processamento completo usou ${data.processingBudgetUsagePercent.toStringAsFixed(0)}% do intervalo disponível.',
          state: SessionHealthState.attention,
          bottleneck: SessionBottleneck.ai,
        ),
      );
    }

    final processingDrop = data.processingDropPercent;
    if (data.framesReceived >= 10 && processingDrop >= 50) {
      issues.add(
        SessionHealthIssue(
          code: 'processing_drop_critical',
          title: 'Muitos frames perdidos no processamento',
          detail: '${processingDrop.toStringAsFixed(0)}% dos frames recebidos chegaram enquanto a IA ainda estava ocupada.',
          state: SessionHealthState.unstable,
          bottleneck: SessionBottleneck.ai,
        ),
      );
    } else if (data.framesReceived >= 10 && processingDrop >= 20) {
      issues.add(
        SessionHealthIssue(
          code: 'processing_drop_high',
          title: 'Frames descartados por processamento',
          detail: '${processingDrop.toStringAsFixed(0)}% dos frames recebidos chegaram enquanto a IA ainda estava ocupada.',
          state: SessionHealthState.attention,
          bottleneck: SessionBottleneck.ai,
        ),
      );
    }

    if (data.remotePhone?.isStale(data.sampledAt) == true) {
      issues.add(
        const SessionHealthIssue(
          code: 'remote_telemetry_stale',
          title: 'Telemetria remota atrasada',
          detail: 'O vídeo pode continuar ativo, mas o estado do celular remoto deixou de ser atualizado recentemente.',
          state: SessionHealthState.attention,
          bottleneck: SessionBottleneck.network,
        ),
      );
    }

    _appendDeviceIssues(issues, data.localDevice, 'deste celular');
    _appendDeviceIssues(issues, data.remotePhone?.device, 'do celular remoto');

    final state = _highestState(issues);
    final bottleneck = _primaryBottleneck(issues, state);
    return SessionHealthSnapshot(
      state: state,
      bottleneck: bottleneck,
      issues: List<SessionHealthIssue>.unmodifiable(issues),
      frameAgeMs: frameAge,
      processingDropPercent: processingDrop,
      expectedReceivedFps: expectedFps,
    );
  }

  static void _appendDeviceIssues(
    List<SessionHealthIssue> issues,
    DeviceTelemetrySnapshot? device,
    String deviceLabel,
  ) {
    if (device == null) return;
    final battery = device.batteryPercent;
    if (device.batteryCharging != true && battery != null && battery <= 10) {
      issues.add(
        SessionHealthIssue(
          code: 'device_battery_critical_$deviceLabel',
          title: 'Bateria crítica',
          detail: 'Restam $battery% de bateria $deviceLabel.',
          state: SessionHealthState.unstable,
          bottleneck: SessionBottleneck.device,
        ),
      );
    } else if (device.batteryCharging != true && battery != null && battery <= 20) {
      issues.add(
        SessionHealthIssue(
          code: 'device_battery_low_$deviceLabel',
          title: 'Bateria baixa',
          detail: 'Restam $battery% de bateria $deviceLabel.',
          state: SessionHealthState.attention,
          bottleneck: SessionBottleneck.device,
        ),
      );
    }

    final temperature = device.batteryTemperatureC;
    if (temperature != null && temperature >= 45) {
      issues.add(
        SessionHealthIssue(
          code: 'device_temperature_critical_$deviceLabel',
          title: 'Temperatura alta',
          detail: 'A bateria $deviceLabel está em ${temperature.toStringAsFixed(1)} °C.',
          state: SessionHealthState.unstable,
          bottleneck: SessionBottleneck.device,
        ),
      );
    } else if (temperature != null && temperature >= 40) {
      issues.add(
        SessionHealthIssue(
          code: 'device_temperature_high_$deviceLabel',
          title: 'Temperatura elevada',
          detail: 'A bateria $deviceLabel está em ${temperature.toStringAsFixed(1)} °C.',
          state: SessionHealthState.attention,
          bottleneck: SessionBottleneck.device,
        ),
      );
    }

    final available = device.memoryAvailableBytes;
    final total = device.memoryTotalBytes;
    if (available != null && total != null && total > 0) {
      final availableRatio = available / total;
      if (availableRatio <= 0.05) {
        issues.add(
          SessionHealthIssue(
            code: 'device_memory_critical_$deviceLabel',
            title: 'RAM quase esgotada',
            detail: 'Há menos de 5% de RAM disponível $deviceLabel.',
            state: SessionHealthState.unstable,
            bottleneck: SessionBottleneck.device,
          ),
        );
      } else if (availableRatio <= 0.10) {
        issues.add(
          SessionHealthIssue(
            code: 'device_memory_low_$deviceLabel',
            title: 'Pouca RAM disponível',
            detail: 'Há menos de 10% de RAM disponível $deviceLabel.',
            state: SessionHealthState.attention,
            bottleneck: SessionBottleneck.device,
          ),
        );
      }
    }

    final cpu = device.appCpuPercent;
    if (cpu != null && cpu >= 90) {
      issues.add(
        SessionHealthIssue(
          code: 'device_cpu_high_$deviceLabel',
          title: 'CPU do Vigia IA elevada',
          detail: 'O Vigia IA está usando ${cpu.toStringAsFixed(0)}% de CPU $deviceLabel.',
          state: SessionHealthState.attention,
          bottleneck: SessionBottleneck.device,
        ),
      );
    }
  }

  static SessionHealthState _highestState(List<SessionHealthIssue> issues) {
    if (issues.any((issue) => issue.state == SessionHealthState.disconnected)) {
      return SessionHealthState.disconnected;
    }
    if (issues.any((issue) => issue.state == SessionHealthState.unstable)) {
      return SessionHealthState.unstable;
    }
    if (issues.any((issue) => issue.state == SessionHealthState.attention)) {
      return SessionHealthState.attention;
    }
    return SessionHealthState.healthy;
  }

  static SessionBottleneck _primaryBottleneck(
    List<SessionHealthIssue> issues,
    SessionHealthState state,
  ) {
    if (issues.isEmpty) return SessionBottleneck.none;
    for (final issue in issues) {
      if (issue.state == state) return issue.bottleneck;
    }
    return issues.first.bottleneck;
  }

  static String _durationLabel(int milliseconds) {
    if (milliseconds < 1000) return '$milliseconds ms';
    final seconds = milliseconds / 1000;
    return '${seconds.toStringAsFixed(seconds >= 10 ? 0 : 1)} s';
  }
}
