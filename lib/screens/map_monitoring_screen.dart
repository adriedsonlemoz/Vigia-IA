import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_mbtiles/flutter_map_mbtiles.dart';
import 'package:latlong2/latlong.dart';

import '../controllers/secondary_camera_controller.dart';
import '../models/camera_endpoint.dart';
import '../models/map_navigation_target.dart';
import '../models/map_route_point.dart';
import '../models/offline_map_package.dart';
import '../models/route_explorer_models.dart';
import '../models/video_source_config.dart';
import '../services/camera_registry_service.dart';
import '../services/location_tracking_service.dart';
import '../services/map_camera_overlay_settings_service.dart';
import '../services/map_gps_filter.dart';
import '../services/map_route_service.dart';
import '../services/map_ux_policy.dart';
import '../services/map_view_policy.dart';
import '../services/map_view_settings_service.dart';
import '../services/native_platform_service.dart';
import '../services/offline_map_service.dart';
import '../services/route_explorer_service.dart';
import '../services/system_ui_service.dart';
import '../widgets/offline_map_manager_sheet.dart';

enum _MapPoiQuickFilter { all, fuel, food, health, water, other }

enum _MapQuickView { near, region, route }

enum _CameraPipMenuAction { source, size, minimize, hide }

class MapMonitoringScreen extends StatefulWidget {
  const MapMonitoringScreen({
    super.key,
    this.cameraPreviewBuilder,
    this.cameraAspectRatio,
    this.cameraListenable,
    this.cameraAspectRatioProvider,
    this.externalCameraSourceProvider,
    this.secondaryCameraPreviewBuilder,
    this.secondaryCameraListenable,
    this.secondaryCameraAspectRatioProvider,
    this.initialPointOfInterest,
  });

  final WidgetBuilder? cameraPreviewBuilder;
  final double? cameraAspectRatio;
  final Listenable? cameraListenable;
  final double? Function()? cameraAspectRatioProvider;
  final VideoSourceConfig? Function(bool secondary)? externalCameraSourceProvider;
  final WidgetBuilder? secondaryCameraPreviewBuilder;
  final Listenable? secondaryCameraListenable;
  final double? Function()? secondaryCameraAspectRatioProvider;
  final RouteExplorerResult? initialPointOfInterest;

  @override
  State<MapMonitoringScreen> createState() => _MapMonitoringScreenState();
}

