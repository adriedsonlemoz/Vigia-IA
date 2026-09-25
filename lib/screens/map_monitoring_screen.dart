import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_mbtiles/flutter_map_mbtiles.dart';
import 'package:latlong2/latlong.dart';

import '../models/map_navigation_target.dart';
import '../models/map_route_point.dart';
import '../models/offline_map_package.dart';
import '../models/route_explorer_models.dart';
import '../services/location_tracking_service.dart';
import '../services/map_gps_filter.dart';
import '../services/map_route_service.dart';
import '../services/map_view_policy.dart';
import '../services/map_view_settings_service.dart';
import '../services/native_platform_service.dart';
import '../services/offline_map_service.dart';
import '../services/route_explorer_service.dart';
import '../services/system_ui_service.dart';
import '../widgets/offline_map_manager_sheet.dart';

enum _MapPoiQuickFilter { all, fuel, food, health, water, other }

enum _MapQuickView { near, region, route }

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
    this.initialPointOfInterest,
  });

  final WidgetBuilder? cameraPreviewBuilder;
  final double? cameraAspectRatio;
  final Listenable? cameraListenable;
  final double? Function()? cameraAspectRatioProvider;
  final WidgetBuilder? secondaryCameraPreviewBuilder;
  final Listenable? secondaryCameraListenable;
  final double? Function()? secondaryCameraAspectRatioProvider;
  final RouteExplorerResult? initialPointOfInterest;

  @override
  State<MapMonitoringScreen> createState() => _MapMonitoringScreenState();
}

class _MapMonitoringScreenState extends State<MapMonitoringScreen> {
  final MapController _mapController = MapController();
  final LocationTrackingService _location = LocationTrackingService.instance;
  final OfflineMapService _offlineMaps = OfflineMapService.instance;
  final MapRouteService _routeState = MapRouteService.instance;
  final NativePlatformService _native = NativePlatformService.instance;
  final RouteExplorerService _routeExplorer = RouteExplorerService.instance;
  final MapViewSettingsService _mapViewSettings = MapViewSettingsService.instance;

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
  Size _mapViewportSize = Size.zero;
  bool _compactLandscape = false;
  _MapQuickView? _quickView = _MapQuickView.near;
  double? _customFollowZoom;
  DateTime? _lastFollowCameraPointAt;
  _MapPoiQuickFilter _poiFilter = _MapPoiQuickFilter.all;
  String? _selectedPoiId;

  @override
  void initState() {
    super.initState();
    _offlineMaps.addListener(_onOfflineMapsChanged);
    _routeState.addListener(_onRouteStateChanged);
    _routeExplorer.addListener(_onRouteExplorerChanged);
    _selectedPoiId = widget.initialPointOfInterest?.id;
    unawaited(SystemUiService.edgeToEdge());
    unawaited(_initializeOfflineMaps());
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _offlineMaps.removeListener(_onOfflineMapsChanged);
    _routeState.removeListener(_onRouteStateChanged);
    _routeExplorer.removeListener(_onRouteExplorerChanged);
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
    await _mapViewSettings.initialize();
    _quickView = switch (_mapViewSettings.followViewPreset) {
      MapFollowViewPreset.near => _MapQuickView.near,
      MapFollowViewPreset.region => _MapQuickView.region,
    };
    await _routeState.initialize(requestPermission: true);
    await _routeExplorer.initialize();
    if (!mounted) return;
    setState(() {});
    if (_routeState.availability == LocationTrackingAvailability.ready &&
        _routeState.current != null &&
        _routeExplorer.results.isEmpty &&
        !_routeExplorer.loading) {
      unawaited(_routeExplorer.searchNow(requestPermission: false));
    }
  }

  void _onRouteExplorerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onRouteStateChanged() {
    if (!mounted) return;
    setState(() {});
    final current = _routeState.current;
    if (_followPosition &&
        current != null &&
        current.recordedAt != _lastFollowCameraPointAt) {
      _applyFollowCamera(current);
    }
  }

  double get _followZoom {
    final custom = _customFollowZoom;
    if (custom != null) return custom;
    if (_quickView == _MapQuickView.region) {
      return MapViewPolicy.regionZoom;
    }
    return MapViewPolicy.nearZoom;
  }

  double get _followOffsetY => MapViewPolicy.followOffsetPixels(
        viewportHeight: _mapViewportSize.height,
        compactLandscape: _compactLandscape,
      );

