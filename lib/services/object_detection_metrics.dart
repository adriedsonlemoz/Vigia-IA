part of 'object_detection_service.dart';

class DetectorStageTimings {
  const DetectorStageTimings({
    required this.roundTripMs,
    required this.isolateTransferAndQueueMs,
    required this.workerMaterializeMs,
    required this.imageBuildMs,
    required this.resizeLetterboxMs,
    required this.tensorBuildMs,
    required this.liteRtMs,
    this.tensorTransferMs = 0,
    required this.detectorPostprocessMs,
    required this.workerTotalMs,
  });

  final double roundTripMs;
  final double isolateTransferAndQueueMs;
  final double workerMaterializeMs;
  final double imageBuildMs;
  final double resizeLetterboxMs;
  final double tensorBuildMs;
  final double liteRtMs;
  final double tensorTransferMs;
  final double detectorPostprocessMs;
  final double workerTotalMs;

  Map<String, Object?> toJson() => <String, Object?>{
        'roundTripMs': roundTripMs,
        'isolateTransferAndQueueMs': isolateTransferAndQueueMs,
        'workerMaterializeMs': workerMaterializeMs,
        'imageBuildMs': imageBuildMs,
        'resizeLetterboxMs': resizeLetterboxMs,
        'tensorBuildMs': tensorBuildMs,
        'liteRtMs': liteRtMs,
        'tensorTransferMs': tensorTransferMs,
        'detectorPostprocessMs': detectorPostprocessMs,
        'workerTotalMs': workerTotalMs,
      };
}

class DetectionRunResult {
  const DetectionRunResult({
    required this.detections,
    required this.timings,
  });

  final List<Detection> detections;
  final DetectorStageTimings timings;
}

class _PendingDetection {
  _PendingDetection()
      : completer = Completer<DetectionRunResult>(),
        watch = (Stopwatch()..start());

  final Completer<DetectionRunResult> completer;
  final Stopwatch watch;
}

