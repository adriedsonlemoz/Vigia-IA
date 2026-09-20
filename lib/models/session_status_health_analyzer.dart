part of 'session_status.dart';

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

    final sourceConversion = data.sourceConversionMs;
    if (sourceConversion != null && sourceConversion >= expectedInterval * 2.5) {
      issues.add(
        SessionHealthIssue(
          code: 'source_conversion_critical',
          title: 'Conversão da imagem muito lenta',
          detail: 'A preparação RGB da fonte leva ${sourceConversion.toStringAsFixed(0)} ms antes de a IA receber o frame.',
          state: SessionHealthState.unstable,
          bottleneck: SessionBottleneck.capture,
        ),
      );
    } else if (sourceConversion != null &&
        sourceConversion >= expectedInterval * 1.25) {
      issues.add(
        SessionHealthIssue(
          code: 'source_conversion_high',
          title: 'Conversão da imagem lenta',
          detail: 'A preparação RGB da fonte leva ${sourceConversion.toStringAsFixed(0)} ms.',
          state: SessionHealthState.attention,
          bottleneck: SessionBottleneck.capture,
        ),
      );
    }

    final liteRt = data.liteRtMs;
    if (liteRt != null && liteRt >= expectedInterval * 2.5) {
      issues.add(
        SessionHealthIssue(
          code: 'litert_critical',
          title: 'Modelo de IA muito lento',
          detail: 'O LiteRT/TFLite puro leva ${liteRt.toStringAsFixed(0)} ms, muito acima do intervalo de $expectedInterval ms.',
          state: SessionHealthState.unstable,
          bottleneck: SessionBottleneck.ai,
        ),
      );
    } else if (liteRt != null && liteRt >= expectedInterval * 1.25) {
      issues.add(
        SessionHealthIssue(
          code: 'litert_high',
          title: 'Modelo de IA lento',
          detail: 'O LiteRT/TFLite puro leva ${liteRt.toStringAsFixed(0)} ms para um intervalo de $expectedInterval ms.',
          state: SessionHealthState.attention,
          bottleneck: SessionBottleneck.ai,
        ),
      );
    }

    final detectorPreparation = <double?>[
      data.isolateTransferAndQueueMs,
      data.workerMaterializeMs,
      data.detectorImageBuildMs,
      data.resizeLetterboxMs,
      data.tensorBuildMs,
    ].whereType<double>().fold<double>(0, (sum, value) => sum + value);
    if (detectorPreparation >= expectedInterval * 2.5) {
      issues.add(
        SessionHealthIssue(
          code: 'detector_preparation_critical',
          title: 'Preparação da IA muito lenta',
          detail: 'Transferência, resize e montagem do tensor consomem ${detectorPreparation.toStringAsFixed(0)} ms antes/depois do modelo.',
          state: SessionHealthState.unstable,
          bottleneck: SessionBottleneck.ai,
        ),
      );
    } else if (detectorPreparation >= expectedInterval * 1.25) {
      issues.add(
        SessionHealthIssue(
          code: 'detector_preparation_high',
          title: 'Preparação da IA lenta',
          detail: 'Transferência, resize e montagem do tensor consomem ${detectorPreparation.toStringAsFixed(0)} ms.',
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
