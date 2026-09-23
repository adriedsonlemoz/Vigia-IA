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

  void _confirm() {
    if (!_ready) return;
    Navigator.pop(context, _controller.camera.visibleBounds);
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
      body: Stack(
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
            child: SafeArea(
              minimum: const EdgeInsets.all(14),
              child: Column(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.93),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Text(
                        'Mova e ajuste o zoom. Toda a área visível será preparada para o download offline.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    height: 3,
                    width: 72,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
