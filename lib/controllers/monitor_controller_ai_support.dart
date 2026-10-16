part of 'monitor_controller.dart';

void _clearMonitorControllerAiState(MonitorController controller) {
  controller._detections = const <Detection>[];
  controller._trackedDetections = const <TrackedDetection>[];
  controller._recentMotionByTrackId.clear();
  controller._lastIdleInferenceAt = null;
  controller._lastDetailScanAt = null;
  controller._detailTileIndex = 0;
  controller._seenTrackIds.clear();
  controller._lastTransitionSpeechAt.clear();
  controller._motionScore = 0;
  controller._cameraMotion = false;
  controller._motionActive = false;
  controller._processing = false;
  controller._fps = 0;
  controller._lastAnalyzedFpsSample = null;
  controller._lastInferenceMs = null;
  controller._lastAnalysisWidth = null;
  controller._lastAnalysisHeight = null;
  controller._lastPreprocessMs = null;
  controller._lastPrimaryInferenceMs = null;
  controller._lastIsolateTransferAndQueueMs = null;
  controller._lastWorkerMaterializeMs = null;
  controller._lastDetectorImageBuildMs = null;
  controller._lastResizeLetterboxMs = null;
  controller._lastTensorBuildMs = null;
  controller._lastLiteRtMs = null;
  controller._lastTensorTransferMs = null;
  controller._lastDetectorPostprocessMs = null;
  controller._lastAuxiliaryInferenceMs = 0;
  controller._lastPostprocessMs = null;
  controller._lastTotalProcessingMs = null;
  controller._lastEndToEndMs = null;
  controller._lastDetectorRuns = 0;
  controller._lastAuxiliaryInferenceRuns = 0;
  controller._detailScansSkippedByBudget = 0;
  final processingDone = controller._processingDone;
  if (processingDone != null && !processingDone.isCompleted) {
    processingDone.complete();
  }
  controller._processingDone = null;
  controller._tracker.reset();
  controller._detectionFilter.reset();
  controller._resetBikeApproach();
}

extension MonitorControllerAiSupport on MonitorController {
  String get activeDetectorModel => _detector.activeModel;
  DetectorModelPreference get detectorModelPreference => _settings.detectorModel;
  String get activeDetectorModel => _detector.activeModel;
  void setAiEnabled(bool enabled) {
    _aiEnabled = enabled;
    _settings = _settings.copyWith(aiEnabled: enabled);
    _health.aiReady = false;
    if (!enabled) {
      _clearMonitorControllerAiState(this);
    }
    _notify();
    unawaited(_persistRuntime());
  }


  Future<void> changeDetectorModel(DetectorModelPreference preference) async {
    if (_disposed || _initializing || !_baseReady ||
        preference == _settings.detectorModel) {
      return;
    }
    // A câmera continua transmitindo e exibindo a imagem enquanto a IA troca.
    _baseReady = false;
    _health.aiReady = false;
    _notify();
    await _waitForProcessing();
    final old = _detector;
    try {
      await old.dispose();
      final replacement = ObjectDetectionService(preference: preference);
      _detector = replacement;
      await replacement.initialize();
      _settings = _settings.copyWith(detectorModel: preference);
      _baseReady = true;
      _health.aiReady = replacement.isReady;
      await _logs.record(
        level: ErrorLogLevel.info,
        source: 'Detector',
        message: 'Seleção de modelo de IA aplicada.',
        context: <String, Object?>{
          'preferência': preference.label,
          'modeloEfetivo': replacement.activeModel,
          'fallback': preference != DetectorModelPreference.automatic &&
              replacement.activeModel != preference.label,
        },
      );
      unawaited(_persistRuntime());
    } catch (error, stackTrace) {
      // Até a recuperação não pode desligar a recepção da câmera.
      final recovery = ObjectDetectionService();
      _detector = recovery;
      try {
        await recovery.initialize();
        _baseReady = true;
        _health.aiReady = true;
      } catch (_) {
        _baseReady = false;
        _error = 'Não foi possível recuperar o detector de IA.';
      }
      unawaited(_logs.recordException(
        source: 'Seleção do detector',
        error: error,
        stackTrace: stackTrace,
        message: 'Troca de modelo falhou; tentativa de recuperação automática.',
      ));
      rethrow;
    } finally {
      _notify();
    }
  }

  void setTrackingEnabled(bool enabled) {
    _trackingEnabled = enabled;
    _settings = _settings.copyWith(trackingEnabled: enabled);
    _tracker.reset();
    _detectionFilter.reset();
    _recentMotionByTrackId.clear();
    _lastIdleInferenceAt = null;
    _lastDetailScanAt = null;
    _detailTileIndex = 0;
    _seenTrackIds.clear();
    _lastTransitionSpeechAt.clear();
    _trackedDetections = const <TrackedDetection>[];
    _notify();
    unawaited(_persistRuntime());
  }
}
