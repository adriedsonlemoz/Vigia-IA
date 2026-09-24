import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_mbtiles/flutter_map_mbtiles.dart';
import 'package:latlong2/latlong.dart';

import '../models/map_route_point.dart';
import '../models/offline_map_package.dart';
import '../services/location_tracking_service.dart';
import '../services/map_route_service.dart';
import '../services/native_platform_service.dart';
import '../services/offline_map_service.dart';
import '../widgets/offline_map_manager_sheet.dart';

class MapMonitoringScreen extends StatefulWidget {
  const MapMonitoringScreen({
    super.key,
    this.cameraPreviewBuilder,
    this.cameraAspectRatio,
    this.cameraListenable,
    this.cameraAspectRatioProvider,
    this.secondaryCameraPreviewBuilder,
    this.secondaryCameraListenable,
    this.secondaryCameraAspectRatioProvider,
  });

  final WidgetBuilder? cameraPreviewBuilder;
  final double? cameraAspectRatio;
  final Listenable? cameraListenable;
  final double? Function()? cameraAspectRatioProvider;
  final WidgetBuilder? secondaryCameraPreviewBuilder;
  final Listenable? secondaryCameraListenable;
  final double? Function()? secondaryCameraAspectRatioProvider;

  @override
  State<MapMonitoringScreen> createState() => _MapMonitoringScreenState();
}

class _MapMonitoringScreenState extends State<MapMonitoringScreen> {
  final MapController _mapController = MapController();
  final LocationTrackingService _location = LocationTrackingService.instance;
  final OfflineMapService _offlineMaps = OfflineMapService.instance;
  final MapRouteService _routeState = MapRouteService.instance;
  final NativePlatformService _native = NativePlatformService.instance;

  MbTilesTileProvider? _offlineTileProvider;
  String? _offlineTilePackageId;
  String? _offlineTileError;
  int _offlineMinNativeZoom = 0;
  int _offlineMaxNativeZoom = 19;
  Offset? _primaryCameraOffset;
  Offset? _secondaryCameraOffset;
  bool _camerasVisible = true;

  bool _followPosition = true;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _offlineMaps.addListener(_onOfflineMapsChanged);
    _routeState.addListener(_onRouteStateChanged);
    unawaited(_initializeOfflineMaps());
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _offlineMaps.removeListener(_onOfflineMapsChanged);
    _routeState.removeListener(_onRouteStateChanged);
    _offlineTileProvider?.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initializeOfflineMaps() async {
    await _offlineMaps.initialize();
    if (!mounted) return;
    _syncOfflineTileProvider();
  }

  void _onOfflineMapsChanged() {
    if (!mounted) return;
    _syncOfflineTileProvider();
  }

  void _syncOfflineTileProvider() {
    final active = _offlineMaps.activePackage;
    if (_offlineTilePackageId == active?.id) {
      setState(() {});
      return;
    }
    _offlineTileProvider?.dispose();
    _offlineTileProvider = null;
    _offlineTilePackageId = active?.id;
    _offlineTileError = null;
    _offlineMinNativeZoom = 0;
    _offlineMaxNativeZoom = 19;
    if (active != null) {
      try {
        final provider = MbTilesTileProvider.fromPath(path: active.path);
        final metadata = provider.mbtiles.getMetadata();
        final minZoom = (metadata.minZoom ?? 0).floor().clamp(0, 22);
        final maxZoom = (metadata.maxZoom ?? 19).ceil().clamp(minZoom, 22);
        _offlineMinNativeZoom = minZoom.toInt();
        _offlineMaxNativeZoom = maxZoom.toInt();
        _offlineTileProvider = provider;
      } catch (error) {
        _offlineTileError = '$error';
      }
    }
    setState(() {});
  }

  Future<void> _initialize() async {
    await _routeState.initialize(requestPermission: true);
    if (!mounted) return;
    setState(() {});
  }

