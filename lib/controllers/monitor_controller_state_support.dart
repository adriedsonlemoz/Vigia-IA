part of 'monitor_controller.dart';

extension _MonitorControllerStateSupport on MonitorController {
  void _resetSessionMetricsImpl() {
    _receivedFps = 0;
    _fps = 0;
    _lastReceivedFpsSample = null;
    _lastAnalyzedFpsSample = null;
    _framesReceived = 0;
    _framesAnalyzed = 0;
    _framesDropped = 0;
    _framesDroppedProcessing = 0;
    _framesSkippedOptimization = 0;
    _sessionHealthIncidents.clear();
    _lastSessionHealthFingerprint = null;
    _lastFrameWidth = null;
    _lastFrameHeight = null;
    _lastAnalysisWidth = null;
    _lastAnalysisHeight = null;
    _lastFrameDelayMs = null;
    _lastInferenceMs = null;
    _lastSourceConversionMs = null;
    _lastIsolateTransferAndQueueMs = null;
    _lastWorkerMaterializeMs = null;
    _lastDetectorImageBuildMs = null;
    _lastResizeLetterboxMs = null;
    _lastTensorBuildMs = null;
    _lastLiteRtMs = null;
    _lastDetectorPostprocessMs = null;
    _lastPreprocessMs = null;
    _lastPrimaryInferenceMs = null;
    _lastAuxiliaryInferenceMs = null;
    _lastPostprocessMs = null;
    _lastTotalProcessingMs = null;
    _lastEndToEndMs = null;
    _lastDetectorRuns = 0;
    _lastAuxiliaryInferenceRuns = 0;
    _detailScansSkippedByBudget = 0;
    _performanceTelemetry.resetSession();
  }

  void _resetAfterZoneChangeImpl() {
    _frameSession++;
    _motion.reset();
    _clipRecorder.resetBuffer();
    _resetEventStateImpl();
    _notify();
  }

  void _resetRulesAndTrackingImpl() {
    if (_baseReady) {
      _alertGuard.reset();
      _smartRuleEngine.reset();
    }
    _tracker.reset();
    _detectionFilter.reset();
    _recentMotionByTrackId.clear();
    _lastIdleInferenceAt = null;
    _lastDetailScanAt = null;
    _detailTileIndex = 0;
    _seenTrackIds.clear();
    _lastTransitionSpeechAt.clear();
    _trackedDetections = const <TrackedDetection>[];
    _resetBikeApproach();
  }

  void _resetEventStateImpl() {
    _detections = const [];
    _trackedDetections = const <TrackedDetection>[];
    if (_baseReady) {
      _alertGuard.reset();
      _smartRuleEngine.reset();
    }
    _tracker.reset();
    _detectionFilter.reset();
    _recentMotionByTrackId.clear();
    _lastIdleInferenceAt = null;
    _lastDetailScanAt = null;
    _detailTileIndex = 0;
    _seenTrackIds.clear();
    _lastTransitionSpeechAt.clear();
    _resetBikeApproach();
    _motion.reset();
    _motionActive = false;
    _cameraMotion = false;
    _motionScore = 0;
    _cameraIntegrity.reset();
    _fps = 0;
  }


  Map<String, Object?> _zonesDiagnosticContextImpl() => <String, Object?>{
        'quantidade': _monitoringZones.length,
        'ativas': activeMonitoringZones.length,
        'areas': _monitoringZones
            .map(
              (zone) => <String, Object?>{
                'id': zone.id,
                'nome': zone.name,
                'ativa': zone.enabled,
                'xMin': zone.zone.xMin.toStringAsFixed(3),
                'yMin': zone.zone.yMin.toStringAsFixed(3),
                'xMax': zone.zone.xMax.toStringAsFixed(3),
                'yMax': zone.zone.yMax.toStringAsFixed(3),
              },
            )
            .toList(growable: false),
      };

  Map<String, Object?> _smartRulesDiagnosticContextImpl() => <String, Object?>{
        'ativas': _smartAlertRules.enabled,
        'pessoaMs': _smartAlertRules.personMinimumPresence.inMilliseconds,
        'veiculoMs': _smartAlertRules.vehicleMinimumPresence.inMilliseconds,
        'animalMs': _smartAlertRules.animalMinimumPresence.inMilliseconds,
        'outrosMs': _smartAlertRules.otherMinimumPresence.inMilliseconds,
        'ignorarVeiculoParado': _smartAlertRules.ignoreStationaryVehicles,
      };

  Map<String, Object?> _diagnosticContextImpl() => <String, Object?>{
        'fonte': sourceConfig.type.name,
        'intervaloAnaliseMs': sourceConfig.analysisInterval.inMilliseconds,
        'intervaloEfetivoMs': effectiveAnalysisInterval.inMilliseconds,
        'modoBike': _bikeConfig.enabled,
        'perfilBike': _bikeConfig.powerProfile.name,
        'alertaAproximacaoBike': _bikeConfig.approachAlertsEnabled,
        'ttcAvisoBike': _bikeConfig.approachWarningTtcSeconds,
        'estadoAproximacaoBike': _bikeApproachStatus.level.name,
        if (_bikeApproachStatus.estimatedTtcSeconds != null)
          'ttcAtualBike': _bikeApproachStatus.estimatedTtcSeconds!.toStringAsFixed(2),
        'confiança': _settings.confidenceThreshold,
        'somenteMovimento': _settings.motionOnly,
        'movimento': _motionScore.toStringAsFixed(3),
        'detectorPronto': _detector.isReady,
        'suspenso': _suspended,
        'segundoPlano': _backgroundMonitoringEnabled,
        'transmissaoLan': _lanStream.running,
        'visualizadoresLan': _lanStream.connectedViewers,
        'agendamentoAtivo': _schedule.enabled,
        'dentroDoHorario': _scheduleActive,
        'clipes': _clipRecordingEnabled,
        'rastreamento': _trackingEnabled,
        'objetosMonitorados': _alertLabels.toList()..sort(),
        'regrasInteligentes': _smartRulesDiagnosticContextImpl(),
        'areasMonitoramento': _zonesDiagnosticContextImpl(),
        if (sourceConfig.type == VideoSourceType.rtsp)
          'rtspHost': Uri.tryParse(sourceConfig.rtspUrl ?? '')?.host ?? '',
      };

}