class _MapMonitoringScreenState extends State<MapMonitoringScreen>
    with WidgetsBindingObserver {
  final MapController _mapController = MapController();
  final LocationTrackingService _location = LocationTrackingService.instance;
  final OfflineMapService _offlineMaps = OfflineMapService.instance;
  final MapRouteService _routeState = MapRouteService.instance;
  final NativePlatformService _native = NativePlatformService.instance;
  final RouteExplorerService _routeExplorer = RouteExplorerService.instance;
  final MapViewSettingsService _mapViewSettings = MapViewSettingsService.instance;
  final CameraRegistryService _cameraRegistry = CameraRegistryService.instance;
  final MapCameraOverlaySettingsService _cameraOverlaySettings =
      MapCameraOverlaySettingsService.instance;

  SecondaryCameraController? _primaryMapCamera;
  SecondaryCameraController? _secondaryMapCamera;
  bool _primaryUsesExternal = false;
  bool _secondaryUsesExternal = false;
  MapCameraSlotLayout _primaryCameraLayout = const MapCameraSlotLayout(yFraction: 0.20);
  MapCameraSlotLayout _secondaryCameraLayout = const MapCameraSlotLayout(
    yFraction: 0.48,
  );
  bool _appActive = true;

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
    WidgetsBinding.instance.addObserver(this);
    _primaryUsesExternal = widget.cameraPreviewBuilder != null;
    _secondaryUsesExternal = widget.secondaryCameraPreviewBuilder != null;
    _offlineMaps.addListener(_onOfflineMapsChanged);
    _routeState.addListener(_onRouteStateChanged);
    _routeExplorer.addListener(_onRouteExplorerChanged);
    _selectedPoiId = widget.initialPointOfInterest?.id;
    unawaited(SystemUiService.edgeToEdge());
    unawaited(_initializeOfflineMaps());
    unawaited(_initializeCameraOverlays());
    unawaited(_initialize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _primaryMapCamera?.dispose();
    _secondaryMapCamera?.dispose();
    _routeState.releaseLocationConsumer(this);
    _offlineMaps.removeListener(_onOfflineMapsChanged);
    _routeState.removeListener(_onRouteStateChanged);
    _routeExplorer.removeListener(_onRouteExplorerChanged);
    _offlineTileProvider?.dispose();
    _mapController.dispose();
    super.dispose();
  }

  static const String _mapLocalBackCameraId = '__map_local_back__';

  Future<void> _initializeCameraOverlays() async {
    await Future.wait<void>([
      _cameraOverlaySettings.initialize(),
      _cameraRegistry.initialize(),
    ]);
    if (!mounted) return;
    setState(() {
      _primaryCameraLayout = _cameraOverlaySettings.primary;
      _secondaryCameraLayout = _cameraOverlaySettings.secondary;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    _appActive = active;
    if (active) {
      unawaited(_resumeVisibleInternalCameras());
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(_primaryMapCamera?.suspend());
      unawaited(_secondaryMapCamera?.suspend());
    }
  }

  Future<void> _resumeVisibleInternalCameras() async {
    if (!_appActive || !_camerasVisible) return;
    if (!_primaryUsesExternal &&
        !_primaryCameraLayout.hidden &&
        !_primaryCameraLayout.minimized) {
      await _primaryMapCamera?.resume();
    }
    if (!_secondaryUsesExternal &&
        !_secondaryCameraLayout.hidden &&
        !_secondaryCameraLayout.minimized) {
      await _secondaryMapCamera?.resume();
    }
  }

  VideoSourceConfig _sourceForEndpoint(CameraEndpoint camera) =>
      switch (camera.type) {
        CameraEndpointType.local => VideoSourceConfig(
            type: VideoSourceType.localCamera,
            displayName: camera.name,
            cameraId: camera.id,
          ),
        CameraEndpointType.rtsp => VideoSourceConfig(
            type: VideoSourceType.rtsp,
            rtspUrl: camera.address,
            displayName: camera.name,
            cameraId: camera.id,
          ),
        CameraEndpointType.remotePhone => VideoSourceConfig(
            type: VideoSourceType.remotePhone,
            remoteBaseUrl: camera.address,
            remoteAccessKey: camera.accessKey,
            displayName: camera.name,
            cameraId: camera.id,
          ),
        CameraEndpointType.esp32 => VideoSourceConfig(
            type: VideoSourceType.esp32,
            remoteBaseUrl: camera.address,
            remoteAccessKey: camera.accessKey,
            displayName: camera.name,
            cameraId: camera.id,
          ),
      };

  VideoSourceConfig get _localBackSource => const VideoSourceConfig(
        type: VideoSourceType.localCamera,
        displayName: 'Traseira / local',
        cameraId: _mapLocalBackCameraId,
        analysisInterval: Duration(milliseconds: 800),
      );

  VideoSourceConfig get _frontCameraSource => const VideoSourceConfig(
        type: VideoSourceType.localCamera,
        displayName: 'Câmera frontal',
        cameraId: frontCameraTestId,
        analysisInterval: Duration(milliseconds: 800),
      );

  bool _sameCameraSource(VideoSourceConfig? first, VideoSourceConfig? second) {
    if (first == null || second == null || first.type != second.type) {
      return false;
    }
    if (first.type == VideoSourceType.localCamera) {
      if (first.isFrontCameraTest || second.isFrontCameraTest) {
        return first.isFrontCameraTest && second.isFrontCameraTest;
      }
      return true;
    }
    if (first.cameraId != null && second.cameraId != null) {
      return first.cameraId == second.cameraId;
    }
    return switch (first.type) {
      VideoSourceType.localCamera => true,
      VideoSourceType.rtsp => first.rtspUrl == second.rtspUrl,
      VideoSourceType.remotePhone => first.remoteBaseUrl == second.remoteBaseUrl,
      VideoSourceType.esp32 => first.remoteBaseUrl == second.remoteBaseUrl,
    };
  }

  VideoSourceConfig? _activeCameraConfig(bool secondary) {
    if (secondary) {
      return _secondaryUsesExternal
          ? widget.externalCameraSourceProvider?.call(true)
          : _secondaryMapCamera?.sourceConfig;
    }
    return _primaryUsesExternal
        ? widget.externalCameraSourceProvider?.call(false)
        : _primaryMapCamera?.sourceConfig;
  }

  String _activeCameraLabel(bool secondary) {
    if (secondary) {
      if (_secondaryUsesExternal) {
        return widget.externalCameraSourceProvider?.call(true)?.displayName ??
            'Câmera 2 do Monitor';
      }
      return _secondaryMapCamera?.displayName ?? 'Câmera 2';
    }
    if (_primaryUsesExternal) {
      return widget.externalCameraSourceProvider?.call(false)?.displayName ??
          'Câmera do Monitor';
    }
    return _primaryMapCamera?.displayName ?? 'Câmera 1';
  }

  bool _slotHasCamera(bool secondary) {
    if (secondary) {
      return (_secondaryUsesExternal &&
              widget.secondaryCameraPreviewBuilder != null) ||
          _secondaryMapCamera != null;
    }
    return (_primaryUsesExternal && widget.cameraPreviewBuilder != null) ||
        _primaryMapCamera != null;
  }

  Future<bool> _ensureCameraPermission(VideoSourceConfig source) async {
    if (source.type != VideoSourceType.localCamera) return true;
    final granted = await _native.requestCameraPermission();
    if (!mounted) return false;
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permita a câmera para usar esta fonte.')),
      );
    }
    return granted;
  }

  Future<void> _replaceMapCamera(
    bool secondary,
    VideoSourceConfig? source, {
    bool useExternal = false,
  }) async {
    if (source != null && !useExternal && !await _ensureCameraPermission(source)) {
      return;
    }
    final other = _activeCameraConfig(!secondary);
    if (source != null && _sameCameraSource(source, other)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Essa fonte já está sendo exibida no outro PiP.')),
      );
      return;
    }

    final previous = secondary ? _secondaryMapCamera : _primaryMapCamera;
    await previous?.suspend();
    previous?.dispose();
    final next = source == null || useExternal
        ? null
        : SecondaryCameraController(sourceConfig: source);
    if (secondary) {
      _secondaryMapCamera = next;
      _secondaryUsesExternal = useExternal;
      _secondaryCameraOffset = null;
      _secondaryCameraLayout = _secondaryCameraLayout.copyWith(
        hidden: source == null && !useExternal,
        minimized: false,
      );
      await _cameraOverlaySettings.saveSecondary(_secondaryCameraLayout);
    } else {
      _primaryMapCamera = next;
      _primaryUsesExternal = useExternal;
      _primaryCameraOffset = null;
      _primaryCameraLayout = _primaryCameraLayout.copyWith(
        hidden: source == null && !useExternal,
        minimized: false,
      );
      await _cameraOverlaySettings.savePrimary(_primaryCameraLayout);
    }
    if (mounted) setState(() {});
    if (next != null && _appActive && _camerasVisible) {
      await next.start();
    }
  }

  Future<void> _setCameraSlotHidden(bool secondary, bool hidden) async {
    if (secondary) {
      _secondaryCameraLayout = _secondaryCameraLayout.copyWith(hidden: hidden);
      await _cameraOverlaySettings.saveSecondary(_secondaryCameraLayout);
      if (!_secondaryUsesExternal) {
        if (hidden) {
          await _secondaryMapCamera?.suspend();
        } else if (!_secondaryCameraLayout.minimized && _appActive) {
          await _secondaryMapCamera?.resume();
        }
      }
    } else {
      _primaryCameraLayout = _primaryCameraLayout.copyWith(hidden: hidden);
      await _cameraOverlaySettings.savePrimary(_primaryCameraLayout);
      if (!_primaryUsesExternal) {
        if (hidden) {
          await _primaryMapCamera?.suspend();
        } else if (!_primaryCameraLayout.minimized && _appActive) {
          await _primaryMapCamera?.resume();
        }
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleCameraSlotMinimized(bool secondary) async {
    final layout = secondary ? _secondaryCameraLayout : _primaryCameraLayout;
    final minimized = !layout.minimized;
    if (secondary) {
      _secondaryCameraLayout = layout.copyWith(minimized: minimized, hidden: false);
      await _cameraOverlaySettings.saveSecondary(_secondaryCameraLayout);
      if (!_secondaryUsesExternal) {
        if (minimized) {
          await _secondaryMapCamera?.suspend();
        } else if (_appActive && _camerasVisible) {
          await _secondaryMapCamera?.resume();
        }
      }
    } else {
      _primaryCameraLayout = layout.copyWith(minimized: minimized, hidden: false);
      await _cameraOverlaySettings.savePrimary(_primaryCameraLayout);
      if (!_primaryUsesExternal) {
        if (minimized) {
          await _primaryMapCamera?.suspend();
        } else if (_appActive && _camerasVisible) {
          await _primaryMapCamera?.resume();
        }
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _cycleCameraSlotSize(bool secondary) async {
    final layout = secondary ? _secondaryCameraLayout : _primaryCameraLayout;
    final current = layout.sizeScale;
    final next = current < 0.9 ? 1.0 : current < 1.15 ? 1.25 : 0.78;
    final updated = layout.copyWith(sizeScale: next, minimized: false);
    if (secondary) {
      _secondaryCameraLayout = updated;
      _secondaryCameraOffset = null;
      await _cameraOverlaySettings.saveSecondary(updated);
    } else {
      _primaryCameraLayout = updated;
      _primaryCameraOffset = null;
      await _cameraOverlaySettings.savePrimary(updated);
    }
    if (mounted) setState(() {});
  }

  Future<void> _persistCameraPosition(
    bool secondary,
    Offset position, {
    required double minX,
    required double minY,
    required double maxX,
    required double maxY,
  }) async {
    final x = MapUxPolicy.fractionForPosition(
      position: position.dx,
      min: minX,
      max: maxX,
    );
    final y = MapUxPolicy.fractionForPosition(
      position: position.dy,
      min: minY,
      max: maxY,
    );
    if (secondary) {
      _secondaryCameraLayout = _secondaryCameraLayout.copyWith(
        xFraction: x,
        yFraction: y,
      );
      await _cameraOverlaySettings.saveSecondary(_secondaryCameraLayout);
    } else {
      _primaryCameraLayout = _primaryCameraLayout.copyWith(
        xFraction: x,
        yFraction: y,
      );
      await _cameraOverlaySettings.savePrimary(_primaryCameraLayout);
    }
  }

  Future<void> _showCameraSourcePicker(bool secondary) async {
    await _cameraRegistry.initialize();
    if (!mounted) return;
    final options = <VideoSourceConfig>[
      _localBackSource,
      _frontCameraSource,
      ..._cameraRegistry.items
          .where(
            (camera) =>
                camera.enabled &&
                (camera.type != CameraEndpointType.esp32 ||
                    camera.esp32CameraEnabled),
          )
          .map(_sourceForEndpoint),
    ];
    final selectedKey = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 18),
          children: [
            ListTile(
              title: Text(secondary ? 'Fonte da câmera 2' : 'Fonte da câmera 1'),
              subtitle: const Text('A IA do Monitor não é duplicada pelas câmeras abertas só para o mapa.'),
            ),
            if ((!secondary && widget.cameraPreviewBuilder != null) ||
                (secondary && widget.secondaryCameraPreviewBuilder != null))
              ListTile(
                leading: const Icon(Icons.monitor_rounded),
                title: Text(secondary ? 'Câmera 2 do Monitor' : 'Câmera atual do Monitor'),
                subtitle: const Text('Reutiliza a visualização já aberta pelo Monitor.'),
                onTap: () => Navigator.pop(sheetContext, '__external__'),
              ),
            for (var index = 0; index < options.length; index++)
              ListTile(
                leading: Icon(_videoSourceIcon(options[index])),
                title: Text(options[index].displayName ?? 'Câmera'),
                subtitle: Text(_videoSourceDescription(options[index])),
                trailing: _sameCameraSource(
                  _activeCameraConfig(secondary),
                  options[index],
                )
                    ? const Icon(Icons.check_circle_rounded)
                    : null,
                onTap: () => Navigator.pop(sheetContext, 'source:$index'),
              ),
            ListTile(
              leading: const Icon(Icons.videocam_off_outlined),
              title: const Text('Remover deste PiP'),
              onTap: () => Navigator.pop(sheetContext, '__none__'),
            ),
          ],
        ),
      ),
    );
    if (selectedKey == null || !mounted) return;
    if (selectedKey == '__external__') {
      await _replaceMapCamera(
        secondary,
        widget.externalCameraSourceProvider?.call(secondary),
        useExternal: true,
      );
      return;
    }
    if (selectedKey == '__none__') {
      await _replaceMapCamera(secondary, null);
      return;
    }
    if (!selectedKey.startsWith('source:')) return;
    final index = int.tryParse(selectedKey.substring(7));
    if (index == null || index < 0 || index >= options.length) return;
    await _replaceMapCamera(secondary, options[index]);
  }

  IconData _videoSourceIcon(VideoSourceConfig source) => switch (source.type) {
        VideoSourceType.localCamera => source.isFrontCameraTest
            ? Icons.face_retouching_natural_outlined
            : Icons.camera_alt_outlined,
        VideoSourceType.rtsp => Icons.router_outlined,
        VideoSourceType.remotePhone => Icons.phone_android_rounded,
        VideoSourceType.esp32 => Icons.memory_rounded,
      };

  String _videoSourceDescription(VideoSourceConfig source) => switch (source.type) {
        VideoSourceType.localCamera => source.isFrontCameraTest
            ? 'Frontal deste aparelho'
            : 'Traseira/local deste aparelho',
        VideoSourceType.rtsp => 'Câmera de rede RTSP',
        VideoSourceType.remotePhone => 'Celular remoto',
        VideoSourceType.esp32 => 'Câmera do ESP32',
      };

  Future<void> _showCameraManager() async {
    await _cameraRegistry.initialize();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          Widget slotTile(bool secondary) {
            final hasCamera = _slotHasCamera(secondary);
            final layout = secondary ? _secondaryCameraLayout : _primaryCameraLayout;
            return Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(secondary ? Icons.filter_2_rounded : Icons.filter_1_rounded),
                    title: Text(hasCamera ? _activeCameraLabel(secondary) : (secondary ? 'Câmera 2' : 'Câmera 1')),
                    subtitle: Text(hasCamera
                        ? (layout.hidden
                            ? 'Oculta'
                            : layout.minimized
                                ? 'Minimizada · fonte suspensa quando possível'
                                : 'Visível sobre o mapa')
                        : 'Nenhuma fonte selecionada'),
                    trailing: IconButton(
                      tooltip: 'Trocar fonte',
                      icon: const Icon(Icons.cameraswitch_outlined),
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        unawaited(_showCameraSourcePicker(secondary));
                      },
                    ),
                  ),
                  if (hasCamera)
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      alignment: WrapAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            await _setCameraSlotHidden(secondary, !layout.hidden);
                            setSheetState(() {});
                          },
                          icon: Icon(layout.hidden ? Icons.visibility_rounded : Icons.visibility_off_outlined),
                          label: Text(layout.hidden ? 'Mostrar' : 'Ocultar'),
                        ),
                        TextButton.icon(
                          onPressed: layout.hidden
                              ? null
                              : () async {
                                  await _toggleCameraSlotMinimized(secondary);
                                  setSheetState(() {});
                                },
                          icon: Icon(layout.minimized ? Icons.open_in_full_rounded : Icons.minimize_rounded),
                          label: Text(layout.minimized ? 'Expandir' : 'Minimizar'),
                        ),
                        TextButton.icon(
                          onPressed: layout.hidden
                              ? null
                              : () async {
                                  await _cycleCameraSlotSize(secondary);
                                  setSheetState(() {});
                                },
                          icon: const Icon(Icons.aspect_ratio_rounded),
                          label: const Text('Tamanho'),
                        ),
                      ],
                    ),
                  const SizedBox(height: 6),
                ],
              ),
            );
          }

          return SafeArea(
            child: FractionallySizedBox(
              heightFactor: 0.70,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                children: [
                  const Text(
                    'Câmeras sobre o mapa',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Escolha fontes, oculte ou minimize cada PiP. Arrastar encaixa no canto mais próximo e posição/tamanho ficam salvos.',
                  ),
                  const SizedBox(height: 12),
                  slotTile(false),
                  slotTile(true),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: _camerasVisible,
                    title: const Text('Mostrar PiPs no mapa'),
                    subtitle: const Text('Desligar pausa apenas as fontes abertas pelo próprio mapa.'),
                    onChanged: (value) async {
                      setState(() => _camerasVisible = value);
                      setSheetState(() {});
                      if (value) {
                        await _resumeVisibleInternalCameras();
                      } else {
                        await _primaryMapCamera?.suspend();
                        await _secondaryMapCamera?.suspend();
                      }
                    },
                  ),
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await _cameraOverlaySettings.resetLayout();
                      if (!mounted) return;
                      setState(() {
                        _primaryCameraLayout = _cameraOverlaySettings.primary;
                        _secondaryCameraLayout = _cameraOverlaySettings.secondary;
                        _primaryCameraOffset = null;
                        _secondaryCameraOffset = null;
                      });
                      setSheetState(() {});
                      await _resumeVisibleInternalCameras();
                    },
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Restaurar posição e tamanho dos PiPs'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
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
    await _routeState.acquireLocationConsumer(
      this,
      requestPermission: true,
    );
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

  List<List<LatLng>> _routeSegmentsForDisplay() {
    const maximumDisplayPoints = 2200;
    final segments = _routeState.routeSegments;
    final totalPoints = segments.fold<int>(0, (sum, item) => sum + item.length);
    final stride = totalPoints <= maximumDisplayPoints
        ? 1
        : (totalPoints / maximumDisplayPoints).ceil();
    return segments
        .map((segment) {
          if (segment.length < 2) return const <LatLng>[];
          final points = <LatLng>[];
          for (var index = 0; index < segment.length; index += stride) {
            final point = segment[index];
            points.add(LatLng(point.latitude, point.longitude));
          }
          final last = segment.last;
          final lastLatLng = LatLng(last.latitude, last.longitude);
          if (points.isEmpty ||
              points.last.latitude != lastLatLng.latitude ||
              points.last.longitude != lastLatLng.longitude) {
            points.add(lastLatLng);
          }
          return points;
        })
        .where((segment) => segment.length >= 2)
        .toList(growable: false);
  }

  String _formatDistance() {
    final distanceMeters = _routeState.distanceMeters;
    if (distanceMeters < 1000) return '${distanceMeters.toStringAsFixed(0)} m';
    return '${(distanceMeters / 1000).toStringAsFixed(2)} km';
  }

  bool get _hasCameraOverlay => _slotHasCamera(false) || _slotHasCamera(true);

  WidgetBuilder? _cameraPreviewBuilderFor(bool secondary) {
    if (secondary) {
      if (_secondaryUsesExternal) return widget.secondaryCameraPreviewBuilder;
      final controller = _secondaryMapCamera;
      return controller == null ? null : (_) => controller.buildPreview();
    }
    if (_primaryUsesExternal) return widget.cameraPreviewBuilder;
    final controller = _primaryMapCamera;
    return controller == null ? null : (_) => controller.buildPreview();
  }

  Listenable? _cameraListenableFor(bool secondary) {
    if (secondary) {
      return _secondaryUsesExternal
          ? widget.secondaryCameraListenable
          : _secondaryMapCamera;
    }
    return _primaryUsesExternal ? widget.cameraListenable : _primaryMapCamera;
  }

  double? Function()? _cameraAspectRatioProviderFor(bool secondary) {
    if (secondary) {
      if (_secondaryUsesExternal) return widget.secondaryCameraAspectRatioProvider;
      final controller = _secondaryMapCamera;
      return controller == null ? null : () => controller.previewAspectRatio;
    }
    if (_primaryUsesExternal) return widget.cameraAspectRatioProvider;
    final controller = _primaryMapCamera;
    return controller == null ? null : () => controller.previewAspectRatio;
  }

  double? _cameraFallbackAspectRatioFor(bool secondary) {
    if (secondary) return 16 / 9;
    return _primaryUsesExternal ? widget.cameraAspectRatio : 16 / 9;
  }

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

  RouteExplorerResult? get _selectedPoi {
    final id = _selectedPoiId;
    if (id == null) return null;
    for (final item in _routeExplorer.results) {
      if (item.id == id) return item;
    }
    for (final item in _routeExplorer.offlineResults) {
      if (item.id == id) return item;
    }
    return null;
  }

  IconData _mapStyleIcon(MapStylePreset style) => switch (style) {
        MapStylePreset.standard => Icons.map_outlined,
        MapStylePreset.bikeTravel => Icons.directions_bike_rounded,
        MapStylePreset.terrain => Icons.terrain_rounded,
        MapStylePreset.topographic => Icons.landscape_rounded,
        MapStylePreset.satellite => Icons.satellite_alt_rounded,
      };

  _OnlineMapLayerSpec get _onlineMapLayerSpec {
    final selected = _mapViewSettings.stylePreset;
    switch (selected) {
      case MapStylePreset.standard:
        return const _OnlineMapLayerSpec(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          maxNativeZoom: 19,
          attribution: '© OpenStreetMap contributors',
        );
      case MapStylePreset.bikeTravel:
        final stadia = _offlineMaps.stadiaRasterTileTemplate('outdoors');
        if (stadia != null) {
          return _OnlineMapLayerSpec(
            urlTemplate: stadia,
            maxNativeZoom: 20,
            attribution: '© Stadia Maps · OpenMapTiles · OpenStreetMap',
          );
        }
        return const _OnlineMapLayerSpec(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          maxNativeZoom: 19,
          attribution: 'Bike/Viagem · © OpenStreetMap contributors',
        );
      case MapStylePreset.terrain:
        final stadia = _offlineMaps.stadiaRasterTileTemplate('stamen_terrain');
        if (stadia != null) {
          return _OnlineMapLayerSpec(
            urlTemplate: stadia,
            maxNativeZoom: 20,
            attribution:
                '© Stadia Maps · Stamen Design · OpenMapTiles · OpenStreetMap',
          );
        }
        return const _OnlineMapLayerSpec(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          maxNativeZoom: 19,
          attribution: 'Terreno indisponível · © OpenStreetMap contributors',
        );
      case MapStylePreset.topographic:
        return const _OnlineMapLayerSpec(
          urlTemplate: 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
          maxNativeZoom: 17,
          subdomains: <String>['a', 'b', 'c'],
          attribution:
              '© OpenStreetMap contributors, SRTM · © OpenTopoMap (CC-BY-SA)',
        );
      case MapStylePreset.satellite:
        final stadia = _offlineMaps.stadiaRasterTileTemplate(
          'alidade_satellite',
          extension: 'jpg',
        );
        if (stadia != null) {
          return _OnlineMapLayerSpec(
            urlTemplate: stadia,
            maxNativeZoom: 20,
            attribution:
                '© Stadia Maps · imagery providers · OpenMapTiles · OpenStreetMap',
          );
        }
        return const _OnlineMapLayerSpec(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          maxNativeZoom: 19,
          attribution: 'Satélite indisponível · © OpenStreetMap contributors',
        );
    }
  }

  Future<void> _showLayerPicker() async {
    await _offlineMaps.initialize();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final selected = _mapViewSettings.stylePreset;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Camadas e tipo do mapa',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 6),
                for (final style in MapStylePreset.values)
                  ListTile(
                    leading: Icon(_mapStyleIcon(style)),
                    title: Text(style.label),
                    subtitle: Text(
                      style == MapStylePreset.bikeTravel &&
                              !_offlineMaps.hasStadiaApiKey
                          ? '${style.description} Usando OSM até configurar Stadia.'
                          : style.description,
                    ),
                    trailing: style.needsStadiaKey &&
                            !_offlineMaps.hasStadiaApiKey
                        ? const Icon(Icons.lock_outline_rounded)
                        : selected == style
                            ? const Icon(Icons.check_circle_rounded)
                            : null,
                    selected: selected == style,
                    enabled: !style.needsStadiaKey ||
                        _offlineMaps.hasStadiaApiKey,
                    onTap: !style.needsStadiaKey ||
                            _offlineMaps.hasStadiaApiKey
                        ? () {
                            Navigator.of(sheetContext).pop();
                            unawaited(_selectMapStyle(style));
                          }
                        : null,
                  ),
                if (!_offlineMaps.hasStadiaApiKey)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        unawaited(_openOfflineMaps());
                      },
                      icon: const Icon(Icons.key_rounded),
                      label: const Text('Configurar Stadia para Terreno/Satélite'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _selectMapStyle(MapStylePreset style) async {
    if (style.needsStadiaKey && !_offlineMaps.hasStadiaApiKey) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${style.label} precisa da chave Stadia configurada.')),
      );
      return;
    }
    await _mapViewSettings.setStylePreset(style);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _showMapOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.place_rounded),
                title: const Text('Próximos pontos'),
                subtitle: const Text('Postos, comida, saúde, água e outros.'),
                trailing: _routeExplorer.results.isEmpty
                    ? null
                    : Text('${_routeExplorer.results.length}'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_showNearbyPoints());
                },
              ),
              ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: const Text('Pacotes de pontos offline'),
                subtitle: Text(
                  _routeExplorer.offlinePackages.isEmpty
                      ? 'Nenhuma região salva.'
                      : '${_routeExplorer.offlinePackages.length} região(ões) salva(s).',
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_showOfflinePoiPackages());
                },
              ),
              ListTile(
                leading: const Icon(Icons.download_for_offline_outlined),
                title: const Text('Mapas offline'),
                subtitle: const Text('Gerenciar MBTiles e downloads de mapa.'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_openOfflineMaps());
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_rounded),
                title: const Text('Configurações'),
                subtitle: const Text('Busca, categorias e alertas.'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_showMapSettings());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _promptSaveOfflinePoiPackage() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Salvar região offline'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 48,
          decoration: const InputDecoration(
            labelText: 'Nome do pacote',
            hintText: 'Ex.: Serra do Cipó ou BH → Ouro Preto',
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null) return;
    await _routeExplorer.saveCurrentResultsOffline(name: name);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_routeExplorer.statusMessage ?? 'Pacote salvo.')),
    );
  }

  String _formatOfflinePackageDate(DateTime value) {
    final local = value.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
  }

  Future<void> _updateOfflinePoiPackage(OfflinePoiPackage package) async {
    await _routeExplorer.updateOfflinePackage(package.id);
    if (!mounted) return;
    final message = _routeExplorer.statusMessage ?? _routeExplorer.error;
    if (message == null || message.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _confirmDeleteOfflinePoiPackage(
    OfflinePoiPackage package,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir pacote offline?'),
        content: Text(
          '“${package.name}” e seus ${package.itemCount} pontos serão removidos deste aparelho.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _routeExplorer.removeOfflinePackage(package.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_routeExplorer.statusMessage ?? 'Pacote removido.'),
      ),
    );
  }

  Future<void> _showOfflinePoiPackages() async {
    await _routeExplorer.initialize();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.72,
          child: ListenableBuilder(
            listenable: _routeExplorer,
            builder: (context, _) {
              final packages = _routeExplorer.offlinePackages;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Pacotes de pontos offline',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                          ),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _routeExplorer.results.isEmpty
                              ? null
                              : () {
                                  Navigator.of(sheetContext).pop();
                                  unawaited(_promptSaveOfflinePoiPackage());
                                },
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Salvar atual'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: packages.isEmpty
                        ? const _MapEmptyState(
                            message:
                                'Nenhuma região offline salva. Faça uma busca em Próximos pontos e salve um pacote.',
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                            itemCount: packages.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final package = packages[index];
                              final active = package.id ==
                                  _routeExplorer.activeOfflinePackageId;
                              return Card(
                                margin: EdgeInsets.zero,
                                child: ListTile(
                                  leading: CircleAvatar(
                                    child: Icon(
                                      active
                                          ? Icons.offline_pin_rounded
                                          : Icons.inventory_2_outlined,
                                    ),
                                  ),
                                  title: Text(package.name),
                                  subtitle: Text(
                                    '${package.itemCount} pontos · raio ${package.searchRadiusKm} km · ${_formatOfflinePackageDate(package.updatedAt)}',
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'activate') {
                                        unawaited(
                                          _routeExplorer.activateOfflinePackage(package.id),
                                        );
                                      } else if (value == 'update') {
                                        unawaited(
                                          _updateOfflinePoiPackage(package),
                                        );
                                      } else if (value == 'delete') {
                                        unawaited(
                                          _confirmDeleteOfflinePoiPackage(package),
                                        );
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(
                                        value: 'activate',
                                        child: Text('Usar este pacote'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'update',
                                        child: Text('Atualizar pela internet'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Excluir'),
                                      ),
                                    ],
                                  ),
                                  onTap: () => unawaited(
                                    _routeExplorer.activateOfflinePackage(package.id),
                                  ),
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
    );
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
                              onPressed: service.loading || service.results.isEmpty
                                  ? null
                                  : () {
                                      Navigator.of(sheetContext).pop();
                                      unawaited(_promptSaveOfflinePoiPackage());
                                    },
                              icon: const Icon(Icons.inventory_2_outlined),
                              label: const Text('Salvar pacote'),
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
                    icon: const Icon(Icons.download_for_offline_outlined),
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
                    'A busca “No caminho” pode se atualizar durante o deslocamento mesmo sem gravar percurso: considera distância, tempo em movimento, mudança de direção e saída da área pesquisada. Se a rede falhar, usa o pacote offline mais adequado.',
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
    final routeSegments = _routeSegmentsForDisplay();
    final visiblePois = _visiblePois;
    final selectedPoi = _selectedPoi;
    final onlineLayer = _onlineMapLayerSpec;
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
          final horizontalControls = MapUxPolicy.compactLandscape(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
          );
          final compactHud = MapUxPolicy.compactHud(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
          );
          final telemetryTop = topInset + 46;
          final quickViewTop = topInset + (compactHud ? 82 : 87);
          final controlDockTop = topInset + (compactHud ? 90 : 132);
          final attributionBottom = MapUxPolicy.attributionBottom(
            safeBottom: safePadding.bottom,
            hasSelectedPoi: selectedPoi != null,
            hasNavigation: navigationTarget != null,
          );
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
                      key: ValueKey<String>(
                        'online-${_mapViewSettings.stylePreset.name}',
                      ),
                      urlTemplate: onlineLayer.urlTemplate,
                      userAgentPackageName: 'com.vigiaia.app',
                      maxNativeZoom: onlineLayer.maxNativeZoom,
                      subdomains: onlineLayer.subdomains,
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
                              onTap: () => _focusPoi(item),
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
                right: compactHud ? 86 : null,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: (compactHud
                            ? math.max(96.0, constraints.maxWidth - 124)
                            : math.min(220.0, constraints.maxWidth - 180))
                        .toDouble(),
                  ),
                  child: _MapSourceChip(
                    mode: mode,
                    activePackage: activeOffline,
                    error: _offlineTileError,
                    styleLabel: _mapViewSettings.stylePreset.label,
                    compact: compactHud,
                    onTap: () => unawaited(_showLayerPicker()),
                  ),
                ),
              ),
              Positioned(
                top: topInset,
                right: 8,
                child: _GpsChip(point: current, compact: compactHud),
              ),
              Positioned(
                top: telemetryTop,
                left: 8,
                right: 58,
                child: _MapTelemetryStrip(
                  paused: _routeState.paused,
                  speedKmh: current?.speedKilometersPerHour ?? 0,
                  distance: _formatDistance(),
                  routeState: _routeState,
                  altitudeMeters: current?.altitudeMeters,
                  headingDegrees: current?.headingDegrees,
                  following: _followPosition,
                  onToggleFollow: current == null ? null : _toggleFollow,
                  compact: compactHud,
                ),
              ),
              Positioned(
                top: quickViewTop,
                left: 8,
                child: _MapQuickViewBar(
                  selected: _quickView,
                  routeAvailable:
                      _routeState.route.length >= 2 || navigationTarget != null,
                  onSelected: _selectQuickView,
                  compact: compactHud,
                ),
              ),
              if (outsideOfflineArea && mode != OfflineMapMode.online)
                Positioned(
                  top: quickViewTop + (compactHud ? 39 : 41),
                  left: 8,
                  child: _OfflineAreaWarning(
                    onTap: () => unawaited(_openOfflineMaps()),
                  ),
                ),
              Positioned(
                top: horizontalControls ? null : controlDockTop,
                right: 8,
                bottom: horizontalControls ? bottomInset + 58 : null,
                child: Flex(
                  direction:
                      horizontalControls ? Axis.horizontal : Axis.vertical,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MapZoomCluster(
                      horizontal: horizontalControls,
                      onZoomIn: () => _zoomBy(1),
                      onZoomOut: () => _zoomBy(-1),
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
                      tooltip: 'Câmeras sobre o mapa',
                      icon: _hasCameraOverlay
                          ? (_camerasVisible
                              ? Icons.videocam_rounded
                              : Icons.videocam_off_rounded)
                          : Icons.add_a_photo_outlined,
                      active: _hasCameraOverlay && _camerasVisible,
                      onPressed: () => unawaited(_showCameraManager()),
                    ),
                    _MapControlGap(horizontal: horizontalControls),
                    _MapControlButton(
                      tooltip: 'Opções do mapa',
                      icon: Icons.more_horiz_rounded,
                      badge: _routeExplorer.results.isEmpty
                          ? null
                          : '${_routeExplorer.results.length}',
                      active: offlineProvider != null ||
                          _routeExplorer.offlinePackages.isNotEmpty,
                      onPressed: () => unawaited(_showMapOptions()),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 8,
                bottom: attributionBottom,
                child: _MapAttribution(
                  text: mode == OfflineMapMode.offline
                      ? (activeOffline?.providerId == 'stadia-alidade-smooth'
                          ? '© Stadia Maps · OpenMapTiles · OpenStreetMap'
                          : 'Mapa offline · licença do pacote')
                      : onlineLayer.attribution,
                ),
              ),
              if (selectedPoi != null)
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: bottomInset + (navigationTarget == null ? 62 : 124),
                  child: _SelectedPoiCard(
                    item: selectedPoi,
                    distanceLabel:
                        _routeExplorer.formatDistance(selectedPoi.distanceMeters),
                    icon: _poiIcon(selectedPoi.category),
                    compact: compactHud,
                    onClose: () => setState(() => _selectedPoiId = null),
                    onDetails: () => unawaited(_showPoiDetails(selectedPoi)),
                    onNavigate: () => _navigateToPoi(selectedPoi),
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
              if (_camerasVisible &&
                  !_primaryCameraLayout.hidden &&
                  _cameraPreviewBuilderFor(false) != null)
                _buildCameraPip(
                  context,
                  constraints,
                  previewBuilder: _cameraPreviewBuilderFor(false)!,
                  listenable: _cameraListenableFor(false),
                  aspectRatioProvider: _cameraAspectRatioProviderFor(false),
                  fallbackAspectRatio: _cameraFallbackAspectRatioFor(false),
                  secondary: false,
                ),
              if (_camerasVisible &&
                  !_secondaryCameraLayout.hidden &&
                  _cameraPreviewBuilderFor(true) != null)
                _buildCameraPip(
                  context,
                  constraints,
                  previewBuilder: _cameraPreviewBuilderFor(true)!,
                  listenable: _cameraListenableFor(true),
                  aspectRatioProvider: _cameraAspectRatioProviderFor(true),
                  fallbackAspectRatio: _cameraFallbackAspectRatioFor(true),
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
      final layout = secondary ? _secondaryCameraLayout : _primaryCameraLayout;
      final requestedRatio =
          aspectRatioProvider?.call() ?? fallbackAspectRatio ?? (16 / 9);
      final aspectRatio = requestedRatio.clamp(0.50, 2.20).toDouble();
      final minimized = layout.minimized;
      late double width;
      late double height;
      if (minimized) {
        width = 154;
        height = 42;
      } else if (aspectRatio >= 1) {
        final baseWidth =
            (constraints.maxWidth * 0.29).clamp(126.0, 190.0).toDouble();
        width = (baseWidth * layout.sizeScale)
            .clamp(104.0, math.min(238.0, constraints.maxWidth * 0.52))
            .toDouble();
        height = (width / aspectRatio).clamp(70.0, 166.0).toDouble();
      } else {
        final baseHeight =
            (constraints.maxHeight * 0.22).clamp(118.0, 188.0).toDouble();
        height = (baseHeight * layout.sizeScale)
            .clamp(94.0, math.min(228.0, constraints.maxHeight * 0.42))
            .toDouble();
        width = (height * aspectRatio).clamp(76.0, 164.0).toDouble();
      }

      final safePadding = MediaQuery.paddingOf(context);
      const minX = 8.0;
      final minY = MapUxPolicy.cameraMinY(
        safeTop: safePadding.top,
        compactLandscape: _compactLandscape,
      );
      final bottomReserve = MapUxPolicy.cameraBottomReserve(
        safeBottom: safePadding.bottom,
        hasSelectedPoi: _selectedPoi != null,
        hasNavigation: _routeState.navigationTarget != null,
      );
      final availableHeight = math.max(
        minimized ? 42.0 : 70.0,
        constraints.maxHeight - minY - bottomReserve,
      ).toDouble();
      if (!minimized && height > availableHeight) {
        height = availableHeight;
        width = math.min(width, height * aspectRatio).toDouble();
      }
      final rightReserve = _compactLandscape ? 8.0 : 58.0;
      final maxX = math
          .max(
            minX,
            constraints.maxWidth - width - rightReserve,
          )
          .toDouble();
      final maxY = math
          .max(
            minY,
            constraints.maxHeight - height - bottomReserve,
          )
          .toDouble();
      final spanX = math.max(0.0, maxX - minX).toDouble();
      final spanY = math.max(0.0, maxY - minY).toDouble();
      final storedPosition = Offset(
        MapUxPolicy.positionForFraction(
          fraction: layout.xFraction,
          min: minX,
          max: maxX,
        ),
        MapUxPolicy.positionForFraction(
          fraction: layout.yFraction,
          min: minY,
          max: maxY,
        ),
      );
      final raw = secondary
          ? (_secondaryCameraOffset ?? storedPosition)
          : (_primaryCameraOffset ?? storedPosition);
      final position = Offset(
        raw.dx.clamp(minX, maxX).toDouble(),
        raw.dy.clamp(minY, maxY).toDouble(),
      );
      final label = _activeCameraLabel(secondary);

      Future<void> snapAndPersist() async {
        final current = secondary
            ? (_secondaryCameraOffset ?? position)
            : (_primaryCameraOffset ?? position);
        final snapped = Offset(
          current.dx <= minX + spanX / 2 ? minX : maxX,
          current.dy <= minY + spanY / 2 ? minY : maxY,
        );
        if (mounted) {
          setState(() {
            if (secondary) {
              _secondaryCameraOffset = snapped;
            } else {
              _primaryCameraOffset = snapped;
            }
          });
        }
        await _persistCameraPosition(
          secondary,
          snapped,
          minX: minX,
          minY: minY,
          maxX: maxX,
          maxY: maxY,
        );
      }

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
                next.dx.clamp(minX, maxX).toDouble(),
                next.dy.clamp(minY, maxY).toDouble(),
              );
              if (secondary) {
                _secondaryCameraOffset = updated;
              } else {
                _primaryCameraOffset = updated;
              }
            });
          },
          onPanEnd: (_) => unawaited(snapAndPersist()),
          child: Material(
            elevation: 10,
            color: Colors.black,
            borderRadius: BorderRadius.circular(minimized ? 22 : 16),
            clipBehavior: Clip.antiAlias,
            child: minimized
                ? Row(
                    children: [
                      const SizedBox(width: 8),
                      Icon(
                        secondary ? Icons.filter_2_rounded : Icons.videocam_rounded,
                        size: 17,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Expandir câmera',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
                        onPressed: () => unawaited(_toggleCameraSlotMinimized(secondary)),
                        icon: const Icon(Icons.open_in_full_rounded, size: 16, color: Colors.white),
                      ),
                    ],
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      RepaintBoundary(child: previewBuilder(context)),
                      Positioned(
                        left: 6,
                        top: 6,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.62),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: scheme.primary.withValues(alpha: 0.40),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.drag_indicator_rounded, size: 14, color: Colors.white),
                                const SizedBox(width: 3),
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: math.max(42.0, width - 50).toDouble(),
                                  ),
                                  child: Text(
                                    label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: _CameraPipMenuButton(
                          onSelected: (action) {
                            switch (action) {
                              case _CameraPipMenuAction.source:
                                unawaited(_showCameraSourcePicker(secondary));
                                break;
                              case _CameraPipMenuAction.size:
                                unawaited(_cycleCameraSlotSize(secondary));
                                break;
                              case _CameraPipMenuAction.minimize:
                                unawaited(_toggleCameraSlotMinimized(secondary));
                                break;
                              case _CameraPipMenuAction.hide:
                                unawaited(_setCameraSlotHidden(secondary, true));
                                break;
                            }
                          },
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
    final forever =
        availability == LocationTrackingAvailability.permissionDeniedForever;
    final disabled =
        availability == LocationTrackingAvailability.servicesDisabled;
    final title = disabled
        ? 'Localização do aparelho está desligada'
        : forever
            ? 'Permissão de localização bloqueada'
            : 'Permissão de localização necessária';
    final body = disabled
        ? 'Ative a localização do Android para mostrar sua posição e registrar o trajeto.'
        : forever
            ? 'Abra as configurações do Vigia IA e permita localização durante o uso.'
            : 'O GPS alimenta a mesma sessão de percurso do Monitor e do mapa completo; uma gravação ativa continua ao trocar de tela.';
    final scheme = Theme.of(context).colorScheme;
    final safePadding = MediaQuery.paddingOf(context);

    return Scaffold(
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scheme.surfaceContainerHighest,
                  scheme.surface,
                ],
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 88, 24, 72),
                child: Material(
                  elevation: 4,
                  color: scheme.surface.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_off_outlined,
                          size: 56,
                          color: scheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
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
                          icon: Icon(
                            disabled
                                ? Icons.location_searching_rounded
                                : Icons.settings_outlined,
                          ),
                          label: Text(
                            disabled
                                ? 'Ativar localização'
                                : forever
                                    ? 'Abrir configurações'
                                    : 'Permitir localização',
                          ),
                        ),
                        if (disabled || forever) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _initialize,
                            child: const Text('Verificar novamente'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: safePadding.top + 8,
            left: 8,
            child: _MapControlButton(
              tooltip: 'Voltar',
              icon: Icons.arrow_back_rounded,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          Positioned(
            top: safePadding.top + 8,
            right: 8,
            child: _MapControlButton(
              tooltip: 'Mapas offline',
              icon: Icons.download_for_offline_outlined,
              onPressed: () => unawaited(_openOfflineMaps()),
            ),
          ),
        ],
      ),
    );
  }

}

class _MapQuickViewBar extends StatelessWidget {
  const _MapQuickViewBar({
    required this.selected,
    required this.routeAvailable,
    required this.onSelected,
    this.compact = false,
  });

  final _MapQuickView? selected;
  final bool routeAvailable;
  final ValueChanged<_MapQuickView> onSelected;
  final bool compact;

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
            compact: compact,
          ),
          _MapQuickViewButton(
            label: 'Região',
            icon: Icons.public_rounded,
            active: selected == _MapQuickView.region,
            onPressed: () => onSelected(_MapQuickView.region),
            compact: compact,
          ),
          _MapQuickViewButton(
            label: 'Rota',
            icon: Icons.route_rounded,
            active: selected == _MapQuickView.route,
            onPressed:
                routeAvailable ? () => onSelected(_MapQuickView.route) : null,
            compact: compact,
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
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    final foreground = !enabled
        ? scheme.onSurface.withValues(alpha: 0.32)
        : active
            ? scheme.onPrimaryContainer
            : scheme.onSurface;
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 9,
            vertical: 7,
          ),
          color: active ? scheme.primaryContainer : Colors.transparent,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: compact ? 17 : 15, color: foreground),
              if (!compact) ...[
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                    color: foreground,
                  ),
                ),
              ],
            ],
          ),
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