  void _onRouteStateChanged() {
    if (!mounted) return;
    setState(() {});
    final current = _routeState.current;
    if (_followPosition && current != null) _centerOn(current, zoom: 16);
  }

  void _centerOn(MapRoutePoint point, {double zoom = 16}) {
    if (!_mapReady) return;
    _mapController.move(LatLng(point.latitude, point.longitude), zoom);
  }

  Future<void> _openOfflineMaps() async {
    LatLngBounds? visibleBounds;
    if (_mapReady) {
      try {
        visibleBounds = _mapController.camera.visibleBounds;
      } catch (_) {}
    }
    final current = _routeState.current;
    await showOfflineMapManager(
      context,
      planning: OfflineMapPlanningContext(
        currentPosition: current == null
            ? null
            : LatLng(current.latitude, current.longitude),
        visibleBounds: visibleBounds,
        route: _routeState.route
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList(growable: false),
      ),
    );
  }

  void _startRoute() {
    setState(() => _followPosition = true);
    unawaited(_routeState.startRoute());
    final current = _routeState.current;
    if (current != null) _centerOn(current);
  }

  void _finishRoute() {
    unawaited(_routeState.finishRoute());
  }

  void _togglePauseRoute() {
    if (!_routeState.tracking) return;
    if (_routeState.paused) {
      unawaited(_routeState.resumeRoute());
    } else {
      unawaited(_routeState.pauseRoute());
    }
  }