  void _applyFollowCamera(
    MapRoutePoint point, {
    double? zoom,
    bool forceRotation = false,
  }) {
    if (!_mapReady) return;
    try {
      if (_mapViewSettings.orientationMode == MapOrientationMode.northUp) {
        if (_mapController.camera.rotation.abs() > 0.1) {
          _mapController.rotate(0);
        }
      } else {
        final heading = point.headingDegrees;
        if (heading != null &&
            MapViewPolicy.shouldApplyHeadingRotation(
              headingDegrees: heading,
              speedKmh: point.speedKilometersPerHour,
              currentMapRotationDegrees: _mapController.camera.rotation,
              force: forceRotation,
            )) {
          _mapController.rotate(
            MapViewPolicy.mapRotationForHeading(heading),
          );
        }
      }
      _mapController.move(
        LatLng(point.latitude, point.longitude),
        zoom ?? _followZoom,
        offset: Offset(0, _followOffsetY),
      );
      _lastFollowCameraPointAt = point.recordedAt;
    } catch (_) {}
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

  Future<void> _startRecording() async {
    setState(() {
      _followPosition = true;
      if (_quickView == _MapQuickView.route) {
        _quickView = _MapQuickView.near;
        _customFollowZoom = null;
      }
    });
    final started = await _routeState.startRecording();
    if (!mounted) return;
    if (!started) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Aguardando GPS com precisão de até '
            '${MapGpsFilter.maximumRecordingAccuracyMeters.toStringAsFixed(0)} m para gravar o percurso.',
          ),
        ),
      );
      return;
    }
    final current = _routeState.current;
    if (current != null) _applyFollowCamera(current, forceRotation: true);
  }

  void _finishRecording() {
    unawaited(_routeState.finishRecording());
  }

  void _togglePauseRecording() {
    if (!_routeState.recording) return;
    if (_routeState.paused) {
      unawaited(_routeState.resumeRecording());
    } else {
      unawaited(_routeState.pauseRecording());
    }
  }

  void _navigateToPoi(RouteExplorerResult item) {
    setState(() {
      _followPosition = true;
      _quickView = _MapQuickView.near;
      _customFollowZoom = null;
      _selectedPoiId = item.id;
    });
    unawaited(
      _routeState.navigateTo(
        MapNavigationTarget(
          latitude: item.latitude,
          longitude: item.longitude,
          label: item.title,
          startedAt: DateTime.now(),
          sourceId: item.id,
        ),
      ),
    );
    final current = _routeState.current;
    if (current != null) _applyFollowCamera(current, forceRotation: true);
  }

  void _stopNavigation() {
    unawaited(_routeState.stopNavigation());
  }

  Future<void> _exportGpx() async {
    if (_routeState.route.isEmpty) return;
    try {
      final gpx = _routeState.buildGpx();
      final now = DateTime.now();
      String two(int value) => value.toString().padLeft(2, '0');
      final name = 'VigiaIA-percurso-${now.year}${two(now.month)}${two(now.day)}-'
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
                : 'Percurso GPX exportado.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível exportar o percurso: $error')),
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

  bool get _hasCameraOverlay =>
      widget.cameraPreviewBuilder != null ||
      widget.secondaryCameraPreviewBuilder != null;

  List<RouteExplorerResult> get _visiblePois => _routeExplorer.results
      .where((item) => _matchesPoiFilter(item, _poiFilter))
      .toList(growable: false);

  void _toggleFollow() {
    final current = _routeState.current;
    if (current == null) return;
    final next = !_followPosition;
    setState(() {
      _followPosition = next;
      if (next && _quickView == _MapQuickView.route) {
        _quickView = _MapQuickView.near;
        _customFollowZoom = null;
      }
    });
    if (next) _applyFollowCamera(current, forceRotation: true);
  }

  void _zoomBy(double delta) {
    if (!_mapReady) return;
    try {
      final camera = _mapController.camera;
      final nextZoom = (camera.zoom + delta).clamp(3.0, 19.0).toDouble();
      final current = _routeState.current;
      if (_followPosition && current != null) {
        setState(() {
          _quickView = null;
          _customFollowZoom = nextZoom;
        });
        _applyFollowCamera(current, zoom: nextZoom);
      } else {
        setState(() {
          _quickView = null;
          _customFollowZoom = null;
        });
        _mapController.move(camera.center, nextZoom);
      }
    } catch (_) {}
  }

  void _toggleOrientationMode() {
    final next = _mapViewSettings.orientationMode == MapOrientationMode.northUp
        ? MapOrientationMode.headingUp
        : MapOrientationMode.northUp;
    final persistChange = _mapViewSettings.setOrientationMode(next);
    setState(() {});
    unawaited(persistChange);

    if (!_mapReady) return;
    final current = _routeState.current;
    if (next == MapOrientationMode.northUp) {
      _mapController.rotate(0);
      if (_followPosition && current != null) {
        _applyFollowCamera(current, forceRotation: true);
      }
      return;
    }
    final heading = current?.headingDegrees;
    if (heading == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Acompanhamento por direção ativado; aguardando rumo do GPS.'),
        ),
      );
      return;
    }
    if (_followPosition && current != null) {
      _applyFollowCamera(current, forceRotation: true);
    } else {
      _mapController.rotate(MapViewPolicy.mapRotationForHeading(heading));
    }
  }

  void _selectQuickView(_MapQuickView view) {
    final current = _routeState.current;
    if (view == _MapQuickView.route) {
      _showRouteOverview();
      return;
    }
    if (current == null) return;
    final preset = view == _MapQuickView.near
        ? MapFollowViewPreset.near
        : MapFollowViewPreset.region;
    setState(() {
      _quickView = view;
      _customFollowZoom = null;
      _followPosition = true;
    });
    unawaited(_mapViewSettings.setFollowViewPreset(preset));
    _applyFollowCamera(
      current,
      zoom: MapViewPolicy.zoomFor(preset),
      forceRotation: true,
    );
  }

  void _showRouteOverview() {
    if (!_mapReady) return;
    final coordinates = <LatLng>[
      for (final point in _routeState.route)
        LatLng(point.latitude, point.longitude),
    ];
    final current = _routeState.current;
    if (current != null) {
      coordinates.add(LatLng(current.latitude, current.longitude));
    }
    final target = _routeState.navigationTarget;
    if (target != null) {
      coordinates.add(LatLng(target.latitude, target.longitude));
    }
    if (coordinates.length < 2) {
      if (current != null) {
        _selectQuickView(_MapQuickView.region);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Grave um percurso ou escolha um destino para usar a visão Rota.'),
        ),
      );
      return;
    }
    setState(() {
      _quickView = _MapQuickView.route;
      _customFollowZoom = null;
      _followPosition = false;
    });
    try {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: coordinates,
          padding: const EdgeInsets.fromLTRB(52, 138, 68, 132),
          minZoom: 3,
          maxZoom: 15.5,
        ),
      );
    } catch (_) {}
  }

  bool _matchesPoiFilter(
    RouteExplorerResult item,
    _MapPoiQuickFilter filter,
  ) {
    return switch (filter) {
      _MapPoiQuickFilter.all => true,
      _MapPoiQuickFilter.fuel => item.category == RouteExplorerCategory.fuel,
      _MapPoiQuickFilter.food =>
        item.category == RouteExplorerCategory.restaurant,
      _MapPoiQuickFilter.health =>
        item.category == RouteExplorerCategory.health,
      _MapPoiQuickFilter.water => item.category == RouteExplorerCategory.water,
      _MapPoiQuickFilter.other =>
        item.category == RouteExplorerCategory.stop ||
            item.category == RouteExplorerCategory.workshop ||
            item.category == RouteExplorerCategory.riverBridge,
    };
  }

  String _poiFilterLabel(_MapPoiQuickFilter filter) => switch (filter) {
        _MapPoiQuickFilter.all => 'Todos',
        _MapPoiQuickFilter.fuel => 'Postos',
        _MapPoiQuickFilter.food => 'Comida',
        _MapPoiQuickFilter.health => 'Saúde',
        _MapPoiQuickFilter.water => 'Água',
        _MapPoiQuickFilter.other => 'Outros',
      };

  IconData _poiIcon(RouteExplorerCategory category) => switch (category) {
        RouteExplorerCategory.fuel => Icons.local_gas_station_rounded,
        RouteExplorerCategory.restaurant => Icons.restaurant_rounded,
        RouteExplorerCategory.stop => Icons.local_parking_rounded,
        RouteExplorerCategory.workshop => Icons.build_rounded,
        RouteExplorerCategory.health => Icons.local_hospital_rounded,
        RouteExplorerCategory.water => Icons.water_drop_rounded,
        RouteExplorerCategory.riverBridge => Icons.water_rounded,
      };

  void _focusPoi(RouteExplorerResult item) {
    if (!_mapReady) return;
    setState(() {
      _followPosition = false;
      _quickView = null;
      _customFollowZoom = null;
      _selectedPoiId = item.id;
    });
    _mapController.move(LatLng(item.latitude, item.longitude), 16);
  }

  Future<void> _showPoiDetails(RouteExplorerResult item) async {
    _focusPoi(item);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: scheme.primaryContainer,
                      child: Icon(
                        _poiIcon(item.category),
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.category.label} · ${item.source == 'offline' ? 'Offline' : 'Online'}',
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _routeExplorer.formatDistance(item.distanceMeters),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                if (item.subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(item.subtitle),
                ],
                const SizedBox(height: 12),
                Text(
                  '${item.latitude.toStringAsFixed(5)}, ${item.longitude.toStringAsFixed(5)}',
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.map_rounded),
                        label: const Text('Mostrar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          _navigateToPoi(item);
                        },
                        icon: const Icon(Icons.navigation_rounded),
                        label: const Text('Navegar até'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _refreshNearby({bool saveAsOffline = false}) async {
    try {
      await _routeExplorer.searchNow(
        requestPermission: false,
        saveAsOffline: saveAsOffline,
      );
      if (!mounted) return;
      final message = _routeExplorer.statusMessage;
      if (message != null && message.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível atualizar os pontos: $error')),
      );
    }
  }

  Future<void> _showNearbyPoints() async {
    await _routeExplorer.initialize();
    if (!mounted) return;
    var filter = _poiFilter;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.82,
            child: ListenableBuilder(
              listenable: _routeExplorer,
              builder: (context, _) {
                final service = _routeExplorer;
                final filtered = service.results
                    .where((item) => _matchesPoiFilter(item, filter))
                    .toList(growable: false);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 8, 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Próximos pontos',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  '${service.settings.radiusKm} km · ${service.lastSource == 'offline' ? 'dados offline' : 'busca online'}',
                                  style: Theme.of(sheetContext).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Configurações do mapa',
                            onPressed: () {
                              Navigator.of(sheetContext).pop();
                              unawaited(_showMapSettings());
                            },
                            icon: const Icon(Icons.settings_rounded),
                          ),
                        ],
                      ),
                    ),
                    if (service.loading)
                      const LinearProgressIndicator(minHeight: 2),
                    SizedBox(
                      height: 43,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: [
                          for (final item in _MapPoiQuickFilter.values) ...[
                            ChoiceChip(
                              label: Text(_poiFilterLabel(item)),
                              selected: filter == item,
                              onSelected: (_) {
                                setSheetState(() => filter = item);
                                setState(() => _poiFilter = item);
                              },
                            ),
                            const SizedBox(width: 6),
                          ],
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: service.loading
                                  ? null
                                  : () => unawaited(_refreshNearby()),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Atualizar'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: service.loading
                                  ? null
                                  : () => unawaited(
                                        _refreshNearby(saveAsOffline: true),
                                      ),
                              icon: const Icon(Icons.download_for_offline_rounded),
                              label: const Text('Salvar offline'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: service.error != null && service.results.isEmpty
                          ? _MapEmptyState(message: service.error!)
                          : filtered.isEmpty
                              ? const _MapEmptyState(
                                  message:
                                      'Nenhum ponto neste filtro. Atualize a busca ou aumente o raio.',
                                )
                              : ListView.separated(
                                  padding:
                                      const EdgeInsets.fromLTRB(12, 0, 12, 18),
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 5),
                                  itemBuilder: (context, index) {
                                    final item = filtered[index];
                                    return Card(
                                      margin: EdgeInsets.zero,
                                      child: ListTile(
                                        dense: true,
                                        leading: CircleAvatar(
                                          child: Icon(
                                            _poiIcon(item.category),
                                            size: 18,
                                          ),
                                        ),
                                        title: Text(
                                          item.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          '${item.category.label} · ${item.source == 'offline' ? 'Offline' : 'Online'}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        trailing: Text(
                                          service.formatDistance(
                                            item.distanceMeters,
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        onTap: () {
                                          Navigator.of(sheetContext).pop();
                                          _focusPoi(item);
                                        },
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showMapSettings() async {
    await _routeExplorer.initialize();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.88,
          child: ListenableBuilder(
            listenable: _routeExplorer,
            builder: (context, _) {
              final settings = _routeExplorer.settings;
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
                children: [
                  const Text(
                    'Configurações do mapa',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Busca de locais, avisos de aproximação, gravação de percurso e mapas offline.',
                  ),
                  const SizedBox(height: 18),
                  const _MapSettingsTitle('Raio de busca'),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final value in const <int>[5, 10, 20, 50])
                        ChoiceChip(
                          label: Text('$value km'),
                          selected: settings.radiusKm == value,
                          onSelected: (_) => unawaited(
                            _routeExplorer.setRadiusKm(value),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const _MapSettingsTitle('Busca durante o deslocamento'),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: false,
                        icon: Icon(Icons.my_location_rounded),
                        label: Text('Ao redor'),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        icon: Icon(Icons.route_rounded),
                        label: Text('No caminho'),
                      ),
                    ],
                    selected: <bool>{settings.searchAheadWhenMoving},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) => unawaited(
                      _routeExplorer
                          .setSearchAheadWhenMoving(selection.first),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _MapSettingsTitle('Categorias'),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final category in RouteExplorerCategory.values)
                        FilterChip(
                          avatar: Icon(_poiIcon(category), size: 16),
                          label: Text(category.label),
                          selected: settings.categories.contains(category),
                          showCheckmark: false,
                          onSelected: (_) => unawaited(
                            _routeExplorer.toggleCategory(category),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const _MapSettingsTitle('Alertas de aproximação'),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Ativar alertas'),
                    subtitle: const Text(
                      'Avisa sobre postos, comida, saúde, água e demais categorias selecionadas.',
                    ),
                    value: settings.alertsEnabled,
                    onChanged: (value) => unawaited(
                      _routeExplorer.setAlertsEnabled(value),
                    ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Falar aviso'),
                    value: settings.voiceEnabled,
                    onChanged: settings.alertsEnabled
                        ? (value) => unawaited(
                              _routeExplorer.setVoiceEnabled(value),
                            )
                        : null,
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Notificação Android'),
                    value: settings.notificationEnabled,
                    onChanged: settings.alertsEnabled
                        ? (value) => unawaited(
                              _routeExplorer.setNotificationEnabled(value),
                            )
                        : null,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final distance in const <int>[1000, 3000, 5000, 10000])
                        ChoiceChip(
                          label: Text('${distance ~/ 1000} km'),
                          selected:
                              settings.alertDistanceMeters == distance,
                          onSelected: settings.alertsEnabled
                              ? (_) => unawaited(
                                    _routeExplorer
                                        .setAlertDistanceMeters(distance),
                                  )
                              : null,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const _MapSettingsTitle('Offline e percurso'),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      unawaited(_openOfflineMaps());
                    },
                    icon: const Icon(Icons.offline_map_rounded),
                    label: const Text('Mapas offline'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _routeState.route.length >= 2
                        ? () => unawaited(_exportGpx())
                        : null,
                    icon: const Icon(Icons.file_upload_outlined),
                    label: const Text('Exportar percurso em GPX'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Durante a gravação de um percurso, a busca “No caminho” se atualiza automaticamente após deslocamento relevante ou alguns minutos, usando a lista offline se a rede falhar.',
                    style: Theme.of(sheetContext).textTheme.bodySmall,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
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
    final safePadding = MediaQuery.paddingOf(context);
    final current = _routeState.current;
    final navigationTarget = _routeState.navigationTarget;
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
    final visiblePois = _visiblePois;
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
    final topInset = safePadding.top + 8;
    final bottomInset = safePadding.bottom + 8;

    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalControls = constraints.maxHeight < 520;
          _mapViewportSize = Size(constraints.maxWidth, constraints.maxHeight);
          _compactLandscape = horizontalControls;
          return Stack(
            fit: StackFit.expand,
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: current == null ? 12.5 : _followZoom,
                  minZoom: 3,
                  maxZoom: 19,
                  interactionOptions: InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onMapReady: () {
                    _mapReady = true;
                    final initialPoi = widget.initialPointOfInterest;
                    if (initialPoi != null) {
                      _followPosition = false;
                      _quickView = null;
                      _customFollowZoom = null;
                      _selectedPoiId = initialPoi.id;
                      _mapController.move(
                        LatLng(initialPoi.latitude, initialPoi.longitude),
                        16,
                      );
                    } else {
                      final point = _routeState.current;
                      if (point != null) {
                        _applyFollowCamera(point, forceRotation: true);
                      }
                    }
                  },
                  onPositionChanged: (_, hasGesture) {
                    if (hasGesture && _followPosition && mounted) {
                      setState(() {
                        _followPosition = false;
                        _quickView = null;
                        _customFollowZoom = null;
                      });
                    }
                  },
                  onTap: (_, _) {
                    if (_selectedPoiId != null) {
                      setState(() => _selectedPoiId = null);
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
                      for (final item in visiblePois)
                        Marker(
                          point: LatLng(item.latitude, item.longitude),
                          width: item.id == _selectedPoiId ? 48 : 40,
                          rotate: true,
                          height: item.id == _selectedPoiId ? 48 : 40,
                          child: Semantics(
                            button: true,
                            label:
                                '${item.title}, ${_routeExplorer.formatDistance(item.distanceMeters)}',
                            child: GestureDetector(
                              onTap: () => unawaited(_showPoiDetails(item)),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: item.id == _selectedPoiId
                                      ? scheme.primary
                                      : scheme.surface.withValues(alpha: 0.94),
                                  border: Border.all(
                                    color: item.id == _selectedPoiId
                                        ? Colors.white
                                        : scheme.primary.withValues(alpha: 0.72),
                                    width: item.id == _selectedPoiId ? 3 : 2,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      blurRadius: 7,
                                      color: Color(0x44000000),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  _poiIcon(item.category),
                                  size: item.id == _selectedPoiId ? 23 : 19,
                                  color: item.id == _selectedPoiId
                                      ? scheme.onPrimary
                                      : scheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
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
                      if (navigationTarget != null)
                        Marker(
                          point: LatLng(
                            navigationTarget.latitude,
                            navigationTarget.longitude,
                          ),
                          width: 52,
                          rotate: true,
                          height: 52,
                          child: Tooltip(
                            message: 'Destino: ${navigationTarget.label}',
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: scheme.tertiaryContainer,
                                border: Border.all(
                                  color: scheme.tertiary,
                                  width: 3,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    blurRadius: 8,
                                    color: Color(0x55000000),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.flag_circle_rounded,
                                color: scheme.onTertiaryContainer,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      if (current != null)
                        Marker(
                          point: LatLng(current.latitude, current.longitude),
                          width: 54,
                          rotate: false,
                          height: 54,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: scheme.primary.withValues(alpha: 0.18),
                            ),
                            alignment: Alignment.center,
                            child: Container(
                              width: 31,
                              height: 31,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: scheme.primary,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: const [
                                  BoxShadow(
                                    blurRadius: 7,
                                    color: Color(0x55000000),
                                  ),
                                ],
                              ),
                              child: current.headingDegrees == null
                                  ? const Icon(
                                      Icons.circle,
                                      size: 10,
                                      color: Colors.white,
                                    )
                                  : Transform.rotate(
                                      angle:
                                          current.headingDegrees! * math.pi / 180,
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
                ],
              ),

              // O mapa permanece sob as áreas do sistema; somente os controles
              // respeitam notch/status/navigation bar para evitar faixas vazias.
              Positioned(
                top: topInset,
                left: 8,
                child: _MapControlButton(
                  tooltip: 'Voltar',
                  icon: Icons.arrow_back_rounded,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              Positioned(
                top: topInset,
                left: 58,
                child: _MapSourceChip(
                  mode: mode,
                  activePackage: activeOffline,
                  error: _offlineTileError,
                  onTap: () => unawaited(_openOfflineMaps()),
                ),
              ),
              Positioned(
                top: topInset,
                right: 8,
                child: _GpsChip(point: current),
              ),
              Positioned(
                top: topInset + 46,
                left: 8,
                right: 58,
                child: _MapTelemetryStrip(
                  paused: _routeState.paused,
                  speedKmh: current?.speedKilometersPerHour ?? 0,
                  distance: _formatDistance(),
                  elapsed: _formatDuration(_routeState.elapsed),
                  altitudeMeters: current?.altitudeMeters,
                  headingDegrees: current?.headingDegrees,
                  following: _followPosition,
                  onToggleFollow: current == null ? null : _toggleFollow,
                ),
              ),
              Positioned(
                top: topInset + 87,
                left: 8,
                child: _MapQuickViewBar(
                  selected: _quickView,
                  routeAvailable:
                      _routeState.route.length >= 2 || navigationTarget != null,
                  onSelected: _selectQuickView,
                ),
              ),
              if (outsideOfflineArea && mode != OfflineMapMode.online)
                Positioned(
                  top: topInset + 128,
                  left: 8,
                  child: _OfflineAreaWarning(
                    onTap: () => unawaited(_openOfflineMaps()),
                  ),
                ),
              Positioned(
                top: horizontalControls ? null : topInset + 98,
                right: 8,
                bottom: horizontalControls ? bottomInset + 58 : null,
                child: Flex(
                  direction:
                      horizontalControls ? Axis.horizontal : Axis.vertical,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MapControlButton(
                      tooltip: 'Aumentar zoom',
                      icon: Icons.add_rounded,
                      onPressed: () => _zoomBy(1),
                    ),
                    _MapControlGap(horizontal: horizontalControls),
                    _MapControlButton(
                      tooltip: 'Diminuir zoom',
                      icon: Icons.remove_rounded,
                      onPressed: () => _zoomBy(-1),
                    ),
                    _MapControlGap(horizontal: horizontalControls),
                    _MapControlButton(
                      tooltip: _followPosition
                          ? 'Posição sendo seguida'
                          : 'Centralizar e seguir posição',
                      icon: _followPosition
                          ? Icons.navigation_rounded
                          : Icons.my_location_rounded,
                      active: _followPosition,
                      onPressed: current == null ? null : _toggleFollow,
                    ),
                    _MapControlGap(horizontal: horizontalControls),
                    _MapControlButton(
                      tooltip: _mapViewSettings.orientationMode ==
                              MapOrientationMode.headingUp
                          ? 'Acompanhando direção · tocar para Norte fixo'
                          : 'Norte fixo · tocar para acompanhar direção',
                      icon: _mapViewSettings.orientationMode ==
                              MapOrientationMode.headingUp
                          ? Icons.explore_rounded
                          : Icons.north_rounded,
                      active: _mapViewSettings.orientationMode ==
                          MapOrientationMode.headingUp,
                      onPressed: current == null ? null : _toggleOrientationMode,
                    ),
                    _MapControlGap(horizontal: horizontalControls),
                    _MapControlButton(
                      tooltip: 'Próximos pontos',
                      icon: Icons.place_rounded,
                      badge: _routeExplorer.results.isEmpty
                          ? null
                          : '${_routeExplorer.results.length}',
                      active: _poiFilter != _MapPoiQuickFilter.all,
                      onPressed: () => unawaited(_showNearbyPoints()),
                    ),
                    _MapControlGap(horizontal: horizontalControls),
                    _MapControlButton(
                      tooltip: _camerasVisible
                          ? 'Ocultar câmeras sobre o mapa'
                          : 'Mostrar câmeras sobre o mapa',
                      icon: _hasCameraOverlay
                          ? (_camerasVisible
                              ? Icons.videocam_rounded
                              : Icons.videocam_off_rounded)
                          : Icons.no_photography_outlined,
                      active: _hasCameraOverlay && _camerasVisible,
                      onPressed: _hasCameraOverlay
                          ? () => setState(
                                () => _camerasVisible = !_camerasVisible,
                              )
                          : null,
                    ),
                    _MapControlGap(horizontal: horizontalControls),
                    _MapControlButton(
                      tooltip: 'Mapas offline',
                      icon: offlineProvider == null
                          ? Icons.download_for_offline_outlined
                          : Icons.offline_pin_rounded,
                      active: offlineProvider != null,
                      onPressed: () => unawaited(_openOfflineMaps()),
                    ),
                    _MapControlGap(horizontal: horizontalControls),
                    _MapControlButton(
                      tooltip: 'Configurações do mapa',
                      icon: Icons.settings_rounded,
                      onPressed: () => unawaited(_showMapSettings()),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 8,
                bottom: bottomInset + 58,
                child: _MapAttribution(
                  text: mode != OfflineMapMode.online &&
                          activeOffline?.providerId == 'stadia-alidade-smooth'
                      ? '© Stadia Maps · OpenMapTiles · OpenStreetMap'
                      : mode == OfflineMapMode.offline
                          ? 'Mapa offline · licença do pacote'
                          : '© OpenStreetMap contributors',
                ),
              ),
              if (navigationTarget != null)
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: bottomInset + 62,
                  child: _NavigationBanner(
                    target: navigationTarget,
                    distanceMeters: _routeState.navigationDistanceMeters,
                    bearingDegrees: _routeState.navigationBearingDegrees,
                    onStop: _stopNavigation,
                  ),
                ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _RouteButtonBar(
                  recording: _routeState.recording,
                  paused: _routeState.paused,
                  hasRoute: _routeState.route.length >= 2,
                  onToggleRecording: current == null
                      ? null
                      : _routeState.recording
                          ? _finishRecording
                          : () => unawaited(_startRecording()),
                  onTogglePause:
                      _routeState.recording ? _togglePauseRecording : null,
                  onExport: _routeState.route.length >= 2
                      ? () => unawaited(_exportGpx())
                      : null,
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

      final safePadding = MediaQuery.paddingOf(context);
      final shortLayout = constraints.maxHeight < 520;
      final defaultTop = safePadding.top +
          (shortLayout ? 164.0 : secondary ? 320.0 : 164.0);
      // Em paisagem as duas câmeras começam lado a lado; em retrato, empilhadas.
      final fallback = Offset(
        shortLayout && secondary ? width + 20 : 10,
        defaultTop,
      );
      final raw = secondary
          ? (_secondaryCameraOffset ?? fallback)
          : (_primaryCameraOffset ?? fallback);
      final maxX = (constraints.maxWidth - width - 58)
          .clamp(8.0, double.infinity);
      // Reserva a barra compacta da rota e a navegação do sistema.
      final maxY = (constraints.maxHeight - height - safePadding.bottom - 66)
          .clamp(8.0, double.infinity);
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
      rotate: true,
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
            : 'O GPS alimenta a mesma sessão de trajeto do Monitor e do mapa completo; um percurso em gravação continua registrado ao trocar de tela.';

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

class _MapQuickViewBar extends StatelessWidget {
  const _MapQuickViewBar({
    required this.selected,
    required this.routeAvailable,
    required this.onSelected,
  });

  final _MapQuickView? selected;
  final bool routeAvailable;
  final ValueChanged<_MapQuickView> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 3,
      color: scheme.surface.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MapQuickViewButton(
            label: 'Perto',
            icon: Icons.near_me_rounded,
            active: selected == _MapQuickView.near,
            onPressed: () => onSelected(_MapQuickView.near),
          ),
          _MapQuickViewButton(
            label: 'Região',
            icon: Icons.public_rounded,
            active: selected == _MapQuickView.region,
            onPressed: () => onSelected(_MapQuickView.region),
          ),
          _MapQuickViewButton(
            label: 'Rota',
            icon: Icons.route_rounded,
            active: selected == _MapQuickView.route,
            onPressed:
                routeAvailable ? () => onSelected(_MapQuickView.route) : null,
          ),
        ],
      ),
    );
  }
}

class _MapQuickViewButton extends StatelessWidget {
  const _MapQuickViewButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    return InkWell(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        color: active ? scheme.primaryContainer : Colors.transparent,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: !enabled
                  ? scheme.onSurface.withValues(alpha: 0.32)
                  : active
                      ? scheme.onPrimaryContainer
                      : scheme.onSurface,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                color: !enabled
                    ? scheme.onSurface.withValues(alpha: 0.32)
                    : active
                        ? scheme.onPrimaryContainer
                        : scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapControlGap extends StatelessWidget {
  const _MapControlGap({required this.horizontal});

  final bool horizontal;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: horizontal ? 6 : 0,
        height: horizontal ? 0 : 6,
      );
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.active = false,
    this.badge,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool active;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    final background = active
        ? scheme.primaryContainer.withValues(alpha: 0.96)
        : scheme.surface.withValues(alpha: enabled ? 0.94 : 0.78);
    final foreground = active
        ? scheme.onPrimaryContainer
        : enabled
            ? scheme.onSurface
            : scheme.onSurface.withValues(alpha: 0.38);
    return Tooltip(
      message: tooltip,
      child: Material(
        elevation: enabled ? 4 : 1,
        color: background,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, color: foreground, size: 21),
                if (badge != null)
                  Positioned(
                    right: 2,
                    top: 2,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 17),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badge!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: scheme.onError,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapAttribution extends StatelessWidget {
  const _MapAttribution({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Text(text, style: const TextStyle(fontSize: 9.5)),
        ),
      ),
    );
  }
}

class _MapEmptyState extends StatelessWidget {
  const _MapEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.place_outlined, size: 44),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _MapSettingsTitle extends StatelessWidget {
  const _MapSettingsTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w900),
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
              label: 'Percurso pausado',
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

class _NavigationBanner extends StatelessWidget {
  const _NavigationBanner({
    required this.target,
    required this.distanceMeters,
    required this.bearingDegrees,
    required this.onStop,
  });

  final MapNavigationTarget target;
  final double? distanceMeters;
  final double? bearingDegrees;
  final VoidCallback onStop;

  String _distance(double? meters) {
    if (meters == null) return '--';
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _bearing(double? degrees) {
    if (degrees == null || !degrees.isFinite) return '--';
    const labels = <String>['N', 'NE', 'L', 'SE', 'S', 'SO', 'O', 'NO'];
    final normalized = ((degrees % 360) + 360) % 360;
    final index = ((normalized + 22.5) ~/ 45) % 8;
    return '${labels[index]} ${normalized.toStringAsFixed(0)}°';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Material(
        elevation: 7,
        color: scheme.tertiaryContainer.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.navigation_rounded,
                size: 20,
                color: scheme.onTertiaryContainer,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      target.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onTertiaryContainer,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${_distance(distanceMeters)} · ${_bearing(bearingDegrees)} · direção direta',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onTertiaryContainer,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Parar navegação',
                onPressed: onStop,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteButtonBar extends StatelessWidget {
  const _RouteButtonBar({
    required this.recording,
    required this.paused,
    required this.hasRoute,
    required this.onToggleRecording,
    required this.onTogglePause,
    required this.onExport,
  });

  final bool recording;
  final bool paused;
  final bool hasRoute;
  final VoidCallback? onToggleRecording;
  final VoidCallback? onTogglePause;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: Center(
        child: Material(
          elevation: 8,
          color: scheme.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(25),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (recording)
                  IconButton(
                    tooltip: paused ? 'Continuar percurso' : 'Pausar percurso',
                    onPressed: onTogglePause,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    ),
                  ),
                FilledButton.icon(
                  onPressed: onToggleRecording,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    backgroundColor: recording ? scheme.error : null,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: Icon(
                    recording ? Icons.stop_rounded : Icons.fiber_manual_record_rounded,
                    size: 19,
                  ),
                  label: Text(recording ? 'Encerrar percurso' : 'Gravar percurso'),
                ),
                if (hasRoute)
                  IconButton(
                    tooltip: 'Exportar GPX',
                    onPressed: onExport,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.file_upload_outlined),
                  ),
              ],
            ),
          ),
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