class _MapZoomCluster extends StatelessWidget {
  const _MapZoomCluster({
    required this.horizontal,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final bool horizontal;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final children = <Widget>[
      _MapZoomAction(
        tooltip: 'Aumentar zoom',
        icon: Icons.add_rounded,
        onPressed: onZoomIn,
      ),
      SizedBox(
        width: horizontal ? 1 : 28,
        height: horizontal ? 28 : 1,
        child: ColoredBox(
          color: scheme.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      _MapZoomAction(
        tooltip: 'Diminuir zoom',
        icon: Icons.remove_rounded,
        onPressed: onZoomOut,
      ),
    ];
    return Material(
      elevation: 4,
      color: scheme.surface.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Flex(
        direction: horizontal ? Axis.horizontal : Axis.vertical,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

class _MapZoomAction extends StatelessWidget {
  const _MapZoomAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: MapUxPolicy.controlSize,
            height: MapUxPolicy.controlSize,
            child: Icon(icon, size: 21),
          ),
        ),
      );
}

class _CameraPipMenuButton extends StatelessWidget {
  const _CameraPipMenuButton({required this.onSelected});

  final ValueChanged<_CameraPipMenuAction> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 30,
        height: 30,
        child: PopupMenuButton<_CameraPipMenuAction>(
          tooltip: 'Opções da câmera',
          onSelected: onSelected,
          padding: EdgeInsets.zero,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.66),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.more_vert_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: _CameraPipMenuAction.source,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.cameraswitch_outlined),
                title: Text('Trocar fonte'),
              ),
            ),
            PopupMenuItem(
              value: _CameraPipMenuAction.size,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.aspect_ratio_rounded),
                title: Text('Alterar tamanho'),
              ),
            ),
            PopupMenuItem(
              value: _CameraPipMenuAction.minimize,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.minimize_rounded),
                title: Text('Minimizar'),
              ),
            ),
            PopupMenuItem(
              value: _CameraPipMenuAction.hide,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.visibility_off_outlined),
                title: Text('Ocultar'),
              ),
            ),
          ],
        ),
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