  Future<void> _exportGpx() async {
    if (_routeState.route.isEmpty) return;
    try {
      final gpx = _routeState.buildGpx();
      final now = DateTime.now();
      String two(int value) => value.toString().padLeft(2, '0');
      final name = 'VigiaIA-rota-${now.year}${two(now.month)}${two(now.day)}-'
          '${two(now.hour)}${two(now.minute)}.gpx';
      final saved = await _native.saveBytesWithPicker(
        fileName: name,
        mimeType: 'application/gpx+xml',
        bytes: Uint8List.fromList(utf8.encode(gpx)),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved == null
                ? 'Exportação cancelada ou não concluída.'
                : 'Rota GPX exportada.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível exportar a rota: $error')),
      );
    }
  }

  String _formatDistance() {
    final distanceMeters = _routeState.distanceMeters;
    if (distanceMeters < 1000) return '${distanceMeters.toStringAsFixed(0)} m';
    return '${(distanceMeters / 1000).toStringAsFixed(2)} km';
  }

  String _formatDuration(Duration value) {
    final hours = value.inHours.toString().padLeft(2, '0');
    final minutes = (value.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  void _handleRouteMenu(String value) {
    if (value == 'pause') {
      _togglePauseRoute();
    } else if (value == 'export') {
      unawaited(_exportGpx());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_routeState.initialized ||
        (_routeState.loading && _routeState.availability == null)) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_routeState.availability != LocationTrackingAvailability.ready) {
      return _buildUnavailable(context);
    }

    final scheme = Theme.of(context).colorScheme;
    final current = _routeState.current;
    final center = current == null
        ? const LatLng(-14.2350, -51.9253)
        : LatLng(current.latitude, current.longitude);
    final routeSegments = _routeState.routeSegments
        .map(
          (segment) => segment
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList(growable: false),
        )
        .where((segment) => segment.length >= 2)
        .toList(growable: false);
    final activeOffline = _offlineMaps.activePackage;
    final outsideOfflineArea = activeOffline != null &&
        current != null &&
        !activeOffline.contains(
          latitude: current.latitude,
          longitude: current.longitude,
        );

    final offlineProvider = _offlineTileProvider;
    final mode = _offlineMaps.mode;
    final useOnline = mode != OfflineMapMode.offline;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mapa do monitoramento',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            Text('GPS, trajeto e mapa offline', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Mapas offline',
            onPressed: () => unawaited(_openOfflineMaps()),
            icon: Icon(
              offlineProvider == null
                  ? Icons.download_for_offline_outlined
                  : Icons.offline_pin_rounded,
            ),
          ),
          if (widget.cameraPreviewBuilder != null ||
              widget.secondaryCameraPreviewBuilder != null)
            IconButton(
              tooltip: _camerasVisible ? 'Ocultar câmeras' : 'Mostrar câmeras',
              onPressed: () => setState(() => _camerasVisible = !_camerasVisible),
              icon: Icon(
                _camerasVisible
                    ? Icons.videocam_rounded
                    : Icons.videocam_off_rounded,
              ),
            ),
          if (_routeState.tracking || _routeState.route.length >= 2)
            PopupMenuButton<String>(
              tooltip: 'Ações da rota',
              onSelected: _handleRouteMenu,
              itemBuilder: (context) => [
                if (_routeState.tracking)
                  PopupMenuItem<String>(
                    value: 'pause',
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        _routeState.paused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                      ),
                      title: Text(
                        _routeState.paused ? 'Continuar rota' : 'Pausar rota',
                      ),
                    ),
                  ),
                if (_routeState.route.length >= 2)
                  const PopupMenuItem<String>(
                    value: 'export',
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.file_upload_outlined),
                      title: Text('Exportar GPX'),
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: current == null ? 13 : 16,
                  minZoom: 3,
                  maxZoom: 19,
                  onMapReady: () {
                    _mapReady = true;
                    final point = _routeState.current;
                    if (point != null) _centerOn(point);
                  },
                  onPositionChanged: (_, hasGesture) {
                    if (hasGesture && _followPosition && mounted) {
                      setState(() => _followPosition = false);
                    }
                  },
                ),
                children: [
                  if (offlineProvider != null)
                    TileLayer(
                      key: ValueKey<String>(
                        'offline-${_offlineTilePackageId ?? 'active'}',
                      ),
                      tileProvider: offlineProvider,
                      tileDisplay: TileDisplay.instantaneous(
                        opacity: mode == OfflineMapMode.online ? 0 : 1,
                      ),
                      minNativeZoom: _offlineMinNativeZoom,
                      maxNativeZoom: _offlineMaxNativeZoom,
                    ),
                  if (useOnline)
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.vigiaia.app',
                      maxNativeZoom: 19,
                    ),
                  if (routeSegments.isNotEmpty)
                    PolylineLayer(
                      polylines: routeSegments
                          .map(
                            (segment) => Polyline(
                              points: segment,
                              strokeWidth: 5,
                              color: scheme.primary,
                            ),
                          )
                          .toList(growable: false),
                    ),
                  MarkerLayer(
                    markers: [
                      if (_routeState.start != null)
                        _pinMarker(
                          _routeState.start!,
                          Icons.flag_rounded,
                          Colors.green,
                          'Início',
                        ),
                      if (_routeState.end != null)
                        _pinMarker(
                          _routeState.end!,
                          Icons.sports_score_rounded,
                          scheme.error,
                          'Fim',
                        ),
                      if (current != null)
                        Marker(
                          point: LatLng(current.latitude, current.longitude),
                          width: 52,
                          height: 52,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: scheme.primary.withValues(alpha: 0.20),
                            ),
                            alignment: Alignment.center,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: scheme.primary,
                                border: Border.all(color: Colors.white, width: 3),
                              ),
                              child: current.headingDegrees == null
                                  ? const Icon(
                                      Icons.circle,
                                      size: 10,
                                      color: Colors.white,
                                    )
                                  : Transform.rotate(
                                      angle: current.headingDegrees! * math.pi / 180,
                                      child: const Icon(
                                        Icons.navigation_rounded,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  Positioned(
                    right: 8,
                    bottom: 72,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surface.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        child: Text(
                          mode != OfflineMapMode.online &&
                                  activeOffline?.providerId ==
                                      'stadia-alidade-smooth'
                              ? '© Stadia Maps © OpenMapTiles © OpenStreetMap contributors'
                              : mode == OfflineMapMode.offline
                                  ? 'Mapa offline · confira a licença do pacote'
                                  : '© OpenStreetMap contributors',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 12,
                left: 12,
                child: _MapSourceChip(
                  mode: mode,
                  activePackage: _offlineMaps.activePackage,
                  error: _offlineTileError,
                  onTap: () => unawaited(_openOfflineMaps()),
                ),
              ),
              if (outsideOfflineArea && mode != OfflineMapMode.online)
                Positioned(
                  top: 54,
                  left: 12,
                  child: _OfflineAreaWarning(
                    onTap: () => unawaited(_openOfflineMaps()),
                  ),
                ),
              Positioned(
                top: 12,
                right: 12,
                child: _GpsChip(point: current),
              ),
              Positioned(
                top: 52,
                left: 8,
                right: 8,
                child: _MapTelemetryStrip(
                  paused: _routeState.paused,
                  speedKmh: current?.speedKilometersPerHour ?? 0,
                  distance: _formatDistance(),
                  elapsed: _formatDuration(_routeState.elapsed),
                  altitudeMeters: current?.altitudeMeters,
                  headingDegrees: current?.headingDegrees,
                  following: _followPosition,
                  onToggleFollow: current == null
                      ? null
                      : () {
                          final next = !_followPosition;
                          setState(() => _followPosition = next);
                          if (next) _centerOn(current);
                        },
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _RouteButtonBar(
                  tracking: _routeState.tracking,
                  onToggleTracking: current == null
                      ? null
                      : _routeState.tracking
                          ? _finishRoute
                          : _startRoute,
                ),
              ),
              if (_camerasVisible && widget.cameraPreviewBuilder != null)
                _buildCameraPip(
                  context,
                  constraints,
                  previewBuilder: widget.cameraPreviewBuilder!,
                  listenable: widget.cameraListenable,
                  aspectRatioProvider: widget.cameraAspectRatioProvider,
                  fallbackAspectRatio: widget.cameraAspectRatio,
                  secondary: false,
                ),
              if (_camerasVisible &&
                  widget.secondaryCameraPreviewBuilder != null)
                _buildCameraPip(
                  context,
                  constraints,
                  previewBuilder: widget.secondaryCameraPreviewBuilder!,
                  listenable: widget.secondaryCameraListenable,
                  aspectRatioProvider: widget.secondaryCameraAspectRatioProvider,
                  fallbackAspectRatio: 16 / 9,
                  secondary: true,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCameraPip(
    BuildContext context,
    BoxConstraints constraints, {
    required WidgetBuilder previewBuilder,
    required Listenable? listenable,
    required double? Function()? aspectRatioProvider,
    required double? fallbackAspectRatio,
    required bool secondary,
  }) {
    Widget buildPip(BuildContext context) {
      final scheme = Theme.of(context).colorScheme;
      final requestedRatio = aspectRatioProvider?.call() ?? fallbackAspectRatio ?? (16 / 9);
      final aspectRatio = requestedRatio.clamp(0.50, 2.20).toDouble();
      late final double width;
      late final double height;
      if (aspectRatio >= 1) {
        width = (constraints.maxWidth * 0.29).clamp(126.0, 190.0).toDouble();
        height = (width / aspectRatio).clamp(78.0, 132.0).toDouble();
      } else {
        height = (constraints.maxHeight * 0.22).clamp(118.0, 188.0).toDouble();
        width = (height * aspectRatio).clamp(82.0, 128.0).toDouble();
      }

      final defaultTop = secondary ? 304.0 : 104.0;
      final fallback = Offset(
        constraints.maxWidth - width - 12,
        defaultTop,
      );
      final raw = secondary
          ? (_secondaryCameraOffset ?? fallback)
          : (_primaryCameraOffset ?? fallback);
      final maxX = (constraints.maxWidth - width - 8).clamp(8.0, double.infinity);
      // Reserva somente a barra essencial da rota; no restante do mapa o PiP é livre.
      final maxY = (constraints.maxHeight - height - 74).clamp(8.0, double.infinity);
      final position = Offset(
        raw.dx.clamp(8.0, maxX).toDouble(),
        raw.dy.clamp(8.0, maxY).toDouble(),
      );

      return Positioned(
        left: position.dx,
        top: position.dy,
        width: width,
        height: height,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (details) {
            setState(() {
              final next = position + details.delta;
              final updated = Offset(
                next.dx.clamp(8.0, maxX).toDouble(),
                next.dy.clamp(8.0, maxY).toDouble(),
              );
              if (secondary) {
                _secondaryCameraOffset = updated;
              } else {
                _primaryCameraOffset = updated;
              }
            });
          },
          child: Material(
            elevation: 10,
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                previewBuilder(context),
                Positioned(
                  left: 6,
                  top: 6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.58),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.45),
                      ),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                if (secondary)
                  const Positioned(
                    right: 7,
                    top: 7,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xAA000000),
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(5),
                        child: Text(
                          '2',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    if (listenable == null) return buildPip(context);
    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) => buildPip(context),
    );
  }

  Marker _pinMarker(
    MapRoutePoint point,
    IconData icon,
    Color color,
    String semanticLabel,
  ) {
    return Marker(
      point: LatLng(point.latitude, point.longitude),
      width: 42,
      height: 42,
      child: Semantics(
        label: semanticLabel,
        child: Icon(icon, size: 34, color: color),
      ),
    );
  }

  Widget _buildUnavailable(BuildContext context) {
    final availability = _routeState.availability;
    final forever = availability == LocationTrackingAvailability.permissionDeniedForever;
    final disabled = availability == LocationTrackingAvailability.servicesDisabled;
    final title = disabled
        ? 'Localização do aparelho está desligada'
        : forever
            ? 'Permissão de localização bloqueada'
            : 'Permissão de localização necessária';
    final body = disabled
        ? 'Ative a localização do Android para mostrar sua posição e registrar o trajeto.'
        : forever
            ? 'Abra as configurações do Vigia IA e permita localização durante o uso.'
            : 'O GPS alimenta a mesma sessão de trajeto do Monitor e do mapa completo; uma rota ativa continua registrada ao trocar de tela.';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa do monitoramento'),
        actions: [
          IconButton(
            tooltip: 'Mapas offline',
            onPressed: () => unawaited(_openOfflineMaps()),
            icon: const Icon(Icons.download_for_offline_outlined),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_off_outlined, size: 56),
                const SizedBox(height: 16),
                Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(body, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () async {
                    if (disabled) {
                      await _location.openLocationSettings();
                    } else if (forever) {
                      await _location.openAppSettings();
                    } else {
                      await _initialize();
                    }
                  },
                  icon: Icon(disabled ? Icons.location_searching_rounded : Icons.settings_outlined),
                  label: Text(disabled ? 'Ativar localização' : forever ? 'Abrir configurações' : 'Permitir localização'),
                ),
                if (disabled || forever) ...[
                  const SizedBox(height: 8),
                  TextButton(onPressed: _initialize, child: const Text('Verificar novamente')),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapSourceChip extends StatelessWidget {
  const _MapSourceChip({
    required this.mode,
    required this.activePackage,
    required this.error,
    required this.onTap,
  });

  final OfflineMapMode mode;
  final OfflineMapPackage? activePackage;
  final String? error;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasOffline = activePackage != null && error == null;
    final label = error != null
        ? 'Offline com erro'
        : switch (mode) {
            OfflineMapMode.automatic => hasOffline ? 'Mapa local' : 'Online',
            OfflineMapMode.online => 'Online',
            OfflineMapMode.offline => hasOffline ? 'Offline' : 'Offline indisponível',
          };
    final icon = switch (mode) {
      OfflineMapMode.automatic => Icons.swap_calls_rounded,
      OfflineMapMode.online => Icons.cloud_outlined,
      OfflineMapMode.offline => Icons.offline_pin_outlined,
    };
    return Material(
      color: scheme.surface.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: error == null ? scheme.primary : scheme.error),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfflineAreaWarning extends StatelessWidget {
  const _OfflineAreaWarning({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wrong_location_rounded, size: 16, color: scheme.onErrorContainer),
              const SizedBox(width: 5),
              Text(
                'Fora da área offline',
                style: TextStyle(
                  color: scheme.onErrorContainer,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GpsChip extends StatelessWidget {
  const _GpsChip({required this.point});

  final MapRoutePoint? point;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accuracy = point?.accuracyMeters;
    return Material(
      color: scheme.surface.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.gps_fixed_rounded, size: 17, color: scheme.primary),
            const SizedBox(width: 6),
            Text(
              accuracy == null ? 'GPS…' : 'GPS ±${accuracy.toStringAsFixed(0)} m',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapTelemetryStrip extends StatelessWidget {
  const _MapTelemetryStrip({
    required this.paused,
    required this.speedKmh,
    required this.distance,
    required this.elapsed,
    required this.altitudeMeters,
    required this.headingDegrees,
    required this.following,
    required this.onToggleFollow,
  });

  final bool paused;
  final double speedKmh;
  final String distance;
  final String elapsed;
  final double? altitudeMeters;
  final double? headingDegrees;
  final bool following;
  final VoidCallback? onToggleFollow;

  String _direction(double? degrees) {
    if (degrees == null || degrees.isNaN) return '--';
    const labels = ['N', 'NE', 'L', 'SE', 'S', 'SO', 'O', 'NO'];
    final normalized = ((degrees % 360) + 360) % 360;
    final index = ((normalized + 22.5) ~/ 45) % 8;
    return '${labels[index]} ${normalized.toStringAsFixed(0)}°';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _MapInfoPill(
            icon: Icons.speed_rounded,
            label: '${speedKmh.toStringAsFixed(1)} km/h',
          ),
          const SizedBox(width: 5),
          _MapInfoPill(icon: Icons.route_rounded, label: distance),
          const SizedBox(width: 5),
          _MapInfoPill(icon: Icons.timer_outlined, label: elapsed),
          const SizedBox(width: 5),
          _MapInfoPill(
            icon: Icons.height_rounded,
            label: altitudeMeters == null
                ? 'Alt. --'
                : 'Alt. ${altitudeMeters!.toStringAsFixed(0)} m',
          ),
          const SizedBox(width: 5),
          _MapInfoPill(
            icon: Icons.explore_rounded,
            label: _direction(headingDegrees),
          ),
          if (paused) ...[
            const SizedBox(width: 5),
            const _MapInfoPill(
              icon: Icons.pause_circle_outline_rounded,
              label: 'Rota pausada',
            ),
          ],
          const SizedBox(width: 5),
          ActionChip(
            avatar: Icon(
              following ? Icons.navigation_rounded : Icons.pan_tool_alt_outlined,
              size: 16,
            ),
            label: Text(following ? 'Seguindo' : 'Mapa livre'),
            visualDensity: VisualDensity.compact,
            onPressed: onToggleFollow,
          ),
        ],
      ),
    );
  }
}

class _RouteButtonBar extends StatelessWidget {
  const _RouteButtonBar({
    required this.tracking,
    required this.onToggleTracking,
  });

  final bool tracking;
  final VoidCallback? onToggleTracking;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton.icon(
          onPressed: onToggleTracking,
          style: FilledButton.styleFrom(
            backgroundColor: tracking ? scheme.error : null,
          ),
          icon: Icon(
            tracking ? Icons.stop_rounded : Icons.navigation_rounded,
          ),
          label: Text(tracking ? 'Encerrar rota' : 'Iniciar rota'),
        ),
      ),
    );
  }
}

class _MapInfoPill extends StatelessWidget {
  const _MapInfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: scheme.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

