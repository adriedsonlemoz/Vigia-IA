import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_mbtiles/flutter_map_mbtiles.dart';
import 'package:latlong2/latlong.dart';

import '../controllers/secondary_camera_controller.dart';
import '../models/bike_approach_status.dart';
import '../models/camera_endpoint.dart';
import '../models/map_connectivity_status.dart';
import '../models/map_navigation_target.dart';
import '../models/map_travel_mode.dart';
import '../models/monitor_ai_pip_status.dart';
import '../models/map_cycling_route.dart';
import '../models/map_route_point.dart';
import '../models/offline_map_package.dart';
import '../models/offline_poi_package.dart';
import '../models/route_explorer_models.dart';
import '../models/video_source_config.dart';
import '../services/app_settings_service.dart';
import '../services/camera_registry_service.dart';
import '../services/location_tracking_service.dart';
import '../services/error_log_service.dart';
import '../services/map_camera_overlay_settings_service.dart';
import '../services/map_bike_consolidation_policy.dart';
import '../services/map_connectivity_service.dart';
import '../services/map_compass_service.dart';
import '../services/map_cycling_route_service.dart';
import '../services/map_gps_filter.dart';
import '../services/map_navigation_guidance.dart';
import '../services/map_navigation_voice_service.dart';
import '../services/map_offline_navigation_policy.dart';
import '../services/map_poi_display_policy.dart';
import '../services/map_route_service.dart';
import '../services/map_telemetry_policy.dart';
import '../services/map_ux_policy.dart';
import '../services/map_view_policy.dart';
import '../services/map_view_settings_service.dart';
import '../services/native_platform_service.dart';
import '../services/offline_map_service.dart';
import '../services/route_explorer_service.dart';
import '../services/system_ui_service.dart';
import 'audio_settings_screen.dart';
import '../widgets/offline_map_manager_sheet.dart';
import '../widgets/map_navigation_3d_view.dart';
import '../widgets/map_poi_details_sheet.dart';
import '../widgets/map_bike_approach_overlay.dart';
import '../widgets/map_ai_status_overlay.dart';

part 'map_monitoring_offline_support.dart';

enum _MapPoiQuickFilter { all, fuel, food, health, water, nature, travel, other }

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
    this.cameraAiStatusProvider,
    this.secondaryCameraAiStatusProvider,
    this.bikeApproachStatusProvider,
    this.bikeApproachEnabledProvider,
    this.aiVoiceEnabledProvider,
    this.onAiVoiceChanged,
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
  final MonitorAiPipStatus Function()? cameraAiStatusProvider;
  final MonitorAiPipStatus Function()? secondaryCameraAiStatusProvider;
  final BikeApproachStatus Function()? bikeApproachStatusProvider;
  final bool Function()? bikeApproachEnabledProvider;
  final bool Function()? aiVoiceEnabledProvider;
  final ValueChanged<bool>? onAiVoiceChanged;
  final RouteExplorerResult? initialPointOfInterest;

  @override
  State<MapMonitoringScreen> createState() => _MapMonitoringScreenState();
}