class _OnlineMapLayerSpec {
  const _OnlineMapLayerSpec({
    required this.urlTemplate,
    required this.maxNativeZoom,
    required this.attribution,
    this.subdomains = const <String>[],
  });

  final String urlTemplate;
  final int maxNativeZoom;
  final String attribution;
  final List<String> subdomains;
}

class _SelectedPoiCard extends StatelessWidget {
  const _SelectedPoiCard({
    required this.item,
    required this.distanceLabel,
    required this.icon,
    required this.onClose,
    required this.onDetails,
    required this.onNavigate,
    this.compact = false,
  });

  final RouteExplorerResult item;
  final String distanceLabel;
  final IconData icon;
  final VoidCallback onClose;
  final VoidCallback onDetails;
  final VoidCallback onNavigate;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      color: scheme.surface.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: scheme.primaryContainer,
              child: Icon(icon, size: 19, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: onDetails,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        '${item.category.label} · $distanceLabel · '
                        '${item.source == 'offline' ? 'Offline' : 'Online'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (!compact)
              IconButton(
                tooltip: 'Detalhes',
                visualDensity: VisualDensity.compact,
                onPressed: onDetails,
                icon: const Icon(Icons.info_outline_rounded),
              ),
            IconButton(
              tooltip: 'Navegar até',
              visualDensity: VisualDensity.compact,
              onPressed: onNavigate,
              icon: const Icon(Icons.navigation_rounded),
            ),
            IconButton(
              tooltip: 'Fechar',
              visualDensity: VisualDensity.compact,
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
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
    required this.styleLabel,
    required this.onTap,
    this.compact = false,
  });

