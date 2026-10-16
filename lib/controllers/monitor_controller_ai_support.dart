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
