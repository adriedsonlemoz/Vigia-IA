import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_mbtiles/flutter_map_mbtiles.dart';
import 'package:latlong2/latlong.dart';

import '../models/map_route_point.dart';
import '../models/offline_map_package.dart';
import '../services/location_tracking_service.dart';
import '../services/offline_map_service.dart';
import '../widgets/offline_map_manager_sheet.dart';

class MapMonitoringScreen extends StatefulWidget {
  const MapMonitoringScreen({
    super.key,
    this.cameraPreviewBuilder,
    this.cameraAspectRatio,
    this.cameraLabel = 'Principal',
  });

  final WidgetBuilder? cameraPreviewBuilder;
  final double? cameraAspectRatio;
  final String cameraLabel;

  @override
  State<MapMonitoringScreen> createState() => _MapMonitoringScreenState();
}

class _MapMonitoringScreenState extends State<MapMonitoringScreen> {
  final MapController _mapController = MapController();
  final LocationTrackingService _location = LocationTrackingService.instance;
  final OfflineMapService _offlineMaps = OfflineMapService.instance;
  final List<MapRoutePoint> _route = <MapRoutePoint>[];

  MbTilesTileProvider? _offlineTileProvider;
  String? _offlineTilePackageId;
  String? _offlineTileError;
  int _offlineMinNativeZoom = 0;
  int _offlineMaxNativeZoom = 19;
  Offset? _cameraOffset;

  StreamSubscription<MapRoutePoint>? _positionSubscription;
  MapRoutePoint? _current;
  MapRoutePoint? _start;
  MapRoutePoint? _end;
  LocationTrackingAvailability? _availability;
  DateTime? _routeStartedAt;
  Duration _elapsed = Duration.zero;
  Timer? _elapsedTimer;
  double _distanceMeters = 0;
  bool _loading = true;
  bool _tracking = false;
  bool _followPosition = true;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _offlineMaps.addListener(_onOfflineMapsChanged);
    unawaited(_initializeOfflineMaps());
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _elapsedTimer?.cancel();
    _offlineMaps.removeListener(_onOfflineMapsChanged);
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
    final availability = await _location.ensureAvailable();
    if (!mounted) return;
    setState(() {
      _availability = availability;
      _loading = false;
    });
    if (availability != LocationTrackingAvailability.ready) return;

    try {
      final current = await _location.currentPosition();
      if (!mounted) return;
      _acceptPosition(current);
    } catch (_) {
      // The continuous stream below can still recover if a single GPS read fails.
    }