  final OfflineMapMode mode;
  final OfflineMapPackage? activePackage;
  final String? error;
  final String styleLabel;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasOffline = activePackage != null && error == null;
    final label = error != null
        ? 'Offline com erro'
        : switch (mode) {
            OfflineMapMode.automatic =>
              hasOffline ? '$styleLabel · Auto' : styleLabel,
            OfflineMapMode.online => styleLabel,
            OfflineMapMode.offline => hasOffline ? 'Offline' : 'Offline indisponível',
          };
    final icon = switch (mode) {
      OfflineMapMode.automatic => Icons.swap_calls_rounded,
      OfflineMapMode.online => Icons.cloud_outlined,
      OfflineMapMode.offline => Icons.offline_pin_outlined,
    };
    return Tooltip(
      message: 'Camadas e tipo do mapa',
      child: Material(
        color: scheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 11,
              vertical: 7,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: error == null ? scheme.primary : scheme.error,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
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
  const _GpsChip({required this.point, this.compact = false});

  final MapRoutePoint? point;
  final bool compact;

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
              accuracy == null
                  ? 'GPS…'
                  : compact
                      ? '±${accuracy.toStringAsFixed(0)} m'
                      : 'GPS ±${accuracy.toStringAsFixed(0)} m',
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
    required this.routeState,
    required this.altitudeMeters,
    required this.headingDegrees,
    required this.following,
    required this.onToggleFollow,
    this.compact = false,
  });

