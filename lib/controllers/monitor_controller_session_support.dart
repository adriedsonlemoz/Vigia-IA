part of 'monitor_controller.dart';

extension _MonitorControllerSessionSupport on MonitorController {
  SessionStatusData _buildSessionStatusImpl() {
    final source = _source;
    final remote = remotePhoneStatus;
    final networkLatency = source is RemotePhoneCameraSource
        ? (source.frameNetworkLatencyMs ?? remote?.networkLatencyMs)
        : null;
    final imageSource = switch (sourceConfig.type) {
      VideoSourceType.localCamera => 'Câmera deste celular',
      VideoSourceType.rtsp => sourceConfig.displayName ?? 'Câmera RTSP',
      VideoSourceType.remotePhone => remote?.name ?? 'Celular remoto',
    };
    final connection = switch (sourceConfig.type) {
      VideoSourceType.localCamera => 'Local • sem rede para a imagem',
      VideoSourceType.rtsp => 'Rede • RTSP',
      VideoSourceType.remotePhone => 'Rede local / hotspot',
    };
    final sourceState = _sourceStatus.state;
    return SessionStatusData(
      sampledAt: DateTime.now(),
      imageSource: imageSource,
      aiDevice: 'Este celular',
      sourceConnection: connection,
      sourceOnline: sourceState == VideoSourceState.streaming,
      sourceConnecting: sourceState == VideoSourceState.connecting ||
          sourceState == VideoSourceState.reconnecting,
      receivedFps: _receivedFps,
      analyzedFps: _fps,
      framesReceived: _framesReceived,
      framesAnalyzed: _framesAnalyzed,
      framesDropped: _framesDropped,
      framesDroppedProcessing: _framesDroppedProcessing,
      framesSkippedOptimization: _framesSkippedOptimization,
      expectedFrameIntervalMs: effectiveAnalysisInterval.inMilliseconds,
      lastFrameReceivedAt: _lastFrameReceivedAt,
      frameWidth: _lastFrameWidth,
      frameHeight: _lastFrameHeight,
      analysisWidth: _lastAnalysisWidth,
      analysisHeight: _lastAnalysisHeight,
      inferenceMs: _lastInferenceMs,
      sourceConversionMs: _lastSourceConversionMs,
      isolateTransferAndQueueMs: _lastIsolateTransferAndQueueMs,
      workerMaterializeMs: _lastWorkerMaterializeMs,
      detectorImageBuildMs: _lastDetectorImageBuildMs,
      resizeLetterboxMs: _lastResizeLetterboxMs,
      tensorBuildMs: _lastTensorBuildMs,
      liteRtMs: _lastLiteRtMs,
      tensorTransferMs: _lastTensorTransferMs,
      detectorPostprocessMs: _lastDetectorPostprocessMs,
      preprocessMs: _lastPreprocessMs,
      primaryInferenceMs: _lastPrimaryInferenceMs,
      auxiliaryInferenceMs: _lastAuxiliaryInferenceMs,
      postprocessMs: _lastPostprocessMs,
      totalProcessingMs: _lastTotalProcessingMs,
      endToEndMs: _lastEndToEndMs,
      detectorRuns: _lastDetectorRuns,
      auxiliaryInferenceRuns: _lastAuxiliaryInferenceRuns,
      detailScansSkippedByBudget: _detailScansSkippedByBudget,
      frameDelayMs: _lastFrameDelayMs,
      networkLatencyMs: networkLatency,
      localDevice: _localDeviceTelemetry,
      remotePhone: remote,
      healthIncidents: List<SessionHealthIncident>.unmodifiable(
        _sessionHealthIncidents,
      ),
    );
  }

  void _sampleSessionHealthImpl() {
    if (_disposed) return;
    final health = _buildSessionStatusImpl().health;
    final codes = health.issues.map((issue) => issue.code).join(',');
    final fingerprint = '${health.state.name}|$codes';
    if (_lastSessionHealthFingerprint == fingerprint) return;

    final previous = _lastSessionHealthFingerprint;
    _lastSessionHealthFingerprint = fingerprint;
    if (previous == null &&
        (health.state == SessionHealthState.healthy ||
            (_framesReceived == 0 &&
                health.issues.length == 1 &&
                health.issues.first.code == 'source_reconnecting'))) {
      return;
    }
    if (health.issues.isEmpty && _sessionHealthIncidents.isEmpty) return;

    final primaryIssue = health.primaryIssue;
    final incident = primaryIssue == null
        ? SessionHealthIncident(
            occurredAt: DateTime.now(),
            state: SessionHealthState.healthy,
            title: 'Sessão normalizada',
            detail: 'Imagem, processamento e recursos voltaram ao estado esperado.',
          )
        : SessionHealthIncident(
            occurredAt: DateTime.now(),
            state: health.state,
            title: primaryIssue.title,
            detail: primaryIssue.detail,
          );
    _sessionHealthIncidents.insert(0, incident);
    if (_sessionHealthIncidents.length > 8) {
      _sessionHealthIncidents.removeRange(8, _sessionHealthIncidents.length);
    }
  }


