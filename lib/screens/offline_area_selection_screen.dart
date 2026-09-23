import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class OfflineAreaSelectionScreen extends StatefulWidget {
  const OfflineAreaSelectionScreen({
    super.key,
    required this.initialCenter,
    this.initialZoom = 13,
  });

  final LatLng initialCenter;
  final double initialZoom;

  @override
  State<OfflineAreaSelectionScreen> createState() =>
      _OfflineAreaSelectionScreenState();
}

class _OfflineAreaSelectionScreenState
    extends State<OfflineAreaSelectionScreen> {
  final MapController _controller = MapController();
  bool _ready = false;

  // Retângulo normalizado em relação à área útil do mapa.
  Rect _selection = const Rect.fromLTRB(0.12, 0.18, 0.88, 0.82);

  void _confirm() {
    if (!_ready) return;
    Navigator.pop(context, _selectedBounds());
  }

  LatLngBounds _selectedBounds() {
    final visible = _controller.camera.visibleBounds;
    final west = _lerp(visible.west, visible.east, _selection.left);
    final east = _lerp(visible.west, visible.east, _selection.right);

    // Interpolar no espaço WebMercator evita distorção excessiva em latitude.
    final northY = _mercatorY(visible.north);
    final southY = _mercatorY(visible.south);
    final topY = _lerp(northY, southY, _selection.top);
    final bottomY = _lerp(northY, southY, _selection.bottom);
    final north = _inverseMercatorY(topY);
    final south = _inverseMercatorY(bottomY);

    return LatLngBounds(LatLng(south, west), LatLng(north, east));
  }

  double _lerp(double a, double b, double t) => a + ((b - a) * t);

  double _mercatorY(double latitude) {
    final safe = latitude.clamp(-85.05112878, 85.05112878).toDouble();
    final radians = safe * math.pi / 180;
    return math.log(math.tan((math.pi / 4) + (radians / 2)));
  }

  double _inverseMercatorY(double value) =>
      (2 * math.atan(math.exp(value)) - (math.pi / 2)) * 180 / math.pi;

  void _moveSelection(DragUpdateDetails details, Size size) {
    final dx = details.delta.dx / size.width;
    final dy = details.delta.dy / size.height;
    final width = _selection.width;
    final height = _selection.height;
    final left = (_selection.left + dx).clamp(0.02, 0.98 - width).toDouble();
    final top = (_selection.top + dy).clamp(0.02, 0.98 - height).toDouble();
    setState(() {
      _selection = Rect.fromLTWH(left, top, width, height);
    });
  }

  void _resizeSelection(
    DragUpdateDetails details,
    Size size, {
    required bool topLeft,
  }) {
    const minWidth = 0.16;
    const minHeight = 0.16;
    final dx = details.delta.dx / size.width;
    final dy = details.delta.dy / size.height;

    if (topLeft) {
      final left = (_selection.left + dx)
          .clamp(0.02, _selection.right - minWidth)
          .toDouble();
      final top = (_selection.top + dy)
          .clamp(0.02, _selection.bottom - minHeight)
          .toDouble();
      setState(() {
        _selection = Rect.fromLTRB(left, top, _selection.right, _selection.bottom);
      });
    } else {
      final right = (_selection.right + dx)
          .clamp(_selection.left + minWidth, 0.98)
          .toDouble();
      final bottom = (_selection.bottom + dy)
          .clamp(_selection.top + minHeight, 0.98)
          .toDouble();
      setState(() {
        _selection = Rect.fromLTRB(_selection.left, _selection.top, right, bottom);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Selecionar região'),
        actions: [
          TextButton.icon(
            onPressed: _ready ? _confirm : null,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Usar área'),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return Stack(
            children: [
              FlutterMap(
                mapController: _controller,
                options: MapOptions(
                  initialCenter: widget.initialCenter,
                  initialZoom: widget.initialZoom,
                  minZoom: 3,
                  maxZoom: 18,
                  onMapReady: () => setState(() => _ready = true),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.vigiaia.app',
                    maxNativeZoom: 19,
                  ),
                  RichAttributionWidget(
                    attributions: const [
                      TextSourceAttribution('© OpenStreetMap contributors'),
                    ],
                  ),
                ],
              ),
              IgnorePointer(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.10),
                ),
              ),
              Positioned(
                left: _selection.left * size.width,
                top: _selection.top * size.height,
                width: _selection.width * size.width,
                height: _selection.height * size.height,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanUpdate: (details) => _moveSelection(details, size),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.08),
                      border: Border.all(color: scheme.primary, width: 3),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Center(
                          child: Material(
                            color: scheme.surface.withValues(alpha: 0.90),
                            borderRadius: BorderRadius.circular(14),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.open_with_rounded, size: 16),
                                  SizedBox(width: 5),
                                  Text(
                                    'Arraste a área',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: -12,
                          top: -12,
                          child: _ResizeHandle(
                            onPanUpdate: (details) => _resizeSelection(
                              details,
                              size,
                              topLeft: true,
                            ),
                          ),
                        ),
                        Positioned(
                          right: -12,
                          bottom: -12,
                          child: _ResizeHandle(
                            onPanUpdate: (details) => _resizeSelection(
                              details,
                              size,
                              topLeft: false,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                minimum: const EdgeInsets.all(12),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surface.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text(
                          'Mova o mapa fora do quadro. Arraste o quadro para reposicionar e use os cantos para redimensionar a região offline.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({required this.onPanUpdate});

  final GestureDragUpdateCallback onPanUpdate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: onPanUpdate,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: scheme.primary,
          shape: BoxShape.circle,
          border: Border.all(color: scheme.surface, width: 3),
        ),
        child: Icon(
          Icons.drag_handle_rounded,
          size: 16,
          color: scheme.onPrimary,
        ),
      ),
    );
  }
}
