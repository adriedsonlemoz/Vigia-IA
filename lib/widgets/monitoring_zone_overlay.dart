import 'package:flutter/material.dart';

import '../models/monitoring_zone.dart';

class MonitoringZoneOverlay extends StatefulWidget {
  const MonitoringZoneOverlay({
    super.key,
    required this.zones,
    required this.editingZoneId,
    required this.previewAspectRatio,
    required this.onChanged,
    this.fillPreview = false,
  });

  final List<MonitoringZoneProfile> zones;
  final String? editingZoneId;
  final double? previewAspectRatio;
  final bool fillPreview;
  final void Function(String id, MonitoringZone zone) onChanged;

  @override
  State<MonitoringZoneOverlay> createState() => _MonitoringZoneOverlayState();
}

class _MonitoringZoneOverlayState extends State<MonitoringZoneOverlay> {
  Offset? _dragStart;
  MonitoringZone? _draft;

  @override
  void didUpdateWidget(covariant MonitoringZoneOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editingZoneId != oldWidget.editingZoneId) {
      _dragStart = null;
      _draft = null;
    }
  }

  Rect _previewRect(Size size) {
    final ratio = widget.previewAspectRatio;
    if (ratio == null || ratio <= 0 || size.isEmpty) return Offset.zero & size;
    final containerRatio = size.width / size.height;
    if (widget.fillPreview) {
      if (containerRatio > ratio) {
        final height = size.width / ratio;
        return Rect.fromLTWH(0, (size.height - height) / 2, size.width, height);
      }
      final width = size.height * ratio;
      return Rect.fromLTWH((size.width - width) / 2, 0, width, size.height);
    }
    if (containerRatio > ratio) {
      final width = size.height * ratio;
      return Rect.fromLTWH((size.width - width) / 2, 0, width, size.height);
    }
    final height = size.width / ratio;
    return Rect.fromLTWH(0, (size.height - height) / 2, size.width, height);
  }

  Offset _clampToRect(Offset point, Rect rect) => Offset(
        point.dx.clamp(rect.left, rect.right).toDouble(),
        point.dy.clamp(rect.top, rect.bottom).toDouble(),
      );

  MonitoringZone _zoneFromPoints(Offset a, Offset b, Rect rect) {
    final first = _clampToRect(a, rect);
    final second = _clampToRect(b, rect);
    return MonitoringZone(
      xMin: ((first.dx - rect.left) / rect.width).clamp(0.0, 1.0).toDouble(),
      yMin: ((first.dy - rect.top) / rect.height).clamp(0.0, 1.0).toDouble(),
      xMax: ((second.dx - rect.left) / rect.width).clamp(0.0, 1.0).toDouble(),
      yMax: ((second.dy - rect.top) / rect.height).clamp(0.0, 1.0).toDouble(),
    ).normalized();
  }

  Rect _zoneRect(MonitoringZone zone, Rect previewRect) {
    final normalized = zone.normalized();
    return Rect.fromLTRB(
      previewRect.left + normalized.xMin * previewRect.width,
      previewRect.top + normalized.yMin * previewRect.height,
      previewRect.left + normalized.xMax * previewRect.width,
      previewRect.top + normalized.yMax * previewRect.height,
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.zones
        .where((zone) => zone.enabled || zone.id == widget.editingZoneId)
        .toList();
    if (active.isEmpty && widget.editingZoneId == null) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final previewRect = _previewRect(size);
        final editing = widget.editingZoneId;
        final zones = <_PaintedZone>[];
        for (final profile in active) {
          final useDraft = profile.id == editing && _draft != null;
          zones.add(
            _PaintedZone(
              id: profile.id,
              name: profile.name,
              rect: _zoneRect(useDraft ? _draft! : profile.zone, previewRect),
              selected: profile.id == editing,
            ),
          );
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: editing == null
              ? null
              : (details) {
                  if (!previewRect.contains(details.localPosition)) return;
                  setState(() {
                    _dragStart = details.localPosition;
                    _draft = _zoneFromPoints(
                      details.localPosition,
                      details.localPosition,
                      previewRect,
                    );
                  });
                },
          onPanUpdate: editing == null
              ? null
              : (details) {
                  final start = _dragStart;
                  if (start == null) return;
                  setState(() {
                    _draft = _zoneFromPoints(start, details.localPosition, previewRect);
                  });
                },
          onPanEnd: editing == null
              ? null
              : (_) {
                  final draft = _draft;
                  if (draft != null) widget.onChanged(editing, draft);
                  setState(() {
                    _dragStart = null;
                    _draft = null;
                  });
                },
          child: CustomPaint(
            painter: _MonitoringZonesPainter(
              previewRect: previewRect,
              zones: zones,
              editing: editing != null,
              textDirection: Directionality.of(context),
            ),
            child: editing == null
                ? null
                : Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      margin: const EdgeInsets.only(top: 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Arraste sobre o vídeo para definir esta área',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _PaintedZone {
  const _PaintedZone({
    required this.id,
    required this.name,
    required this.rect,
    required this.selected,
  });

  final String id;
  final String name;
  final Rect rect;
  final bool selected;
}

class _MonitoringZonesPainter extends CustomPainter {
  const _MonitoringZonesPainter({
    required this.previewRect,
    required this.zones,
    required this.editing,
    required this.textDirection,
  });

  final Rect previewRect;
  final List<_PaintedZone> zones;
  final bool editing;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    if (zones.isNotEmpty) {
      final overlay = Paint()..color = Colors.black.withValues(alpha: 0.38);
      var mask = Path()..addRect(previewRect);
      for (final zone in zones) {
        mask = Path.combine(
          PathOperation.difference,
          mask,
          Path()..addRect(zone.rect),
        );
      }
      canvas.drawPath(mask, overlay);
    }

    for (final zone in zones) {
      final border = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = zone.selected ? 3 : 2
        ..color = zone.selected ? const Color(0xFF35D0BA) : const Color(0xFF63B3FF);
      canvas.drawRect(zone.rect, border);

      final painter = TextPainter(
        text: TextSpan(
          text: zone.name,
          style: TextStyle(
            color: zone.selected ? const Color(0xFF35D0BA) : const Color(0xFF63B3FF),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: textDirection,
      )..layout(maxWidth: 160);
      final top = (zone.rect.top - painter.height - 3)
          .clamp(previewRect.top, previewRect.bottom)
          .toDouble();
      painter.paint(canvas, Offset(zone.rect.left + 2, top));
    }
  }

  @override
  bool shouldRepaint(covariant _MonitoringZonesPainter oldDelegate) => true;
}