  void _startSessionTelemetryTimerImpl() {
    _sessionTelemetryTimer?.cancel();
    unawaited(_refreshSessionTelemetryImpl());
    _sessionTelemetryTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_refreshSessionTelemetryImpl()),
    );
  }

  Future<void> _refreshSessionTelemetryImpl() async {
    if (_disposed) return;
    final telemetry = await _native.readDeviceTelemetry();
    if (_disposed) return;
    _localDeviceTelemetry = telemetry;
    _sampleSessionHealthImpl();
    _notify();
  }

  void _configureBikeTelemetryTimerImpl() {
    _bikeTelemetryTimer?.cancel();
    _bikeTelemetryTimer = null;
    if (!_bikeConfig.enabled || !_bikeConfig.keepRemoteTelemetry || _disposed) {
      _lanStream.updateDeviceTelemetry(null);
      return;
    }
    unawaited(_refreshBikeTelemetryImpl());
    _bikeTelemetryTimer = Timer.periodic(
      _bikeConfig.powerProfile.telemetryInterval,
      (_) => unawaited(_refreshBikeTelemetryImpl()),
    );
  }

  Future<void> _refreshBikeTelemetryImpl() async {
    if (_disposed || !_bikeConfig.enabled || !_bikeConfig.keepRemoteTelemetry) return;
    final telemetry = await _native.readDeviceTelemetry();
    if (_disposed) return;
    _lanStream.updateDeviceTelemetry(telemetry);
    final battery = telemetry.batteryPercent;
    if (battery == null || !_bikeConfig.alertLowBattery) return;
    if (battery > _bikeConfig.lowBatteryPercent + 3) {
      _bikeLowBatteryAlerted = false;
      return;
    }
    if (battery <= _bikeConfig.lowBatteryPercent && !_bikeLowBatteryAlerted) {
      _bikeLowBatteryAlerted = true;
      unawaited(
        _native.showAlertNotification(
          title: 'Modo Bike • bateria baixa',
          message: 'Celular traseiro em $battery%. Verifique a alimentação.',
          outputs: _settings.alertOutputs.copyWith(
            voice: false,
            sound: false,
            vibration: false,
            androidNotification: true,
          ),
        ),
      );
    }
  }

  void _recordPerformanceFrameImpl(RgbFrame frame, RgbFrame analysisFrame, {
    required int detectorRuns, required int auxiliaryInferenceRuns,
    int? networkLatency, required int frameDelayMs,
  }) {
    _performanceTelemetry.record(
      PerformanceFrameSample(
        timestamp: DateTime.now(),
        imageSource: _sourceDisplayName,
        detectorDiagnostics: _detector.diagnostics ?? 'detector sem diagnóstico',
        frameWidth: frame.width,
        frameHeight: frame.height,
        analysisWidth: analysisFrame.width,
        analysisHeight: analysisFrame.height,
        receivedFps: _receivedFps,
        analyzedFps: _fps,
        framesReceived: _framesReceived,
        framesAnalyzed: _framesAnalyzed,
        framesDroppedProcessing: _framesDroppedProcessing,
        framesSkippedOptimization: _framesSkippedOptimization,
        detectorRuns: detectorRuns,
        auxiliaryInferenceRuns: auxiliaryInferenceRuns,
        expectedFrameIntervalMs: effectiveAnalysisInterval.inMilliseconds,
        deviceManufacturer: _localDeviceTelemetry?.deviceManufacturer,
        deviceModel: _localDeviceTelemetry?.deviceModel,
        androidVersion: _localDeviceTelemetry?.androidVersion,
        androidSdk: _localDeviceTelemetry?.androidSdk,
        sourceConversionMs: frame.sourceConversionMs,
        sourceTransportMs: frame.sourceTransportMs,
        controllerPreprocessMs: _lastPreprocessMs,
        isolateTransferAndQueueMs: _lastIsolateTransferAndQueueMs,
        workerMaterializeMs: _lastWorkerMaterializeMs,
        detectorImageBuildMs: _lastDetectorImageBuildMs,
        resizeLetterboxMs: _lastResizeLetterboxMs,
        tensorBuildMs: _lastTensorBuildMs,
        liteRtMs: _lastLiteRtMs,
        tensorTransferMs: _lastTensorTransferMs,
        alertContext: <String, Object?>{
          'decision': _lastAlertDecision,
          'frameCapturedAt': frame.capturedAt.toIso8601String(),
          'observationWindowMs': _cadence.window.inMilliseconds,
          'confidence': _settings.confidenceThreshold,
          'voiceEnabled': voiceEnabled,
          'ttsLanguageInstalled': _speech.languageInstalled,
          'androidNotification': _settings.alertOutputs.androidNotification,
          'motionOnly': _settings.motionOnly,
          'confirmationHits': _settings.motionConfirmationHits,
          'rules': _smartRulesDiagnosticContextImpl(),
        },
        detectorPostprocessMs: _lastDetectorPostprocessMs,
        primaryRoundTripMs: _lastPrimaryInferenceMs,
        auxiliaryInferenceMs: _lastAuxiliaryInferenceMs,
        appPostprocessMs: _lastPostprocessMs,
        totalProcessingMs: _lastTotalProcessingMs,
        endToEndMs: _lastEndToEndMs,
        frameDelayMs: frameDelayMs,
        networkLatencyMs: networkLatency,
        cpuPercent: _localDeviceTelemetry?.appCpuPercent,
        ramBytes: _localDeviceTelemetry?.appMemoryUsedBytes,
        batteryTemperatureC: _localDeviceTelemetry?.batteryTemperatureC,
        batteryPercent: _localDeviceTelemetry?.batteryPercent,
      ),
    );
  }

}
