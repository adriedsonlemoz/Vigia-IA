import 'dart:typed_data';

import '../models/detection.dart';
import '../models/monitoring_zone.dart';
import '../models/rgb_frame.dart';

class MonitoringZoneService {
  const MonitoringZoneService._();

  static RgbFrame crop(RgbFrame frame, MonitoringZone zone) {
    final normalized = zone.normalized();
    if (normalized.isFullFrame) return frame;

    final startX = (normalized.xMin * frame.width)
        .floor()
        .clamp(0, frame.width - 1)
        .toInt();
    final startY = (normalized.yMin * frame.height)
        .floor()
        .clamp(0, frame.height - 1)
        .toInt();
    final endX = (normalized.xMax * frame.width)
        .ceil()
        .clamp(startX + 1, frame.width)
        .toInt();
    final endY = (normalized.yMax * frame.height)
        .ceil()
        .clamp(startY + 1, frame.height)
        .toInt();

    final cropWidth = endX - startX;
    final cropHeight = endY - startY;
    final bytes = Uint8List(cropWidth * cropHeight * 3);

    for (var y = 0; y < cropHeight; y++) {
      final sourceOffset = ((startY + y) * frame.width + startX) * 3;
      final destinationOffset = y * cropWidth * 3;
      bytes.setRange(
        destinationOffset,
        destinationOffset + cropWidth * 3,
        frame.rgbBytes,
        sourceOffset,
      );
    }

    return RgbFrame(
      width: cropWidth,
      height: cropHeight,
      rgbBytes: bytes,
      capturedAt: frame.capturedAt,
    );
  }

  static Detection remapDetection(
    Detection detection,
    MonitoringZone zone,
  ) {
    final normalized = zone.normalized();
    if (normalized.isFullFrame) return detection;

    final box = detection.box;
    return Detection(
      label: detection.label,
      displayLabel: detection.displayLabel,
      confidence: detection.confidence,
      box: NormalizedBox(
        xMin: normalized.xMin + box.xMin * normalized.width,
        yMin: normalized.yMin + box.yMin * normalized.height,
        xMax: normalized.xMin + box.xMax * normalized.width,
        yMax: normalized.yMin + box.yMax * normalized.height,
      ),
    );
  }

  static MonitoringZone boundingZone(Iterable<MonitoringZone> zones) {
    final list = zones.map((zone) => zone.normalized()).toList(growable: false);
    if (list.isEmpty) return const MonitoringZone.fullFrame();
    var xMin = 1.0;
    var yMin = 1.0;
    var xMax = 0.0;
    var yMax = 0.0;
    for (final zone in list) {
      if (zone.xMin < xMin) xMin = zone.xMin;
      if (zone.yMin < yMin) yMin = zone.yMin;
      if (zone.xMax > xMax) xMax = zone.xMax;
      if (zone.yMax > yMax) yMax = zone.yMax;
    }
    return MonitoringZone(
      xMin: xMin,
      yMin: yMin,
      xMax: xMax,
      yMax: yMax,
    ).normalized(minimumSize: 0);
  }

  static bool detectionInsideZone(Detection detection, MonitoringZone zone) {
    final centerX = (detection.box.xMin + detection.box.xMax) / 2;
    final centerY = (detection.box.yMin + detection.box.yMax) / 2;
    return zone.contains(centerX, centerY);
  }

  static List<Detection> filterToZones(
    Iterable<Detection> detections,
    Iterable<MonitoringZone> zones,
  ) {
    final active = zones.toList(growable: false);
    if (active.isEmpty) return detections.toList(growable: false);
    return detections
        .where((detection) =>
            active.any((zone) => detectionInsideZone(detection, zone)))
        .toList(growable: false);
  }

  static List<MonitoringZoneProfile> zonesForDetection(
    Detection detection,
    Iterable<MonitoringZoneProfile> profiles,
  ) =>
      profiles
          .where((profile) =>
              profile.enabled && detectionInsideZone(detection, profile.zone))
          .toList(growable: false);
}