class _MapMonitoringScreenState extends State<MapMonitoringScreen>
    with WidgetsBindingObserver {
  static const String _openFreeMapVectorStyleUrl =
      'https://tiles.openfreemap.org/styles/liberty';
  static const String _openFreeMapAttribution =
      '© OpenFreeMap · © OpenMapTiles · © OpenStreetMap contributors';

  final MapController _mapController = MapController();
  final LocationTrackingService _location = LocationTrackingService.instance;
  final OfflineMapService _offlineMaps = OfflineMapService.instance;
  final MapRouteService _routeState = MapRouteService.instance;
  final MapCyclingRouteService _cyclingRoutes = MapCyclingRouteService();
  final MapNavigationGuidance _navigationGuidance = const MapNavigationGuidance();
  final MapNavigationVoiceService _navigationVoice = MapNavigationVoiceService();
  MapCyclingRoute? _cyclingRoute;
  List<MapCyclingRoute> _cyclingRouteAlternatives = const <MapCyclingRoute>[];
  int _selectedCyclingRouteIndex = 0;
  MapNavigationProgress? _navigationProgress;
  bool _cyclingRouteLoading = false;
  int _cyclingRouteRequestSerial = 0;
  int _offRouteSamples = 0;
  DateTime? _lastRouteRecalculatedAt;
  DateTime? _lastNavigationProgressPointAt;
  final NativePlatformService _native = NativePlatformService.instance;
  final AppSettingsService _appSettings = AppSettingsService.instance;
  final RouteExplorerService _routeExplorer = RouteExplorerService.instance;
  final MapConnectivityService _connectivity = MapConnectivityService.instance;
  final ErrorLogService _logs = ErrorLogService.instance;
  final MapCompassService _compass = const MapCompassService();
  final MapTelemetrySessionTracker _telemetrySession =
      MapTelemetrySessionTracker();
  final MapViewSettingsService _mapViewSettings = MapViewSettingsService.instance;
  final CameraRegistryService _cameraRegistry = CameraRegistryService.instance;
  final MapCameraOverlaySettingsService _cameraOverlaySettings =
      MapCameraOverlaySettingsService.instance;

  SecondaryCameraController? _primaryMapCamera;
  SecondaryCameraController? _secondaryMapCamera;
  bool _primaryUsesExternal = false;
  bool _secondaryUsesExternal = false;
  MapCameraSlotLayout _primaryCameraLayout = const MapCameraSlotLayout(yFraction: 0.08);
  MapCameraSlotLayout _secondaryCameraLayout = const MapCameraSlotLayout(
    yFraction: 0.78,
  );
  bool _appActive = true;

  MbTilesTileProvider? _offlineTileProvider;
  String? _offlineTilePackageId;
  int _offlineMinNativeZoom = 0;
  int _offlineMaxNativeZoom = 19;
  Offset? _primaryCameraOffset;
  Offset? _secondaryCameraOffset;
  bool _camerasVisible = true;

  bool _followPosition = true;
  bool _mapReady = false;
  Size _mapViewportSize = Size.zero;
  bool _compactLandscape = false;
  MapConnectivityState _lastConnectivityState = MapConnectivityState.unknown;
  MapRouteFallbackDecision? _routeFallback;
  Timer? _routeRecoveryTimer;
  bool _routeRecoveryBusy = false;
  _MapQuickView? _quickView = _MapQuickView.near;
  double? _customFollowZoom;
  DateTime? _lastFollowCameraPointAt;
  StreamSubscription<MapCompassReading>? _compassSubscription;
  MapCompassReading? _compassReading;
  double? _smoothedSensorHeading;
  _MapPoiQuickFilter _poiFilter = _MapPoiQuickFilter.all;
  String? _selectedPoiId;
  double _visibleMapZoom = MapViewPolicy.nearZoom;
  bool _navigation3dEnabled = true;
  bool _navigation3dRendererReady = false;
  bool _navigation3dRendererFailed = false;
  bool _navigation3dFollowing = true;
  int _navigation3dRecenterRequest = 0;
  MapTravelMode _lastTravelMode = MapTravelMode.bicycle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _primaryUsesExternal = widget.cameraPreviewBuilder != null;
    _secondaryUsesExternal = widget.secondaryCameraPreviewBuilder != null;
    _offlineMaps.addListener(_onOfflineMapsChanged);
    _routeState.addListener(_onRouteStateChanged);
    _routeExplorer.addListener(_onRouteExplorerChanged);
    _connectivity.addListener(_onMapConnectivityChanged);
    _selectedPoiId = widget.initialPointOfInterest?.id;
    unawaited(SystemUiService.edgeToEdge());
    unawaited(_initializeOfflineMaps());
    unawaited(_initializeCameraOverlays());
    unawaited(_connectivity.acquire(this));
    _compassSubscription = _compass.readings().listen(
      _onCompassReading,
      onError: _onCompassError,
    );
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
    _connectivity.removeListener(_onMapConnectivityChanged);
    _connectivity.release(this);
    _routeRecoveryTimer?.cancel();
    unawaited(_compassSubscription?.cancel());
    _offlineTileProvider?.dispose();
    _navigationVoice.resetRoute();
    _mapController.dispose();
    super.dispose();
  }

  static const String _mapLocalBackCameraId = '__map_local_back__';

  void _applyOfflineUiState(VoidCallback update) {
    if (!mounted) return;
    setState(update);
  }

  Future<void> _initializeCameraOverlays() async {
    await Future.wait<void>([
      _cameraOverlaySettings.initialize(),
      _cameraRegistry.initialize(),
    ]);
    if (!mounted) return;
    setState(() {
      _camerasVisible = _cameraOverlaySettings.visible;
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
      unawaited(_connectivity.checkNow(force: true));
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
    final hadCamera = _slotHasCamera(secondary);
    final otherHasCamera = _slotHasCamera(!secondary);
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
      if (!hadCamera && otherHasCamera && (source != null || useExternal)) {
        _secondaryCameraLayout = _secondaryCameraLayout.copyWith(
          xFraction: _compactLandscape
              ? (_primaryCameraLayout.xFraction < 0.5 ? 0.92 : 0.08)
              : _primaryCameraLayout.xFraction,
          yFraction: _compactLandscape
              ? _primaryCameraLayout.yFraction
              : (_primaryCameraLayout.yFraction < 0.5 ? 0.78 : 0.08),
        );
      }
      await _cameraOverlaySettings.saveSecondary(_secondaryCameraLayout);
    } else {
      _primaryMapCamera = next;
      _primaryUsesExternal = useExternal;
      _primaryCameraOffset = null;
      _primaryCameraLayout = _primaryCameraLayout.copyWith(
        hidden: source == null && !useExternal,
        minimized: false,
      );
      if (!hadCamera && otherHasCamera && (source != null || useExternal)) {
        _primaryCameraLayout = _primaryCameraLayout.copyWith(
          xFraction: _compactLandscape
              ? (_secondaryCameraLayout.xFraction < 0.5 ? 0.92 : 0.08)
              : _secondaryCameraLayout.xFraction,
          yFraction: _compactLandscape
              ? _secondaryCameraLayout.yFraction
              : (_secondaryCameraLayout.yFraction < 0.5 ? 0.78 : 0.08),
        );
      }
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

  Future<void> _swapInternalCameraSlots() async {
    if (!_slotHasCamera(false) || !_slotHasCamera(true)) return;
    if (_primaryUsesExternal || _secondaryUsesExternal) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Para câmeras vindas do Monitor, use “Trocar fonte”. A troca direta funciona nas fontes abertas pelo mapa.',
          ),
        ),
      );
      return;
    }
    final primary = _primaryMapCamera;
    _primaryMapCamera = _secondaryMapCamera;
    _secondaryMapCamera = primary;
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
                    'Escolha fontes e organize os PiPs. Arraste para encaixar, dê dois toques para mudar o tamanho e minimize para virar uma bolha; posição e tamanho ficam salvos.',
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
                      await _cameraOverlaySettings.saveVisible(value);
                      if (value) {
                        await _resumeVisibleInternalCameras();
                      } else {
                        await _primaryMapCamera?.suspend();
                        await _secondaryMapCamera?.suspend();
                      }
                    },
                  ),
                  const SizedBox(height: 4),
                  if (_slotHasCamera(false) && _slotHasCamera(true)) ...[
                    OutlinedButton.icon(
                      onPressed: () async {
                        await _swapInternalCameraSlots();
                        setSheetState(() {});
                      },
                      icon: const Icon(Icons.swap_vert_rounded),
                      label: const Text('Trocar câmera 1 ↔ 2'),
                    ),
                    const SizedBox(height: 8),
                  ],
                  OutlinedButton.icon(
                    onPressed: () async {
                      await _cameraOverlaySettings.resetLayout();
                      if (!mounted) return;
                      setState(() {
                        _camerasVisible = _cameraOverlaySettings.visible;
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
    _navigation3dRendererReady = false;
    _navigation3dRendererFailed = false;
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
        debugPrint(
          'Falha ao abrir mapa offline ${active.id}: $error',
        );
      }
    }
    setState(() {});
  }

  Future<void> _initialize() async {
    await Future.wait<void>([
      _mapViewSettings.initialize(),
      _appSettings.initialize().then((_) {}),
    ]);
    _quickView = switch (_mapViewSettings.followViewPreset) {
      MapFollowViewPreset.near => _MapQuickView.near,
      MapFollowViewPreset.region => _MapQuickView.region,
    };
    _lastTravelMode = _mapViewSettings.lastTravelMode;
    await _routeState.acquireLocationConsumer(
      this,
      requestPermission: true,
    );
    if (MapTelemetryPolicy.isFresh(_routeState.current)) {
      _telemetrySession.add(_routeState.current);
    }
    await Future.wait<void>([
      _routeExplorer.initialize(),
      _navigationVoice.initialize(),
    ]);
    if (!mounted) return;
    setState(() {});
    if (_routeState.availability == LocationTrackingAvailability.ready &&
        _routeState.current != null &&
        _routeExplorer.activeResults.isEmpty &&
        !_routeExplorer.loading) {
      unawaited(_routeExplorer.searchNow(requestPermission: false));
    }
    final restoredTarget = _routeState.navigationTarget;
    final restoredPosition = _routeState.current;
    if (restoredTarget != null) {
      _lastTravelMode = restoredTarget.travelMode;
      unawaited(_mapViewSettings.setLastTravelMode(restoredTarget.travelMode));
      _navigation3dEnabled = true;
      _navigation3dRendererReady = false;
      _navigation3dRendererFailed = false;
      _navigation3dFollowing = true;
    }
    if (restoredTarget != null && restoredPosition != null) {
      unawaited(
        _requestCyclingRoute(
          origin: LatLng(restoredPosition.latitude, restoredPosition.longitude),
          target: restoredTarget,
          fitRoute: false,
          announceFailure: false,
        ),
      );
    }
  }

  void _onRouteExplorerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onRouteStateChanged() {
    if (!mounted) return;
    final navigationStopped = _routeState.navigationTarget == null &&
        (_cyclingRoute != null ||
            _cyclingRouteAlternatives.isNotEmpty ||
            _cyclingRouteLoading ||
            _routeFallback != null ||
            _navigationProgress != null);
    if (navigationStopped) {
      _cancelRouteRecovery();
      _cyclingRouteRequestSerial += 1;
      _navigationVoice.resetRoute();
      _clearLocalNavigationState();
    }
    final current = _routeState.current;
    if (MapTelemetryPolicy.isFresh(current)) {
      _telemetrySession.add(current);
    }
    _navigationProgress = _evaluateNavigationProgress(current);
    unawaited(_navigationVoice.handleProgress(_navigationProgress));
    setState(() {});
    final routeUses3d = _navigation3dEnabled &&
        _navigation3dRendererReady &&
        !_navigation3dRendererFailed &&
        _routeState.navigationTarget != null &&
        _cyclingRoute != null &&
        !_connectivity.isOffline &&
        _offlineMaps.mode != OfflineMapMode.offline;
    if (!routeUses3d &&
        _followPosition &&
        current != null &&
        current.recordedAt != _lastFollowCameraPointAt) {
      _applyFollowCamera(current);
    }
    if (current != null) {
      unawaited(_maybeRecalculateCyclingRoute(current));
    }
  }

  MapNavigationProgress? _evaluateNavigationProgress(MapRoutePoint? current) {
    final route = _cyclingRoute;
    if (current == null || route == null || _routeState.navigationTarget == null) {
      return null;
    }
    return _navigationGuidance.evaluate(route: route, position: current);
  }

  Future<void> _maybeRecalculateCyclingRoute(MapRoutePoint current) async {
    final target = _routeState.navigationTarget;
    final progress = _navigationProgress;
    if (target == null || progress == null || _cyclingRouteLoading) return;
    if (_lastNavigationProgressPointAt == current.recordedAt) return;
    _lastNavigationProgressPointAt = current.recordedAt;
    if (progress.arrived || !progress.offRoute) {
      _offRouteSamples = 0;
      return;
    }

    _offRouteSamples += 1;
    if (_offRouteSamples <
        MapNavigationGuidance.offRouteSamplesBeforeRecalculation) {
      return;
    }
    final lastRecalculation = _lastRouteRecalculatedAt;
    if (lastRecalculation != null &&
        DateTime.now().difference(lastRecalculation) <
            MapNavigationGuidance.recalculationCooldown) {
      return;
    }

    _offRouteSamples = 0;
    _lastRouteRecalculatedAt = DateTime.now();
    if (_connectivity.isOffline) {
      _markRouteUnavailable(
        recalculation: true,
        announceFailure: false,
      );
      return;
    }
    unawaited(_navigationVoice.announceOffRouteAndRecalculation());
    await _requestCyclingRoute(
      origin: LatLng(current.latitude, current.longitude),
      target: target,
      fitRoute: false,
      recalculation: true,
      announceFailure: false,
    );
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

  double? get _sensorHeadingDegrees {
    final reading = _compassReading;
    if (reading == null || _smoothedSensorHeading == null) return null;
    if (DateTime.now().difference(reading.recordedAt) >
        const Duration(seconds: 3)) {
      return null;
    }
    return _smoothedSensorHeading;
  }

  double? _routeHeadingFor(MapRoutePoint? current) =>
      MapViewPolicy.routeBearingNear(
        current: current,
        routePoints: _cyclingRoute?.points ?? const <LatLng>[],
      );

  MapHeadingDecision _displayHeadingFor(MapRoutePoint? current) =>
      MapViewPolicy.displayHeading(
        speedKmh: current?.speedKilometersPerHour ?? 0,
        sensorHeadingDegrees: _sensorHeadingDegrees,
        gpsHeadingDegrees: current?.headingDegrees,
        routeHeadingDegrees: _routeHeadingFor(current),
      );

  MapHeadingDecision _orientationHeadingFor(MapRoutePoint? current) =>
      MapViewPolicy.orientationHeading(
        mode: _mapViewSettings.orientationMode,
        speedKmh: current?.speedKilometersPerHour ?? 0,
        sensorHeadingDegrees: _sensorHeadingDegrees,
        gpsHeadingDegrees: current?.headingDegrees,
        routeHeadingDegrees: _routeHeadingFor(current),
      );

  void _onCompassError(Object error, StackTrace stackTrace) {
    unawaited(
      _logs.recordException(
        source: 'Mapa / Bússola',
        error: error,
        stackTrace: stackTrace,
        level: ErrorLogLevel.warning,
        message: 'Bússola física indisponível; orientação continua com GPS/rota quando possível.',
        context: <String, Object?>{
          'orientationMode': _mapViewSettings.orientationMode.name,
        },
      ),
    );
    if (mounted) setState(() {});
  }

  void _onCompassReading(MapCompassReading reading) {
    final previous = _smoothedSensorHeading;
    final smoothed = MapViewPolicy.smoothHeading(
      previous,
      reading.headingDegrees,
      alpha: 0.28,
    );
    _compassReading = reading;
    if (previous != null &&
        MapViewPolicy.shortestAngularDelta(previous, smoothed).abs() <
            MapViewPolicy.sensorUpdateDeadZoneDegrees) {
      return;
    }
    _smoothedSensorHeading = smoothed;
    if (!mounted) return;
    setState(() {});
    final current = _routeState.current;
    if (_followPosition && current != null &&
        !(_navigation3dEnabled && _navigation3dRendererReady &&
            !_navigation3dRendererFailed &&
            _routeState.navigationTarget != null &&
            _cyclingRoute != null && !_connectivity.isOffline &&
            _offlineMaps.mode != OfflineMapMode.offline)) {
      _applyFollowCamera(current);
    }
  }

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
        final decision = _orientationHeadingFor(point);
        final heading = decision.headingDegrees;
        if (heading != null &&
            MapViewPolicy.shouldApplyMapRotation(
              headingDegrees: heading,
              currentMapRotationDegrees: _mapController.camera.rotation,
              force: forceRotation,
            )) {
          _mapController.rotate(MapViewPolicy.mapRotationForHeading(heading));
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

  IconData _travelModeIcon(MapTravelMode mode) => switch (mode) {
        MapTravelMode.bicycle => Icons.pedal_bike_rounded,
        MapTravelMode.motorcycle => Icons.two_wheeler_rounded,
        MapTravelMode.car => Icons.directions_car_filled_rounded,
        MapTravelMode.walking => Icons.directions_walk_rounded,
      };

  Future<MapTravelMode?> _chooseTravelMode() async {
    final scheme = Theme.of(context).colorScheme;
    return showModalBottomSheet<MapTravelMode>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final systemBottom = MediaQuery.viewPaddingOf(sheetContext).bottom;
        final bottomPadding = MapUxPolicy.travelModeSheetBottomPadding(
          viewPaddingBottom: systemBottom,
        );
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Como você vai até o destino?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                'A rota e o tempo estimado serão calculados para o veículo escolhido.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.04,
                    children: [
                      for (final mode in MapTravelMode.values)
                        _TravelModeChoiceCard(
                          mode: mode,
                          icon: _travelModeIcon(mode),
                          selected: mode == _lastTravelMode,
                          onTap: () => Navigator.of(sheetContext).pop(mode),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _navigateToPoi(RouteExplorerResult item) async {
    final travelMode = await _chooseTravelMode();
    if (!mounted || travelMode == null) return;
    final current = _routeState.current;
    _navigationVoice.resetRoute();
    final target = MapNavigationTarget(
      latitude: item.latitude,
      longitude: item.longitude,
      label: item.title,
      startedAt: DateTime.now(),
      sourceId: item.id,
      travelMode: travelMode,
    );
    setState(() {
      _lastTravelMode = travelMode;
      _navigation3dEnabled = true;
      _navigation3dRendererReady = false;
      _navigation3dRendererFailed = false;
      _navigation3dFollowing = true;
      _followPosition = true;
      _quickView = _MapQuickView.near;
      _customFollowZoom = null;
      _selectedPoiId = item.id;
      _cyclingRoute = null;
      _cyclingRouteAlternatives = const <MapCyclingRoute>[];
      _selectedCyclingRouteIndex = 0;
      _navigationProgress = null;
      _offRouteSamples = 0;
      _lastRouteRecalculatedAt = null;
      _lastNavigationProgressPointAt = null;
    });
    unawaited(_mapViewSettings.setLastTravelMode(travelMode));
    await _routeState.navigateTo(target);
    if (current != null) {
      await _requestCyclingRoute(
        origin: LatLng(current.latitude, current.longitude),
        target: target,
        fitRoute: true,
        announceFailure: true,
      );
      final using3d = _navigation3dEnabled &&
          _navigation3dRendererReady &&
          !_navigation3dRendererFailed &&
          _cyclingRoute != null &&
          !_connectivity.isOffline &&
          _offlineMaps.mode != OfflineMapMode.offline;
      if (!using3d) {
        _applyFollowCamera(current, forceRotation: true);
      }
    }
  }

  Future<void> _requestCyclingRoute({
    required LatLng origin,
    required MapNavigationTarget target,
    required bool fitRoute,
    required bool announceFailure,
    bool recalculation = false,
  }) async {
    final requestSerial = ++_cyclingRouteRequestSerial;
    if (mounted) {
      setState(() => _cyclingRouteLoading = true);
    }
    if (_connectivity.isOffline) {
      _markRouteUnavailable(
        recalculation: recalculation,
        announceFailure: announceFailure,
      );
      if (mounted && requestSerial == _cyclingRouteRequestSerial) {
        setState(() => _cyclingRouteLoading = false);
      }
      return;
    }
    try {
      final routes = await _cyclingRoutes.fetchAlternatives(
        origin: origin,
        destination: LatLng(target.latitude, target.longitude),
        alternativeCount: 2,
        travelMode: target.travelMode,
      );
      if (!mounted || requestSerial != _cyclingRouteRequestSerial) return;
      final activeTarget = _routeState.navigationTarget;
      if (!_sameNavigationTarget(activeTarget, target)) return;
      final current = _routeState.current;
      final route = routes.first;
      setState(() {
        _cyclingRouteAlternatives = routes;
        _selectedCyclingRouteIndex = 0;
        _cyclingRoute = route;
        _routeFallback = null;
        _navigationProgress = current == null
            ? null
            : _navigationGuidance.evaluate(route: route, position: current);
      });
      _cancelRouteRecovery();
      if (fitRoute) _fitCyclingRoutes(routes);
      if (recalculation) {
        unawaited(_navigationVoice.announceRecalculated(_navigationProgress));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rota recalculada a partir da posição atual.')),
          );
        }
      } else {
        unawaited(_navigationVoice.handleProgress(_navigationProgress));
      }
    } catch (_) {
      if (!mounted || requestSerial != _cyclingRouteRequestSerial) return;
      _markRouteUnavailable(
        recalculation: recalculation,
        announceFailure: announceFailure,
      );
      unawaited(_connectivity.checkNow(force: true));
    } finally {
      if (mounted && requestSerial == _cyclingRouteRequestSerial) {
        setState(() => _cyclingRouteLoading = false);
      }
    }
  }

  void _selectCyclingRoute(int index) {
    if (index < 0 || index >= _cyclingRouteAlternatives.length) return;
    if (index == _selectedCyclingRouteIndex) return;
    final route = _cyclingRouteAlternatives[index];
    final current = _routeState.current;
    setState(() {
      _selectedCyclingRouteIndex = index;
      _cyclingRoute = route;
      _navigationProgress = current == null
          ? null
          : _navigationGuidance.evaluate(route: route, position: current);
      _offRouteSamples = 0;
      _lastNavigationProgressPointAt = null;
    });
    _navigationVoice.resetRoute();
    unawaited(_navigationVoice.handleProgress(_navigationProgress));
    if (!_followPosition) _fitCyclingRoute(route.points);
  }

  void _fitCyclingRoutes(List<MapCyclingRoute> routes) {
    final points = <LatLng>[
      for (final route in routes) ...route.points,
    ];
    _fitCyclingRoute(points);
  }

  bool _sameNavigationTarget(
    MapNavigationTarget? active,
    MapNavigationTarget expected,
  ) {
    if (active == null) return false;
    if (active.sourceId != null && expected.sourceId != null) {
      return active.sourceId == expected.sourceId;
    }
    return (active.latitude - expected.latitude).abs() < 0.00001 &&
        (active.longitude - expected.longitude).abs() < 0.00001;
  }

  void _fitCyclingRoute(List<LatLng> points) {
    if (!_mapReady || points.length < 2) return;
    try {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.fromLTRB(48, 138, 60, 150),
          minZoom: 3,
          maxZoom: 16,
        ),
      );
      setState(() => _followPosition = false);
    } catch (_) {}
  }

  void _clearLocalNavigationState() {
    _routeFallback = null;
    _cyclingRoute = null;
    _cyclingRouteAlternatives = const <MapCyclingRoute>[];
    _selectedCyclingRouteIndex = 0;
    _navigationProgress = null;
    _cyclingRouteLoading = false;
    _offRouteSamples = 0;
    _lastRouteRecalculatedAt = null;
    _lastNavigationProgressPointAt = null;
    _navigation3dEnabled = true;
    _navigation3dRendererReady = false;
    _navigation3dRendererFailed = false;
    _navigation3dFollowing = true;
  }

  void _stopNavigation() {
    _cancelRouteRecovery();
    _cyclingRouteRequestSerial += 1;
    _navigationVoice.resetRoute();
    setState(_clearLocalNavigationState);
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

  bool get _allCameraSlotsHidden {
    final primaryHidden = !_slotHasCamera(false) || _primaryCameraLayout.hidden;
    final secondaryHidden = !_slotHasCamera(true) || _secondaryCameraLayout.hidden;
    return primaryHidden && secondaryHidden;
  }

  Future<void> _showCameraOverlayQuickly() async {
    if (!_hasCameraOverlay) {
      await _showCameraManager();
      return;
    }

    _camerasVisible = true;
    await _cameraOverlaySettings.saveVisible(true);
    if (_allCameraSlotsHidden) {
      if (_slotHasCamera(false)) {
        _primaryCameraLayout = _primaryCameraLayout.copyWith(
          hidden: false,
          minimized: false,
        );
        await _cameraOverlaySettings.savePrimary(_primaryCameraLayout);
      } else if (_slotHasCamera(true)) {
        _secondaryCameraLayout = _secondaryCameraLayout.copyWith(
          hidden: false,
          minimized: false,
        );
        await _cameraOverlaySettings.saveSecondary(_secondaryCameraLayout);
      }
    }
    if (mounted) setState(() {});
    await _resumeVisibleInternalCameras();
  }

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

  BikeApproachStatus? _bikeApproachForPip(bool secondary) {
    if (secondary || !_primaryUsesExternal) return null;
    if (widget.bikeApproachEnabledProvider?.call() != true) return null;
    final source = _activeCameraConfig(false);
    if (source == null || source.isFrontCameraTest) return null;
    final status = widget.bikeApproachStatusProvider?.call();
    if (status == null) return null;
    if (!MapBikeConsolidationPolicy.shouldShowApproachOverlay(
      status: status,
      aiStatus: widget.cameraAiStatusProvider?.call(),
    )) {
      return null;
    }
    return status;
  }

  MonitorAiPipStatus? _aiStatusForPip(bool secondary) {
    if (secondary) {
      if (_secondaryUsesExternal) {
        return widget.secondaryCameraAiStatusProvider?.call();
      }
      return _secondaryMapCamera?.aiPipStatus;
    }
    if (_primaryUsesExternal) return widget.cameraAiStatusProvider?.call();
    return _primaryMapCamera?.aiPipStatus;
  }


  void _toggleNavigation3d() {
    final next = !_navigation3dEnabled;
    setState(() {
      _navigation3dEnabled = next;
      _navigation3dRendererReady = false;
      _navigation3dRendererFailed = false;
      _navigation3dFollowing = true;
      if (!next) {
        _followPosition = true;
        _quickView = _MapQuickView.near;
        _customFollowZoom = null;
      }
    });
    if (!next) _restore2dFollowAfter3d();
  }

  void _handleNavigation3dFollowChanged(bool following) {
    if (!mounted || _navigation3dFollowing == following) return;
    setState(() => _navigation3dFollowing = following);
  }

  void _recenterNavigation3d() {
    if (!mounted || _routeState.current == null) return;
    setState(() {
      _navigation3dFollowing = true;
      _navigation3dRecenterRequest += 1;
    });
  }

  void _handleNavigation3dReady() {
    if (!mounted || !_navigation3dEnabled) return;
    setState(() {
      _navigation3dRendererReady = true;
      _navigation3dRendererFailed = false;
      _navigation3dFollowing = true;
    });
  }

  void _handleNavigation3dFallback(String _) {
    if (!mounted) return;
    setState(() {
      _navigation3dEnabled = false;
      _navigation3dRendererReady = false;
      _navigation3dRendererFailed = true;
      _navigation3dFollowing = true;
      _followPosition = true;
      _quickView = _MapQuickView.near;
      _customFollowZoom = null;
    });
    _restore2dFollowAfter3d();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Modo 3D indisponível. A navegação continua normalmente no mapa 2D.',
        ),
      ),
    );
  }

  void _restore2dFollowAfter3d() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = _routeState.current;
      if (current != null) {
        _applyFollowCamera(current, forceRotation: true);
      }
    });
  }

  List<RouteExplorerResult> get _visiblePois => _routeExplorer.activeResults
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

  Future<void> _setOrientationMode(
    MapOrientationMode mode, {
    bool showUnavailableNotice = true,
  }) async {
    await _mapViewSettings.setOrientationMode(mode);
    if (!mounted) return;
    setState(() {});
    final current = _routeState.current;
    if (mode == MapOrientationMode.northUp) {
      if (_mapReady) _mapController.rotate(0);
    } else if (showUnavailableNotice &&
        !_orientationHeadingFor(current).available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Modo ${mode.label} ativado; aguardando sensor, GPS ou rota disponível.',
          ),
        ),
      );
    }
    if (_followPosition && current != null) {
      _applyFollowCamera(current, forceRotation: true);
    }
  }

  String _formatTelemetryTimestamp(DateTime? value) {
    if (value == null) return '--';
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  String _gpsStatus(MapRoutePoint? current) {
    return switch (_routeState.availability) {
      null => 'Inicializando',
      LocationTrackingAvailability.ready => current == null
          ? 'Aguardando leitura'
          : MapTelemetryPolicy.isFresh(current)
              ? 'Ativo'
              : 'Leitura antiga',
      LocationTrackingAvailability.servicesDisabled => 'GPS desativado',
      LocationTrackingAvailability.permissionDenied => 'Permissão negada',
      LocationTrackingAvailability.permissionDeniedForever =>
        'Permissão bloqueada',
    };
  }

  Future<void> _showSpeedDetails() async {
    if (!mounted) return;
    final current = _routeState.current;
    final speed = MapTelemetryPolicy.currentSpeedKmh(current);
    final speedAccuracy = MapTelemetryPolicy.speedAccuracyKmh(current);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.speed_rounded),
            SizedBox(width: 10),
            Text('Velocidade'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TelemetryDetailRow(
                label: 'Velocidade atual',
                value: speed == null
                    ? '--'
                    : '${speed.toStringAsFixed(1)} km/h',
              ),
              _TelemetryDetailRow(
                label: 'Média da sessão',
                value: _telemetrySession.averageSpeedKmh == null
                    ? '--'
                    : '${_telemetrySession.averageSpeedKmh!.toStringAsFixed(1)} km/h',
              ),
              _TelemetryDetailRow(
                label: 'Máxima da sessão',
                value: _telemetrySession.maximumSpeedKmh == null
                    ? '--'
                    : '${_telemetrySession.maximumSpeedKmh!.toStringAsFixed(1)} km/h',
              ),
              _TelemetryDetailRow(
                label: 'Fonte',
                value: speed == null ? 'Indisponível' : 'GPS do aparelho',
              ),
              _TelemetryDetailRow(
                label: 'Qualidade da leitura',
                value: speedAccuracy == null
                    ? 'Precisão indisponível'
                    : '±${speedAccuracy.toStringAsFixed(1)} km/h',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAltitudeDetails() async {
    if (!mounted) return;
    final current = _routeState.current;
    final altitude = current?.altitudeMeters;
    final accuracy = MapTelemetryPolicy.validAccuracyMeters(
      current?.altitudeAccuracyMeters,
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.height_rounded),
            SizedBox(width: 10),
            Text('Altitude'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TelemetryDetailRow(
              label: 'Altitude atual',
              value: altitude == null
                  ? '--'
                  : '${altitude.toStringAsFixed(1)} m',
            ),
            _TelemetryDetailRow(
              label: 'Precisão vertical',
              value: accuracy == null
                  ? 'Indisponível'
                  : '±${accuracy.toStringAsFixed(1)} m',
            ),
            _TelemetryDetailRow(
              label: 'Fonte',
              value: altitude == null ? 'Indisponível' : 'GPS do aparelho',
            ),
            _TelemetryDetailRow(
              label: 'Última atualização',
              value: altitude == null
                  ? '--'
                  : _formatTelemetryTimestamp(current?.recordedAt),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showGpsDetails() async {
    if (!mounted) return;
    final current = _routeState.current;
    final accuracy = MapTelemetryPolicy.validAccuracyMeters(
      current?.accuracyMeters,
    );
    final speed = MapTelemetryPolicy.currentSpeedKmh(current);
    final heading = MapTelemetryPolicy.gpsHeadingDegrees(current);
    final headingAccuracy = MapTelemetryPolicy.validAccuracyMeters(
      current?.headingAccuracyDegrees,
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.gps_fixed_rounded),
            SizedBox(width: 10),
            Text('GPS'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TelemetryDetailRow(label: 'Status', value: _gpsStatus(current)),
              _TelemetryDetailRow(
                label: 'Precisão',
                value: accuracy == null
                    ? '--'
                    : '±${accuracy.toStringAsFixed(1)} m',
              ),
              _TelemetryDetailRow(
                label: 'Latitude',
                value: current == null
                    ? '--'
                    : current.latitude.toStringAsFixed(6),
              ),
              _TelemetryDetailRow(
                label: 'Longitude',
                value: current == null
                    ? '--'
                    : current.longitude.toStringAsFixed(6),
              ),
              _TelemetryDetailRow(
                label: 'Velocidade GPS',
                value: speed == null
                    ? '--'
                    : '${speed.toStringAsFixed(1)} km/h',
              ),
              _TelemetryDetailRow(
                label: 'Heading GPS',
                value: heading == null
                    ? '--'
                    : '${heading.toStringAsFixed(0)}°',
              ),
              if (headingAccuracy != null)
                _TelemetryDetailRow(
                  label: 'Precisão do heading',
                  value: '±${headingAccuracy.toStringAsFixed(0)}°',
                ),
              _TelemetryDetailRow(
                label: 'Altitude',
                value: current?.altitudeMeters == null
                    ? '--'
                    : '${current!.altitudeMeters!.toStringAsFixed(1)} m',
              ),
              _TelemetryDetailRow(
                label: 'Última leitura',
                value: _formatTelemetryTimestamp(current?.recordedAt),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCompassDetails() async {
    if (!mounted) return;
    var selected = _mapViewSettings.orientationMode;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final current = _routeState.current;
          final heading = _displayHeadingFor(current);
          final degrees = heading.headingDegrees;
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.explore_rounded),
                SizedBox(width: 10),
                Text('Bússola e orientação'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TelemetryDetailRow(
                  label: 'Direção atual',
                  value: _mapDirectionLabel(degrees),
                ),
                _TelemetryDetailRow(
                  label: 'Graus',
                  value: degrees == null ? '--' : '${degrees.toStringAsFixed(0)}°',
                ),
                _TelemetryDetailRow(
                  label: 'Fonte usada',
                  value: heading.source.label,
                ),
                _TelemetryDetailRow(
                  label: 'Modo atual',
                  value: selected.label,
                ),
                const SizedBox(height: 14),
                SegmentedButton<MapOrientationMode>(
                  segments: const [
                    ButtonSegment(
                      value: MapOrientationMode.northUp,
                      icon: Icon(Icons.north_rounded),
                      label: Text('Norte'),
                    ),
                    ButtonSegment(
                      value: MapOrientationMode.directionUp,
                      icon: Icon(Icons.explore_rounded),
                      label: Text('Direção'),
                    ),
                    ButtonSegment(
                      value: MapOrientationMode.routeUp,
                      icon: Icon(Icons.alt_route_rounded),
                      label: Text('Rota'),
                    ),
                  ],
                  selected: <MapOrientationMode>{selected},
                  onSelectionChanged: (selection) {
                    final next = selection.first;
                    setDialogState(() => selected = next);
                    unawaited(
                      _setOrientationMode(
                        next,
                        showUnavailableNotice: false,
                      ),
                    );
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Fechar'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _mapDirectionLabel(double? degrees) {
    if (degrees == null || !degrees.isFinite) return '--';
    const labels = ['N', 'NE', 'L', 'SE', 'S', 'SO', 'O', 'NO'];
    final normalized = MapViewPolicy.normalizeDegrees(degrees);
    return labels[((normalized + 22.5) ~/ 45) % 8];
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
      _MapPoiQuickFilter.nature =>
        item.category == RouteExplorerCategory.viewpoint ||
            item.category == RouteExplorerCategory.waterfall ||
            item.category == RouteExplorerCategory.riverBridge,
      _MapPoiQuickFilter.travel =>
        item.category == RouteExplorerCategory.camping ||
            item.category == RouteExplorerCategory.workshop ||
            item.category == RouteExplorerCategory.market,
      _MapPoiQuickFilter.other => item.category == RouteExplorerCategory.stop,
    };
  }

  String _poiFilterLabel(_MapPoiQuickFilter filter) => switch (filter) {
        _MapPoiQuickFilter.all => 'Todos',
        _MapPoiQuickFilter.fuel => 'Postos',
        _MapPoiQuickFilter.food => 'Comida',
        _MapPoiQuickFilter.health => 'Saúde',
        _MapPoiQuickFilter.water => 'Água',
        _MapPoiQuickFilter.nature => 'Natureza',
        _MapPoiQuickFilter.travel => 'Bike/viagem',
        _MapPoiQuickFilter.other => 'Outros',
      };

  IconData _poiIcon(RouteExplorerCategory category) => switch (category) {
        RouteExplorerCategory.fuel => Icons.local_gas_station_rounded,
        RouteExplorerCategory.restaurant => Icons.restaurant_rounded,
        RouteExplorerCategory.stop => Icons.local_parking_rounded,
        RouteExplorerCategory.workshop => Icons.build_rounded,
        RouteExplorerCategory.health => Icons.local_hospital_rounded,
        RouteExplorerCategory.water => Icons.water_drop_rounded,
        RouteExplorerCategory.camping => Icons.home_rounded,
        RouteExplorerCategory.viewpoint => Icons.visibility_rounded,
        RouteExplorerCategory.waterfall => Icons.water_drop_rounded,
        RouteExplorerCategory.market => Icons.shopping_cart,
        RouteExplorerCategory.riverBridge => Icons.water_rounded,
      };

  Color _poiColor(RouteExplorerCategory category) => switch (category) {
        RouteExplorerCategory.fuel => Colors.orange.shade700,
        RouteExplorerCategory.restaurant => Colors.deepOrange.shade600,
        RouteExplorerCategory.stop => Colors.indigo.shade600,
        RouteExplorerCategory.workshop => Colors.amber.shade800,
        RouteExplorerCategory.health => Colors.red.shade600,
        RouteExplorerCategory.water => Colors.blue.shade600,
        RouteExplorerCategory.camping => Colors.green.shade700,
        RouteExplorerCategory.viewpoint => Colors.teal.shade700,
        RouteExplorerCategory.waterfall => Colors.lightBlue.shade700,
        RouteExplorerCategory.market => Colors.purple.shade600,
        RouteExplorerCategory.riverBridge => Colors.cyan.shade700,
      };

  void _focusPoiCluster(MapPoiCluster cluster) {
    if (!_mapReady) return;
    if (!cluster.isCluster) {
      _focusPoi(cluster.first);
      return;
    }
    setState(() {
      _followPosition = false;
      _quickView = null;
      _customFollowZoom = null;
      _selectedPoiId = null;
    });
    final nextZoom =
        math.min(16.0, math.max(_visibleMapZoom + 1.8, 13.0)).toDouble();
    _mapController.move(
      LatLng(cluster.latitude, cluster.longitude),
      nextZoom,
    );
  }

  bool _navigationMatchesSelectedPoi(
    RouteExplorerResult? selectedPoi,
    MapNavigationTarget? target,
  ) {
    if (selectedPoi == null || target == null) return false;
    if (target.sourceId != null && target.sourceId == selectedPoi.id) return true;
    return (target.latitude - selectedPoi.latitude).abs() < 0.00001 &&
        (target.longitude - selectedPoi.longitude).abs() < 0.00001;
  }

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
    for (final item in _routeExplorer.activeResults) {
      if (item.id == id) return item;
    }
    for (final item in _routeExplorer.offlineResults) {
      if (_routeExplorer.settings.categories.contains(item.category) &&
          item.id == id) {
        return item;
      }
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
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Configurações do mapa',
                    style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
              ),
              ListTile(
                leading: Icon(
                  _mapViewSettings.orientationMode == MapOrientationMode.northUp
                      ? Icons.north_rounded
                      : _mapViewSettings.orientationMode == MapOrientationMode.routeUp
                          ? Icons.alt_route_rounded
                          : Icons.explore_rounded,
                ),
                title: const Text('Orientação'),
                subtitle: Text(
                  'Modo ${_mapViewSettings.orientationMode.label}',
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_showCompassDetails());
                },
              ),
              ListTile(
                leading: Icon(
                  _hasCameraOverlay && _camerasVisible
                      ? Icons.videocam_rounded
                      : Icons.videocam_outlined,
                ),
                title: const Text('Câmeras sobre o mapa'),
                subtitle: Text(
                  _hasCameraOverlay
                      ? (_camerasVisible ? 'PiPs visíveis' : 'PiPs ocultos')
                      : 'Adicionar câmera ao mapa',
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_showCameraManager());
                },
              ),
              const Divider(height: 8),
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
                          onPressed: _routeExplorer.activeResults.isEmpty
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
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => MapPoiDetailsSheet(
        item: item,
        icon: _poiIcon(item.category),
        distanceLabel: _routeExplorer.formatDistance(item.distanceMeters),
        onShowOnMap: () => Navigator.of(sheetContext).pop(),
        onNavigate: () {
          Navigator.of(sheetContext).pop();
          _navigateToPoi(item);
        },
      ),
    );
  }

  bool get _aiVoiceEnabled =>
      widget.aiVoiceEnabledProvider?.call() ??
      _appSettings.profile.settings.alertOutputs.voice;

  Future<void> _setAiVoiceEnabled(bool enabled) async {
    widget.onAiVoiceChanged?.call(enabled);
    final current = await _appSettings.initialize();
    final settings = current.settings.copyWith(
      voiceEnabled: enabled,
      alertOutputs: current.settings.alertOutputs.copyWith(voice: enabled),
    );
    await _appSettings.updateRuntime(settings: settings);
    if (mounted) setState(() {});
  }

  Future<void> _muteAllQuickAudio() async {
    await _mapViewSettings.setNavigationVoiceEnabled(false);
    await _setAiVoiceEnabled(false);
    await _routeExplorer.setVoiceEnabled(false);
    await _navigationVoice.stop();
    if (mounted) setState(() {});
  }

  Future<void> _showAudioQuickControls() async {
    await Future.wait<void>([
      _mapViewSettings.initialize(),
      _routeExplorer.initialize(),
      _appSettings.initialize().then((_) {}),
    ]);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.24),
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setPopupState) {
          final navigationEnabled = _mapViewSettings.navigationVoiceEnabled;
          final aiEnabled = _aiVoiceEnabled;
          final nearbyEnabled = _routeExplorer.settings.voiceEnabled;
          final allMuted =
              !navigationEnabled && !aiEnabled && !nearbyEnabled;

          Future<void> updateAndRefresh(Future<void> operation) async {
            await operation;
            if (!dialogContext.mounted) return;
            setPopupState(() {});
            if (mounted) setState(() {});
          }

          final dialogHeight = MediaQuery.sizeOf(dialogContext).height;
          final dialogPadding = MediaQuery.paddingOf(dialogContext);
          final maxHeight = math
              .max(240.0, dialogHeight - dialogPadding.vertical - 32.0)
              .toDouble();
          return Dialog(
            alignment: Alignment.centerRight,
            insetPadding: const EdgeInsets.fromLTRB(24, 16, 14, 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 330, maxHeight: maxHeight),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.volume_up_rounded, size: 22),
                          const SizedBox(width: 9),
                          const Expanded(
                            child: Text(
                              'Áudio do mapa',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Fechar',
                            visualDensity: VisualDensity.compact,
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      _QuickAudioSwitch(
                        icon: Icons.navigation_rounded,
                        title: 'Navegação',
                        subtitle: 'Manobras, recálculo e orientação da rota',
                        value: navigationEnabled,
                        onChanged: (value) => unawaited(
                          updateAndRefresh(
                            _mapViewSettings.setNavigationVoiceEnabled(value),
                          ),
                        ),
                      ),
                      _QuickAudioSwitch(
                        icon: Icons.visibility_rounded,
                        title: 'IA / Detecções',
                        subtitle: 'Alertas falados do monitoramento',
                        value: aiEnabled,
                        onChanged: (value) => unawaited(
                          updateAndRefresh(_setAiVoiceEnabled(value)),
                        ),
                      ),
                      _QuickAudioSwitch(
                        icon: Icons.location_on_rounded,
                        title: 'Pontos próximos',
                        subtitle: 'Avisos falados de locais no caminho',
                        value: nearbyEnabled,
                        onChanged: (value) => unawaited(
                          updateAndRefresh(
                            _routeExplorer.setVoiceEnabled(value),
                          ),
                        ),
                      ),
                      const Divider(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton.icon(
                              onPressed: allMuted
                                  ? null
                                  : () => unawaited(
                                        updateAndRefresh(
                                          _muteAllQuickAudio(),
                                        ),
                                      ),
                              icon: const Icon(
                                Icons.volume_off_rounded,
                                size: 18,
                              ),
                              label: const Text('Silenciar tudo'),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextButton.icon(
                              onPressed: () {
                                Navigator.of(dialogContext).pop();
                                unawaited(
                                  Navigator.of(context)
                                      .push<void>(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              const AudioSettingsScreen(),
                                        ),
                                      )
                                      .then((_) {
                                        if (mounted) setState(() {});
                                      }),
                                );
                              },
                              icon: const Icon(Icons.tune_rounded, size: 18),
                              label: const Text('Configurações'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
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
                final filtered = service.activeResults
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
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: [
                          for (final item in _MapPoiQuickFilter.values) ...[
                            ChoiceChip(
                              label: Text(_poiFilterLabel(item)),
                              selected: filter == item,
                              visualDensity: const VisualDensity(
                                horizontal: -2,
                                vertical: -3,
                              ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
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
                              onPressed: service.loading || service.activeResults.isEmpty
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
                      child: service.error != null && service.activeResults.isEmpty
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
                                          item.subtitle.trim().isEmpty
                                              ? '${item.category.label} · ${item.source == 'offline' ? 'Offline' : 'Online'}'
                                              : '${item.category.label} · ${item.source == 'offline' ? 'Offline' : 'Online'}\n${item.subtitle}',
                                          maxLines: 2,
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
    final poiItemsForMap = <RouteExplorerResult>[...visiblePois];
    if (selectedPoi != null &&
        !poiItemsForMap.any((item) => item.id == selectedPoi.id)) {
      poiItemsForMap.add(selectedPoi);
    }
    final poiClusters = MapPoiDisplayPolicy.clusters(
      items: poiItemsForMap,
      zoom: _visibleMapZoom,
      selectedId: _selectedPoiId,
    );
    final onlineLayer = _onlineMapLayerSpec;
    final activeOffline = _offlineMaps.activePackage;
    final outsideOfflineArea = activeOffline != null &&
        current != null &&
        !activeOffline.contains(
          latitude: current.latitude,
          longitude: current.longitude,
        );
    final navigationMatchesSelectedPoi =
        _navigationMatchesSelectedPoi(selectedPoi, navigationTarget);
    final showSelectedPoiCard = selectedPoi != null && !navigationMatchesSelectedPoi;

    final offlineProvider = _offlineTileProvider;
    final mode = _offlineMaps.mode;
    final networkOffline = _connectivity.isOffline;
    final useOnline = mode != OfflineMapMode.offline && !networkOffline;
    final useOfflineLayer = offlineProvider != null &&
        (mode != OfflineMapMode.online || networkOffline);
    final canRenderNavigation3d = navigationTarget != null &&
        _cyclingRoute != null &&
        useOnline;
    final navigation3dRequested = _navigation3dEnabled &&
        canRenderNavigation3d &&
        !_navigation3dRendererFailed;
    final navigation3dActive =
        navigation3dRequested && _navigation3dRendererReady;
    final stadiaVectorStyle = _offlineMaps.stadiaVectorStyleUrl('outdoors');
    final navigation3dStyleUrl =
        stadiaVectorStyle ?? _openFreeMapVectorStyleUrl;
    final navigation3dAttribution = stadiaVectorStyle != null
        ? '© Stadia Maps · © OpenMapTiles · © OpenStreetMap contributors'
        : _openFreeMapAttribution;
    final topInset = safePadding.top + MapUxPolicy.controlEdge;
    final bottomInset = safePadding.bottom + MapUxPolicy.controlEdge;
    final navigationAudioEnabled = _mapViewSettings.navigationVoiceEnabled;
    final aiAudioEnabled = _aiVoiceEnabled;
    final nearbyAudioEnabled = _routeExplorer.settings.voiceEnabled;
    final enabledAudioChannels = <bool>[
      navigationAudioEnabled,
      aiAudioEnabled,
      nearbyAudioEnabled,
    ].where((value) => value).length;
    final quickAudioIcon = enabledAudioChannels == 0
        ? Icons.volume_off_rounded
        : enabledAudioChannels == 3
            ? Icons.volume_up_rounded
            : Icons.volume_down_rounded;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiService.mapOverlayStyle,
      child: Scaffold(
        extendBody: true,
        backgroundColor: Colors.black,
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
          final telemetryTop = topInset + MapUxPolicy.controlSize + 8;
          final telemetryHeight = compactHud ? 42.0 : 48.0;
          final nearbyTop = telemetryTop + telemetryHeight + 8;
          final nearbyHeight = compactHud ? 52.0 : 58.0;
          final cameraButtonTop = nearbyTop + nearbyHeight + 8;
          final controlDockTop = cameraButtonTop;
          final attributionBottom = MapUxPolicy.attributionBottom(
            safeBottom: safePadding.bottom,
            hasSelectedPoi: showSelectedPoiCard,
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
                    flags: InteractiveFlag.all,
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
                  onPositionChanged: (camera, hasGesture) {
                    if (!mounted) return;
                    final zoomChanged =
                        (_visibleMapZoom - camera.zoom).abs() >= 0.20;
                    final shouldReleaseFollow = hasGesture && _followPosition;
                    if (!zoomChanged && !shouldReleaseFollow) return;
                    setState(() {
                      if (zoomChanged) _visibleMapZoom = camera.zoom;
                      if (shouldReleaseFollow) {
                        _followPosition = false;
                        _quickView = null;
                        _customFollowZoom = null;
                      }
                    });
                  },
                  onTap: (_, _) {
                    if (_selectedPoiId != null) {
                      setState(() => _selectedPoiId = null);
                    }
                  },
                ),
                children: [
                  if (useOfflineLayer)
                    TileLayer(
                      key: ValueKey<String>(
                        'offline-${_offlineTilePackageId ?? 'active'}',
                      ),
                      tileProvider: offlineProvider,
                      tileDisplay: TileDisplay.instantaneous(opacity: 1),
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
                  if (_cyclingRouteAlternatives.isNotEmpty)
                    PolylineLayer(
                      polylines: <Polyline>[
                        for (var index = 0;
                            index < _cyclingRouteAlternatives.length;
                            index++)
                          if (index != _selectedCyclingRouteIndex)
                            Polyline(
                              points: _cyclingRouteAlternatives[index].points,
                              strokeWidth: 4,
                              color: scheme.outline.withValues(alpha: 0.55),
                            ),
                        if (_cyclingRoute != null)
                          Polyline(
                            points: _cyclingRoute!.points,
                            strokeWidth: 6,
                            color: scheme.tertiary,
                          ),
                      ],
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
                      for (final cluster in poiClusters)
                        Marker(
                          point: LatLng(cluster.latitude, cluster.longitude),
                          width: cluster.isCluster
                              ? 44
                              : cluster.first.id == _selectedPoiId
                                  ? 48
                                  : 38,
                          rotate: true,
                          height: cluster.isCluster
                              ? 44
                              : cluster.first.id == _selectedPoiId
                                  ? 48
                                  : 38,
                          child: Semantics(
                            button: true,
                            label: cluster.isCluster
                                ? '${cluster.count} pontos próximos'
                                : '${cluster.first.title}, '
                                    '${_routeExplorer.formatDistance(cluster.first.distanceMeters)}',
                            child: GestureDetector(
                              onTap: () => _focusPoiCluster(cluster),
                              child: Builder(
                                builder: (context) {
                                  final categoryColor = _poiColor(cluster.category);
                                  final selected = !cluster.isCluster &&
                                      cluster.first.id == _selectedPoiId;
                                  return Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: cluster.isCluster || selected
                                          ? categoryColor.withValues(alpha: 0.96)
                                          : scheme.surface.withValues(alpha: 0.94),
                                      border: Border.all(
                                        color: cluster.isCluster || selected
                                            ? Colors.white
                                            : categoryColor,
                                        width: selected ? 3 : 2,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          blurRadius: 6,
                                          color: Color(0x40000000),
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: cluster.isCluster
                                        ? Text(
                                            '${cluster.count}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          )
                                        : Icon(
                                            _poiIcon(cluster.category),
                                            size: selected ? 23 : 18,
                                            color: selected
                                                ? Colors.white
                                                : categoryColor,
                                          ),
                                  );
                                },
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
              if (navigation3dRequested)
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: !navigation3dActive,
                    child: AnimatedOpacity(
                      opacity: navigation3dActive ? 1 : 0,
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      child: MapNavigation3DView(
                        key: ValueKey<String>(
                          'nav3d-${navigationTarget.sourceId ?? navigationTarget.label}-${navigationTarget.travelMode.storageValue}-${stadiaVectorStyle != null ? 'stadia' : 'openfreemap'}',
                        ),
                        target: navigationTarget,
                        route: _cyclingRoute!,
                        current: current,
                        orientationMode: _mapViewSettings.orientationMode,
                        sensorHeadingDegrees: _sensorHeadingDegrees,
                        distanceToNextManeuverMeters:
                            _navigationProgress?.distanceToNextManeuverMeters,
                        vectorStyleUrl: navigation3dStyleUrl,
                        fallbackVectorStyleUrl: stadiaVectorStyle != null
                            ? _openFreeMapVectorStyleUrl
                            : null,
                        vectorAttribution: navigation3dAttribution,
                        recenterRequest: _navigation3dRecenterRequest,
                        onReady: _handleNavigation3dReady,
                        onFallback: _handleNavigation3dFallback,
                        onFollowStateChanged:
                            _handleNavigation3dFollowChanged,
                      ),
                    ),
                  ),
                ),

              // Scrims muito leves mantêm os ícones do Android legíveis sobre
              // tiles claros sem criar uma barra sólida nem reduzir o mapa.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: safePadding.top + 54,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.black.withValues(alpha: 0.36),
                          Colors.black.withValues(alpha: 0.10),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: safePadding.bottom + 18,
                child: IgnorePointer(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.10),
                  ),
                ),
              ),

              // O mapa permanece sob as áreas do sistema; somente os controles
              // respeitam notch/status/navigation bar para evitar faixas vazias.
              Positioned(
                top: topInset,
                left: MapUxPolicy.controlEdge,
                child: _MapControlButton(
                  tooltip: 'Configurações do mapa',
                  icon: Icons.settings_rounded,
                  onPressed: () => unawaited(_showMapOptions()),
                ),
              ),
              Positioned(
                top: topInset,
                left: MapUxPolicy.controlEdge + MapUxPolicy.controlSize + 6,
                right: MapUxPolicy.controlEdge + MapUxPolicy.controlSize + 6,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: navigation3dActive
                      ? _Navigation3DModePill(
                          mode: navigationTarget.travelMode,
                          compact: compactHud,
                        )
                      : _MapQuickViewBar(
                          selected: _quickView,
                          routeAvailable: _routeState.route.length >= 2 ||
                              navigationTarget != null,
                          onSelected: _selectQuickView,
                          compact: compactHud,
                        ),
                ),
              ),
              Positioned(
                top: topInset,
                right: MapUxPolicy.controlEdge,
                child: _MapControlButton(
                  tooltip: 'Camadas e tipo do mapa',
                  icon: Icons.layers_rounded,
                  active: offlineProvider != null || networkOffline,
                  onPressed: () {
                    if (navigation3dActive) {
                      setState(() => _navigation3dEnabled = false);
                    }
                    unawaited(_showLayerPicker());
                  },
                ),
              ),
              Positioned(
                top: telemetryTop,
                left: MapUxPolicy.controlEdge,
                right: MapUxPolicy.controlEdge,
                height: telemetryHeight,
                child: _MapTelemetryStrip(
                  speedKmh: MapTelemetryPolicy.currentSpeedKmh(current),
                  altitudeMeters: current?.altitudeMeters,
                  headingDegrees: _displayHeadingFor(current).headingDegrees,
                  gpsAccuracyMeters:
                      MapTelemetryPolicy.validAccuracyMeters(current?.accuracyMeters),
                  orientationMode: _mapViewSettings.orientationMode,
                  onSpeedTap: () => unawaited(_showSpeedDetails()),
                  onAltitudeTap: () => unawaited(_showAltitudeDetails()),
                  onCompassTap: () => unawaited(_showCompassDetails()),
                  onGpsTap: () => unawaited(_showGpsDetails()),
                  compact: compactHud,
                ),
              ),
              Positioned(
                top: nearbyTop,
                left: MapUxPolicy.controlEdge,
                right: MapUxPolicy.controlEdge,
                height: nearbyHeight,
                child: _NearbyPointsBanner(
                  count: _routeExplorer.activeResults.length,
                  loading: _routeExplorer.loading,
                  offline: _routeExplorer.lastSource == 'offline' || networkOffline,
                  onTap: () => unawaited(_showNearbyPoints()),
                ),
              ),
              if (outsideOfflineArea && mode != OfflineMapMode.online)
                Positioned(
                  top: cameraButtonTop + MapUxPolicy.controlSize + 6,
                  left: MapUxPolicy.controlEdge,
                  child: _OfflineAreaWarning(
                    onTap: () => unawaited(_openOfflineMaps()),
                  ),
                ),
              Positioned(
                top: cameraButtonTop,
                left: MapUxPolicy.controlEdge,
                child: _MapControlButton(
                  tooltip: _hasCameraOverlay
                      ? 'Câmeras sobre o mapa'
                      : 'Adicionar câmera ao mapa',
                  icon: Icons.camera_alt_rounded,
                  active: _hasCameraOverlay && _camerasVisible,
                  onPressed: () => unawaited(
                    _hasCameraOverlay &&
                            (!_camerasVisible || _allCameraSlotsHidden)
                        ? _showCameraOverlayQuickly()
                        : _showCameraManager(),
                  ),
                ),
              ),
              Positioned(
                top: horizontalControls ? null : controlDockTop,
                right: MapUxPolicy.controlEdge,
                bottom: horizontalControls ? bottomInset + 52 : null,
                child: Flex(
                  direction:
                      horizontalControls ? Axis.horizontal : Axis.vertical,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (canRenderNavigation3d)
                      _MapControlButton(
                        tooltip: navigation3dActive
                            ? 'Voltar ao mapa 2D'
                            : 'Entrar na navegação 3D',
                        icon: navigation3dActive
                            ? Icons.map_rounded
                            : Icons.view_in_ar_rounded,
                        active: navigation3dActive,
                        onPressed: _toggleNavigation3d,
                      ),
                    if (canRenderNavigation3d)
                      _MapControlGap(horizontal: horizontalControls),
                    _MapControlButton(
                      tooltip: enabledAudioChannels == 0
                          ? 'Áudio do mapa silenciado'
                          : 'Áudio do mapa',
                      icon: quickAudioIcon,
                      active: enabledAudioChannels > 0,
                      onPressed: () => unawaited(_showAudioQuickControls()),
                    ),
                    if (navigation3dActive && !_navigation3dFollowing) ...[
                      _MapControlGap(horizontal: horizontalControls),
                      _MapControlButton(
                        tooltip: 'Centralizar e retomar acompanhamento 3D',
                        icon: Icons.my_location_rounded,
                        active: false,
                        onPressed:
                            current == null ? null : _recenterNavigation3d,
                      ),
                    ],
                    if (!navigation3dActive) ...[
                      _MapControlGap(horizontal: horizontalControls),
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
                        tooltip: 'Próximos pontos',
                        icon: Icons.location_on_rounded,
                        badge: _routeExplorer.activeResults.isEmpty
                            ? null
                            : '${_routeExplorer.activeResults.length}',
                        active: _routeExplorer.activeResults.isNotEmpty,
                        onPressed: () => unawaited(_showNearbyPoints()),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                left: MapUxPolicy.controlEdge,
                bottom: attributionBottom,
                child: _MapAttribution(
                  text: navigation3dActive
                      ? '3D · $navigation3dAttribution'
                      : (mode == OfflineMapMode.offline ||
                              (networkOffline && useOfflineLayer))
                          ? (activeOffline?.providerId == 'stadia-alidade-smooth'
                              ? '© Stadia Maps · © OpenMapTiles · © OpenStreetMap contributors'
                              : 'Mapa offline · licença do pacote')
                          : onlineLayer.attribution,
                ),
              ),
              if (showSelectedPoiCard)
                Positioned(
                  left: compactHud ? 10 : 36,
                  right: compactHud ? 10 : 36,
                  bottom: bottomInset + (navigationTarget == null ? 82 : 164),
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
                  left: 8,
                  right: 8,
                  bottom: bottomInset + 74,
                  child: _NavigationBanner(
                    target: navigationTarget,
                    distanceMeters: _routeState.navigationDistanceMeters,
                    bearingDegrees: _routeState.navigationBearingDegrees,
                    roadRoute: _cyclingRoute,
                    routeAlternatives: _cyclingRouteAlternatives,
                    selectedRouteIndex: _selectedCyclingRouteIndex,
                    guidance: _navigationProgress,
                    loadingRoadRoute: _cyclingRouteLoading,
                    fallbackMessage: _routeFallback?.message,
                    networkOffline: networkOffline,
                    compact: compactHud,
                    onRouteSelected: _selectCyclingRoute,
                    onStop: _stopNavigation,
                  ),
                ),
              Positioned(
                right: MapUxPolicy.controlEdge,
                bottom: bottomInset + 2,
                child: _RouteButtonBar(
                  recording: _routeState.recording,
                  paused: _routeState.paused,
                  hasRoute: _routeState.route.length >= 2,
                  routeState: _routeState,
                  distanceLabel: _formatDistance(),
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
      final navigationTarget = _routeState.navigationTarget;
      final effectiveScale = MapUxPolicy.cameraEffectiveScale(
        savedScale: layout.sizeScale,
        hasNavigation: navigationTarget != null,
        compactHud: MapUxPolicy.compactHud(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
        ),
      );
      late double width;
      late double height;
      if (minimized) {
        width = 44;
        height = 44;
      } else if (aspectRatio >= 1) {
        final baseWidth =
            (constraints.maxWidth * 0.29).clamp(126.0, 190.0).toDouble();
        width = (baseWidth * effectiveScale)
            .clamp(104.0, math.min(238.0, constraints.maxWidth * 0.52))
            .toDouble();
        height = (width / aspectRatio).clamp(70.0, 166.0).toDouble();
      } else {
        final baseHeight =
            (constraints.maxHeight * 0.22).clamp(118.0, 188.0).toDouble();
        height = (baseHeight * effectiveScale)
            .clamp(94.0, math.min(228.0, constraints.maxHeight * 0.42))
            .toDouble();
        width = (height * aspectRatio).clamp(76.0, 164.0).toDouble();
      }

      final safePadding = MediaQuery.paddingOf(context);
      const minX = MapUxPolicy.controlEdge;
      final minY = MapUxPolicy.cameraMinY(
        safeTop: safePadding.top,
        compactLandscape: _compactLandscape,
      );
      final selectedPoi = _selectedPoi;
      final bottomReserve = MapUxPolicy.cameraBottomReserve(
        safeBottom: safePadding.bottom,
        hasSelectedPoi: selectedPoi != null &&
            !_navigationMatchesSelectedPoi(selectedPoi, navigationTarget),
        hasNavigation: navigationTarget != null,
      );
      final availableHeight = math.max(
        minimized ? 42.0 : 70.0,
        constraints.maxHeight - minY - bottomReserve,
      ).toDouble();
      if (!minimized && height > availableHeight) {
        height = availableHeight;
        width = math.min(width, height * aspectRatio).toDouble();
      }
      final rightReserve = _compactLandscape
          ? MapUxPolicy.controlEdge
          : MapUxPolicy.controlEdge + MapUxPolicy.controlSize + 6;
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
      final bikeApproach = _bikeApproachForPip(secondary);
      final aiStatus = _aiStatusForPip(secondary);

      Future<void> snapAndPersist() async {
        final current = secondary
            ? (_secondaryCameraOffset ?? position)
            : (_primaryCameraOffset ?? position);
        final otherLayout = secondary ? _primaryCameraLayout : _secondaryCameraLayout;
        final otherVisible = _camerasVisible &&
            _slotHasCamera(!secondary) &&
            !otherLayout.hidden;
        final snap = MapUxPolicy.cameraSnapPoint(
          xFraction: MapUxPolicy.fractionForPosition(
            position: current.dx,
            min: minX,
            max: maxX,
          ),
          yFraction: MapUxPolicy.fractionForPosition(
            position: current.dy,
            min: minY,
            max: maxY,
          ),
          compactLandscape: _compactLandscape,
          otherXFraction: otherVisible ? otherLayout.xFraction : null,
          otherYFraction: otherVisible ? otherLayout.yFraction : null,
        );
        final snapped = Offset(
          MapUxPolicy.positionForFraction(
            fraction: snap.xFraction,
            min: minX,
            max: maxX,
          ),
          MapUxPolicy.positionForFraction(
            fraction: snap.yFraction,
            min: minY,
            max: maxY,
          ),
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
          onTap: minimized
              ? () => unawaited(_toggleCameraSlotMinimized(secondary))
              : null,
          onDoubleTap: minimized
              ? null
              : () => unawaited(_cycleCameraSlotSize(secondary)),
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
                ? Tooltip(
                    message: '$label · tocar para expandir',
                    child: Center(
                      child: Icon(
                        secondary ? Icons.filter_2_rounded : Icons.videocam_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
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
                      if (aiStatus != null)
                        Positioned(
                          left: 4,
                          right: 4,
                          top: bikeApproach != null ? 29 : null,
                          bottom: bikeApproach == null ? 4 : null,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: MapAiStatusOverlay(status: aiStatus),
                          ),
                        ),
                      if (bikeApproach != null)
                        Positioned(
                          left: 4,
                          right: 4,
                          bottom: 4,
                          child: MapBikeApproachOverlay(status: bikeApproach),
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
      elevation: 2,
      color: scheme.surface.withValues(alpha: 0.91),
      borderRadius: BorderRadius.circular(16),
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

class _TravelModeChoiceCard extends StatelessWidget {
  const _TravelModeChoiceCard({
    required this.mode,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final MapTravelMode mode;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderColor = selected ? scheme.primary : scheme.outlineVariant;
    final background = selected
        ? scheme.primaryContainer.withValues(alpha: 0.55)
        : scheme.surfaceContainerLow;
    final foreground = selected ? scheme.onPrimaryContainer : scheme.onSurface;

    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: borderColor,
          width: selected ? 1.7 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 38, color: foreground),
                  const SizedBox(height: 9),
                  Text(
                    mode.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: foreground,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Positioned(
                top: 9,
                right: 9,
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: scheme.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Navigation3DModePill extends StatelessWidget {
  const _Navigation3DModePill({
    required this.mode,
    required this.compact,
  });

  final MapTravelMode mode;
  final bool compact;

  IconData get _modeIcon => switch (mode) {
        MapTravelMode.bicycle => Icons.pedal_bike_rounded,
        MapTravelMode.motorcycle => Icons.two_wheeler_rounded,
        MapTravelMode.car => Icons.directions_car_filled_rounded,
        MapTravelMode.walking => Icons.directions_walk_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 2,
      color: scheme.surface.withValues(alpha: 0.93),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 13,
          vertical: compact ? 7 : 9,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.view_in_ar_rounded,
              size: compact ? 18 : 20,
              color: scheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              'Navegação 3D',
              style: TextStyle(
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w900,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 1,
              height: compact ? 18 : 20,
              color: scheme.outlineVariant,
            ),
            const SizedBox(width: 8),
            Icon(
              _modeIcon,
              size: compact ? 17 : 19,
              color: scheme.secondary,
            ),
            const SizedBox(width: 5),
            Text(
              mode.label,
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w800,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
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
            horizontal: compact ? 7 : 8,
            vertical: 6,
          ),
          color: active ? scheme.primaryContainer : Colors.transparent,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: compact ? 16 : 17, color: foreground),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: compact ? 9.5 : 11,
                  fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAudioSwitch extends StatelessWidget {
  const _QuickAudioSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      dense: true,
      secondary: Icon(icon, size: 20),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11.5),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _NearbyPointsBanner extends StatelessWidget {
  const _NearbyPointsBanner({
    required this.count,
    required this.loading,
    required this.offline,
    required this.onTap,
  });

  final int count;
  final bool loading;
  final bool offline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtitle = loading
        ? 'Atualizando pontos próximos...'
        : count > 0
            ? '$count ponto${count == 1 ? '' : 's'} · ${offline ? 'dados offline' : 'dados online'}'
            : 'Postos, comida, saúde, água, mirantes e outros.';

    return Material(
      elevation: 4,
      color: scheme.surface.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            children: [
              Icon(
                Icons.location_on_rounded,
                size: 24,
                color: scheme.primary,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Locais próximos',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 10.5,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant,
              ),
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
        width: horizontal ? MapUxPolicy.controlGap : 0,
        height: horizontal ? 0 : MapUxPolicy.controlGap,
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
            width: MapUxPolicy.controlSize,
            height: MapUxPolicy.controlSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, color: foreground, size: 20),
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
    final subtitle = item.subtitle.trim().isNotEmpty
        ? item.subtitle.trim()
        : item.category.label;

    return Material(
      elevation: 9,
      color: scheme.surface.withValues(alpha: 0.97),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          compact ? 10 : 12,
          compact ? 9 : 11,
          compact ? 8 : 10,
          compact ? 9 : 11,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: compact ? 18 : 21,
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(
                    icon,
                    size: compact ? 19 : 22,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: onDetails,
                    borderRadius: BorderRadius.circular(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Aprox. $distanceLabel · '
                          '${item.source == 'offline' ? 'Offline' : 'Online'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Fechar',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 34,
                    height: 34,
                  ),
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDetails,
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.info_outline_rounded, size: 18),
                    label: const Text('Detalhes'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onNavigate,
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.navigation_rounded, size: 18),
                    label: const Text('Navegar'),
                  ),
                ),
              ],
            ),
          ],
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

class _TelemetryDetailRow extends StatelessWidget {
  const _TelemetryDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label)),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );
}

class _MapTelemetryStrip extends StatelessWidget {
  const _MapTelemetryStrip({
    required this.speedKmh,
    required this.altitudeMeters,
    required this.headingDegrees,
    required this.gpsAccuracyMeters,
    required this.orientationMode,
    required this.onSpeedTap,
    required this.onAltitudeTap,
    required this.onCompassTap,
    required this.onGpsTap,
    this.compact = false,
  });

  final double? speedKmh;
  final double? altitudeMeters;
  final double? headingDegrees;
  final double? gpsAccuracyMeters;
  final MapOrientationMode orientationMode;
  final VoidCallback onSpeedTap;
  final VoidCallback onAltitudeTap;
  final VoidCallback onCompassTap;
  final VoidCallback onGpsTap;
  final bool compact;

  String _direction(double? degrees) {
    if (degrees == null || degrees.isNaN) return '--';
    const labels = ['N', 'NE', 'L', 'SE', 'S', 'SO', 'O', 'NO'];
    final normalized = ((degrees % 360) + 360) % 360;
    final index = ((normalized + 22.5) ~/ 45) % 8;
    return labels[index];
  }

  @override
  Widget build(BuildContext context) {
    final altitudeValue = altitudeMeters == null
        ? '--'
        : altitudeMeters!.toStringAsFixed(0);
    final gpsValue = gpsAccuracyMeters == null
        ? '--'
        : '±${gpsAccuracyMeters!.toStringAsFixed(0)}';

    return Row(
      children: [
        Expanded(
          child: _MapTelemetryCard(
            icon: Icons.speed_rounded,
            value: speedKmh == null ? '--' : speedKmh!.toStringAsFixed(1),
            unit: speedKmh == null ? null : 'km/h',
            label: 'Velocidade',
            emphasized: true,
            onTap: onSpeedTap,
            tooltip: 'Velocidade: toque para ver detalhes da sessão.',
            compact: compact,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: _MapTelemetryCard(
            icon: Icons.height_rounded,
            value: altitudeValue,
            unit: altitudeMeters == null ? null : 'm',
            label: 'Altitude',
            onTap: onAltitudeTap,
            tooltip: 'Altitude: toque para ver fonte e precisão.',
            compact: compact,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: _MapTelemetryCard(
            icon: Icons.explore_rounded,
            value: _direction(headingDegrees),
            label: 'Bússola',
            emphasized: orientationMode != MapOrientationMode.northUp,
            onTap: onCompassTap,
            tooltip:
                'Bússola: toque para ver direção, fonte e escolher Norte, Direção ou Rota.',
            compact: compact,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: _MapTelemetryCard(
            icon: Icons.gps_fixed_rounded,
            value: gpsValue,
            unit: gpsAccuracyMeters == null ? null : 'm',
            label: 'GPS',
            onTap: onGpsTap,
            tooltip: 'GPS: toque para ver posição e qualidade da leitura.',
            compact: compact,
          ),
        ),
      ],
    );
  }
}

class _MapTelemetryCard extends StatelessWidget {
  const _MapTelemetryCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.compact,
    this.unit,
    this.emphasized = false,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final String value;
  final String? unit;
  final String label;
  final bool compact;
  final bool emphasized;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = emphasized
        ? scheme.primaryContainer.withValues(alpha: 0.94)
        : scheme.surface.withValues(alpha: 0.93);
    final foreground =
        emphasized ? scheme.onPrimaryContainer : scheme.onSurface;
    final iconColor = emphasized ? scheme.onPrimaryContainer : scheme.primary;

    Widget card = Material(
      elevation: 2,
      color: background,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 4 : 5,
            vertical: compact ? 3 : 4,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: compact ? 11 : 12, color: iconColor),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: TextStyle(
                        color: foreground.withValues(alpha: 0.72),
                        fontSize: compact ? 7.5 : 8.2,
                        height: 1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: value,
                        style: TextStyle(
                          color: foreground,
                          fontSize: compact ? 15 : 17,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (unit != null) ...[
                        const TextSpan(text: ' '),
                        TextSpan(
                          text: unit,
                          style: TextStyle(
                            color: foreground.withValues(alpha: 0.74),
                            fontSize: compact ? 7 : 8,
                            height: 1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                  maxLines: 1,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (tooltip != null) card = Tooltip(message: tooltip!, child: card);
    return card;
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
    return Text(
      _format(widget.routeState.elapsed),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _NavigationBanner extends StatelessWidget {
  const _NavigationBanner({
    required this.target,
    required this.distanceMeters,
    required this.bearingDegrees,
    required this.roadRoute,
    required this.routeAlternatives,
    required this.selectedRouteIndex,
    required this.guidance,
    required this.loadingRoadRoute,
    required this.fallbackMessage,
    required this.networkOffline,
    required this.compact,
    required this.onRouteSelected,
    required this.onStop,
  });

  final MapNavigationTarget target;
  final double? distanceMeters;
  final double? bearingDegrees;
  final MapCyclingRoute? roadRoute;
  final List<MapCyclingRoute> routeAlternatives;
  final int selectedRouteIndex;
  final MapNavigationProgress? guidance;
  final bool loadingRoadRoute;
  final String? fallbackMessage;
  final bool networkOffline;
  final bool compact;
  final ValueChanged<int> onRouteSelected;
  final VoidCallback onStop;

  String _distance(double? meters) {
    if (meters == null) return '--';
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _duration(double seconds) {
    final minutes = (seconds / 60).round();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '${hours}h' : '${hours}h ${rest}min';
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
    final travelLabel = target.travelMode.routeLabel;
    final progress = guidance;
    final route = roadRoute;
    final currentInstruction = progress?.arrived == true
        ? 'Destino alcançado'
        : progress?.currentInstruction ?? target.label;

    late final String nextLine;
    if (progress?.arrived == true) {
      nextLine = 'Você chegou ao destino.';
    } else if (fallbackMessage != null) {
      nextLine = fallbackMessage!;
    } else if (loadingRoadRoute && route != null) {
      nextLine = 'Recalculando rota…';
    } else if (route != null &&
        progress != null &&
        progress.nextInstruction != null) {
      nextLine =
          'Em ${_distance(progress.distanceToNextManeuverMeters)}: ${progress.nextInstruction}';
    } else if (loadingRoadRoute) {
      nextLine = 'Calculando rota de $travelLabel…';
    } else if (route != null) {
      nextLine = 'Siga pela rota destacada até o destino.';
    } else {
      nextLine =
          '${_distance(distanceMeters)} · ${_bearing(bearingDegrees)} · direção direta';
    }

    late final String summaryLine;
    if (route != null && progress != null) {
      final routeLabel = routeAlternatives.length > 1
          ? 'Rota ${selectedRouteIndex + 1}/${routeAlternatives.length} · '
          : '';
      summaryLine =
          '$routeLabel${_distance(progress.remainingDistanceMeters)} · ${_duration(progress.remainingDurationSeconds)} restantes · ${(progress.progressFraction * 100).round()}%';
    } else if (route != null) {
      final routeLabel = routeAlternatives.length > 1
          ? 'Rota ${selectedRouteIndex + 1}/${routeAlternatives.length} · '
          : '';
      summaryLine =
          '$routeLabel${_distance(route.distanceMeters)} · ${_duration(route.durationSeconds)} · $travelLabel';
    } else {
      summaryLine = 'Destino: ${target.label}';
    }

    final warning = fallbackMessage != null || networkOffline;
    final background = warning
        ? scheme.secondaryContainer.withValues(alpha: 0.96)
        : scheme.tertiaryContainer.withValues(alpha: 0.95);
    final foreground = warning
        ? scheme.onSecondaryContainer
        : scheme.onTertiaryContainer;
    return Center(
      child: Material(
        elevation: 6,
        color: background,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 9 : 11,
            compact ? 6 : 7,
            4,
            compact ? 6 : 7,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                networkOffline
                    ? Icons.wifi_off_rounded
                    : progress?.offRoute == true
                        ? Icons.alt_route_rounded
                        : Icons.navigation_rounded,
                size: compact ? 18 : 20,
                color: foreground,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentInstruction,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontSize: compact ? 12 : 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      nextLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontSize: compact ? 10 : 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      summaryLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground.withValues(alpha: 0.82),
                        fontSize: compact ? 9 : 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (routeAlternatives.length > 1)
                PopupMenuButton<int>(
                  tooltip: 'Escolher rota alternativa',
                  initialValue: selectedRouteIndex,
                  onSelected: onRouteSelected,
                  itemBuilder: (context) => <PopupMenuEntry<int>>[
                    for (var index = 0;
                        index < routeAlternatives.length;
                        index++)
                      PopupMenuItem<int>(
                        value: index,
                        child: Row(
                          children: [
                            Icon(
                              index == selectedRouteIndex
                                  ? Icons.check_circle_rounded
                                  : Icons.alt_route_rounded,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Rota ${index + 1} · ${_distance(routeAlternatives[index].distanceMeters)} · ${_duration(routeAlternatives[index].durationSeconds)}',
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  icon: const Icon(Icons.alt_route_rounded),
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
    required this.routeState,
    required this.distanceLabel,
    required this.onToggleRecording,
    required this.onTogglePause,
    required this.onExport,
  });

  final bool recording;
  final bool paused;
  final bool hasRoute;
  final MapRouteService routeState;
  final String distanceLabel;
  final VoidCallback? onToggleRecording;
  final VoidCallback? onTogglePause;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 7,
      color: scheme.surface.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: recording
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: paused ? 'Continuar percurso' : 'Pausar percurso',
                        onPressed: onTogglePause,
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
                        icon: Icon(
                          paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                          size: 20,
                        ),
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: paused ? scheme.tertiary : scheme.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _LiveRouteElapsedPill(routeState: routeState),
                      const SizedBox(width: 8),
                      Text(
                        distanceLabel,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 3),
                      TextButton.icon(
                        onPressed: onToggleRecording,
                        style: TextButton.styleFrom(
                          foregroundColor: scheme.error,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        icon: const Icon(Icons.stop_rounded, size: 18),
                        label: const Text('Encerrar'),
                      ),
                    ],
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: onToggleRecording,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      ),
                      icon: Icon(Icons.fiber_manual_record_rounded, size: 16, color: scheme.error),
                      label: const Text('Gravar'),
                    ),
                    if (hasRoute)
                      IconButton(
                        tooltip: 'Exportar GPX',
                        onPressed: onExport,
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
                        icon: const Icon(Icons.file_upload_outlined, size: 19),
                      ),
                  ],
                ),
    );
  }
}
