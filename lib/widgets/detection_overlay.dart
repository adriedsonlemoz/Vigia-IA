import 'package:flutter/material.dart';

import '../models/detection.dart';
import '../models/tracked_detection.dart';

class DetectionOverlay extends StatelessWidget {
  const DetectionOverlay({
    super.key,
    required this.detections,
    required this.previewAspectRatio,
    this.trackedDetections = const <TrackedDetection>[],
  });

  final List<Detection> detections;
  final List<TrackedDetection> trackedDetections;
  final double? previewAspectRatio;

  @override
  Widget build(BuildContext context) {
    if (detections.isEmpty) return const SizedBox.shrink();
    final ids = <Detection, int>{
      for (final tracked in trackedDetections) tracked.detection: tracked.trackId,
    };
    return IgnorePointer(
      child: CustomPaint(
        painter: _DetectionPainter(
          detections: detections,
          trackIds: ids,
          previewAspectRatio: previewAspectRatio,
          textDirection: Directionality.of(context),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _DetectionPainter extends CustomPainter {
  const _DetectionPainter({
    required this.detections,
    required this.trackIds,
    required this.previewAspectRatio,
    required this.textDirection,
  });

  final List<Detection> detections;
  final Map<Detection, int> trackIds;
  final double? previewAspectRatio;
  final TextDirection textDirection;

  Rect _previewRect(Size size) {
    final ratio = previewAspectRatio;
    if (ratio == null || ratio <= 0 || size.isEmpty) {
      return Offset.zero & size;
    }
    final containerRatio = size.width / size.height;
    if (containerRatio > ratio) {
      final width = size.height * ratio;
      return Rect.fromLTWH((size.width - width) / 2, 0, width, size.height);
    }
    final height = size.width / ratio;
    return Rect.fromLTWH(0, (size.height - height) / 2, size.width, height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final previewRect = _previewRect(size);
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Colors.lightGreenAccent;
    final labelBackground = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.black.withValues(alpha: 0.78);

    for (final detection in detections) {
      final box = detection.box;
      final rect = Rect.fromLTRB(
        previewRect.left +
            box.xMin.clamp(0.0, 1.0).toDouble() * previewRect.width,
        previewRect.top +
            box.yMin.clamp(0.0, 1.0).toDouble() * previewRect.height,
        previewRect.left +
            box.xMax.clamp(0.0, 1.0).toDouble() * previewRect.width,
        previewRect.top +
            box.yMax.clamp(0.0, 1.0).toDouble() * previewRect.height,
      );
      if (rect.width <= 1 || rect.height <= 1) continue;
      canvas.drawRect(rect, border);

      final trackId = trackIds[detection];
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${trackId == null ? '' : '#$trackId · '}'
              '${detection.displayLabel} '
              '${(detection.confidence * 100).round()}%',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: textDirection,
        maxLines: 1,
      )..layout(maxWidth: previewRect.width.clamp(40, 240).toDouble());

      const paddingX = 6.0;
      const paddingY = 4.0;
      final labelWidth = textPainter.width + paddingX * 2;
      final labelHeight = textPainter.height + paddingY * 2;
      final maxLeft = (previewRect.right - labelWidth)
          .clamp(previewRect.left, previewRect.right)
          .toDouble();
      final left = rect.left.clamp(previewRect.left, maxLeft).toDouble();
      final preferredTop = rect.top - labelHeight;
      final top = preferredTop >= previewRect.top ? preferredTop : rect.top;
      final labelRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, labelWidth, labelHeight),
        const Radius.circular(5),
      );
      canvas.drawRRect(labelRect, labelBackground);
      textPainter.paint(
        canvas,
        Offset(left + paddingX, top + paddingY),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DetectionPainter oldDelegate) =>
      oldDelegate.detections != detections ||
      oldDelegate.trackIds != trackIds ||
      oldDelegate.previewAspectRatio != previewAspectRatio ||
      oldDelegate.textDirection != textDirection;
}