  final bool paused;
  final double speedKmh;
  final String distance;
  final MapRouteService routeState;
  final double? altitudeMeters;
  final double? headingDegrees;
  final bool following;
  final VoidCallback? onToggleFollow;
  final bool compact;

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
          if (!compact || routeState.recording) ...[
            const SizedBox(width: 5),
            _LiveRouteElapsedPill(routeState: routeState),
          ],
          if (!compact) ...[
            const SizedBox(width: 5),
            _MapInfoPill(
              icon: Icons.height_rounded,
              label: altitudeMeters == null
                  ? 'Alt. --'
                  : 'Alt. ${altitudeMeters!.toStringAsFixed(0)} m',
            ),
          ],
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

class _LiveRouteElapsedPill extends StatefulWidget {
  const _LiveRouteElapsedPill({required this.routeState});

  final MapRouteService routeState;

  @override
  State<_LiveRouteElapsedPill> createState() => _LiveRouteElapsedPillState();
}

class _LiveRouteElapsedPillState extends State<_LiveRouteElapsedPill> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !widget.routeState.recording || widget.routeState.paused) {
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _format(Duration value) {
    final hours = value.inHours.toString().padLeft(2, '0');
    final minutes = (value.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return _MapInfoPill(
      icon: Icons.timer_outlined,
      label: _format(widget.routeState.elapsed),
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