    await _positionSubscription?.cancel();
    _positionSubscription = _location.positionStream().listen(
      _acceptPosition,
      onError: (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível atualizar o GPS agora.')),
        );
      },
    );
  }

  void _acceptPosition(MapRoutePoint point) {
    if (!mounted) return;
    setState(() {
      _current = point;
      if (_tracking) {
        if (_route.isNotEmpty) {
          final step = LocationTrackingService.distanceMeters(_route.last, point);
          if (step >= 2 && step <= 250) {
            _distanceMeters += step;
          }
        }
        if (_route.isEmpty ||
            LocationTrackingService.distanceMeters(_route.last, point) >= 2) {
          _route.add(point);
        }
      }
    });
    if (_followPosition) _centerOn(point, zoom: 16);
  }

  void _centerOn(MapRoutePoint point, {double zoom = 16}) {
    if (!_mapReady) return;
    _mapController.move(LatLng(point.latitude, point.longitude), zoom);
  }

  void _startRoute() {
    final current = _current;
    if (current == null) return;
    _elapsedTimer?.cancel();
    setState(() {
      _tracking = true;
      _followPosition = true;
      _route
        ..clear()
        ..add(current);
      _start = current;
      _end = null;
      _distanceMeters = 0;
      _routeStartedAt = DateTime.now();
      _elapsed = Duration.zero;
    });
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _routeStartedAt == null) return;
      setState(() => _elapsed = DateTime.now().difference(_routeStartedAt!));
    });
    _centerOn(current);
  }

  void _finishRoute() {
    _elapsedTimer?.cancel();
    setState(() {
      _tracking = false;
      _end = _current;
    });
  }

  String _formatDistance() {
    if (_distanceMeters < 1000) return '${_distanceMeters.toStringAsFixed(0)} m';
    return '${(_distanceMeters / 1000).toStringAsFixed(2)} km';
  }

  String _formatDuration(Duration value) {
    final hours = value.inHours.toString().padLeft(2, '0');
    final minutes = (value.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_availability != LocationTrackingAvailability.ready) {
      return _buildUnavailable(context);
    }

    final scheme = Theme.of(context).colorScheme;
    final current = _current;
    final center = current == null
        ? const LatLng(-14.2350, -51.9253)
        : LatLng(current.latitude, current.longitude);
    final routePoints = _route
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList(growable: false);

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
            onPressed: () => unawaited(showOfflineMapManager(context)),
            icon: Icon(
              offlineProvider == null
                  ? Icons.download_for_offline_outlined
                  : Icons.offline_pin_rounded,
            ),
          ),
          IconButton(
            tooltip: 'Centralizar',
            onPressed: current == null
                ? null
                : () {
                    setState(() => _followPosition = true);
                    _centerOn(current);
                  },
            icon: const Icon(Icons.my_location_rounded),
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
                    final point = _current;
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
                  if (routePoints.length >= 2)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: routePoints,
                          strokeWidth: 5,
                          color: scheme.primary,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      if (_start != null)
                        _pinMarker(
                          _start!,
                          Icons.flag_rounded,
                          Colors.green,
                          'Início',
                        ),
                      if (_end != null)
                        _pinMarker(
                          _end!,
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
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: scheme.primary,
                                border: Border.all(color: Colors.white, width: 3),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  Positioned(
                    right: 8,
                    bottom: 174,
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
                          mode == OfflineMapMode.offline
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
                  onTap: () => unawaited(showOfflineMapManager(context)),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: _GpsChip(point: current),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _MapRidePanel(
                  tracking: _tracking,
                  speedKmh: current?.speedKilometersPerHour ?? 0,
                  distance: _formatDistance(),
                  elapsed: _formatDuration(_elapsed),
                  lastUpdate: current?.recordedAt,
                  accuracy: current?.accuracyMeters,
                  onToggleTracking: current == null
                      ? null
                      : _tracking
                          ? _finishRoute
                          : _startRoute,
                  onCenter: current == null
                      ? null
                      : () {
                          setState(() => _followPosition = true);
                          _centerOn(current);
                        },
                ),
              ),
              if (widget.cameraPreviewBuilder != null)
                _buildCameraPip(context, constraints),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCameraPip(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final previewBuilder = widget.cameraPreviewBuilder!;
    final scheme = Theme.of(context).colorScheme;
    final width = (constraints.maxWidth * 0.31).clamp(132.0, 196.0).toDouble();
    final aspectRatio = (widget.cameraAspectRatio ?? (16 / 9)).clamp(0.65, 2.2);
    final height = (width / aspectRatio).clamp(88.0, 152.0).toDouble();
    final fallback = Offset(
      constraints.maxWidth - width - 12,
      58,
    );
    final raw = _cameraOffset ?? fallback;
    final maxX = (constraints.maxWidth - width - 8).clamp(8.0, double.infinity);
    final maxY = (constraints.maxHeight - height - 8).clamp(8.0, double.infinity);
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
            _cameraOffset = Offset(
              next.dx.clamp(8.0, maxX).toDouble(),
              next.dy.clamp(8.0, maxY).toDouble(),
            );
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
                right: 6,
                bottom: 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.62),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.drag_indicator_rounded,
                          size: 15,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.cameraLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
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
    final availability = _availability;
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
            : 'O mapa usa o GPS apenas durante esta tela e durante uma rota iniciada por você.';

    return Scaffold(
      appBar: AppBar(title: const Text('Mapa do monitoramento')),
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
            OfflineMapMode.automatic => hasOffline ? 'Auto + offline' : 'Online',
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

class _MapRidePanel extends StatelessWidget {
  const _MapRidePanel({
    required this.tracking,
    required this.speedKmh,
    required this.distance,
    required this.elapsed,
    required this.lastUpdate,
    required this.accuracy,
    required this.onToggleTracking,
    required this.onCenter,
  });

  final bool tracking;
  final double speedKmh;
  final String distance;
  final String elapsed;
  final DateTime? lastUpdate;
  final double? accuracy;
  final VoidCallback? onToggleTracking;
  final VoidCallback? onCenter;

  String _time(DateTime? value) {
    if (value == null) return '--:--:--';
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Card(
        elevation: 5,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: _Metric(label: 'Velocidade', value: '${speedKmh.toStringAsFixed(1)} km/h')),
                  Expanded(child: _Metric(label: 'Distância', value: distance)),
                  Expanded(child: _Metric(label: 'Tempo', value: elapsed)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Atualização ${_time(lastUpdate)}${accuracy == null ? '' : ' · ±${accuracy!.toStringAsFixed(0)} m'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Centralizar no GPS',
                    onPressed: onCenter,
                    icon: const Icon(Icons.my_location_rounded),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: onToggleTracking,
                    style: FilledButton.styleFrom(
                      backgroundColor: tracking ? scheme.error : null,
                    ),
                    icon: Icon(tracking ? Icons.stop_rounded : Icons.navigation_rounded),
                    label: Text(tracking ? 'Encerrar' : 'Iniciar rota'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}
