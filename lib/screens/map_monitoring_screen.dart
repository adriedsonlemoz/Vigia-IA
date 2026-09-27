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
import '../models/bike_sensor_snapshot.dart';
import '../models/bike_trip_plan.dart';
import '../models/camera_endpoint.dart';
import '../models/map_connectivity_status.dart';
import '../models/map_destination_search.dart';
import '../models/map_navigation_target.dart';
import '../models/map_travel_mode.dart';
import '../models/monitor_ai_pip_status.dart';
import '../models/map_cycling_route.dart';
import '../models/map_route_point.dart';
import '../models/map_weather.dart';
import '../models/offline_map_package.dart';
import '../models/offline_poi_package.dart';
import '../models/route_explorer_models.dart';
import '../models/video_source_config.dart';
import '../services/app_settings_service.dart';
import '../services/bike_mode_service.dart';
import '../services/bike_pressure_safety_service.dart';
import '../services/bike_sensor_service.dart';
import '../services/bike_ride_history_service.dart';
import '../services/bike_trip_planner.dart';
import '../services/camera_registry_service.dart';
import '../services/location_tracking_service.dart';
import '../services/error_log_service.dart';
import '../services/map_camera_overlay_settings_service.dart';
import '../services/map_bike_consolidation_policy.dart';
import '../services/map_appearance_policy.dart';
import '../services/map_connectivity_service.dart';
import '../services/map_destination_search_service.dart';
import '../services/map_compass_service.dart';
import '../services/map_cycling_route_service.dart';
import '../services/map_gps_filter.dart';
import '../services/map_navigation_guidance.dart';
import '../services/map_navigation_voice_service.dart';
import '../services/map_offline_navigation_policy.dart';
import '../services/map_poi_display_policy.dart';
import '../services/map_route_service.dart';
import '../services/map_telemetry_policy.dart';
import '../services/map_weather_policy.dart';
import '../services/map_weather_service.dart';
import '../services/map_voice_service.dart';
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
import '../widgets/map_telemetry_panel.dart';

part 'map_monitoring_offline_support.dart';

enum _MapPoiQuickFilter { all, fuel, food, health, water, nature, travel, other }

enum _MapQuickView { near, region, route }

enum _CameraPipMenuAction { source, size, minimize, hide }

class _BikeTravelSelection {
  const _BikeTravelSelection({
    required this.preferences,
    required this.useHistoricalSpeed,
  });

  final BikeTravelPreferences preferences;
  final bool useHistoricalSpeed;
}

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
  final BikeTripPlanner _bikeTripPlanner = const BikeTripPlanner();
  final BikeRideHistoryService _bikeRideHistory = BikeRideHistoryService.instance;
  final BikeModeService _bikeMode = BikeModeService.instance;
  final BikeSensorService _bikeSensors = BikeSensorService.instance;
  final BikePressureSafetyService _bikePressureSafety =
      BikePressureSafetyService.instance;
  final MapNavigationVoiceService _navigationVoice = MapNavigationVoiceService();
  MapCyclingRoute? _cyclingRoute;
  List<MapCyclingRoute> _cyclingRouteAlternatives = const <MapCyclingRoute>[];
  int _selectedCyclingRouteIndex = 0;
  MapNavigationProgress? _navigationProgress;
  BikeTripEstimate? _bikeTripEstimate;
  BikeTripPlan? _bikeTripPlan;
  bool _bikeTripPlanLoading = false;
  bool _cyclingRouteLoading = false;
  int _cyclingRouteRequestSerial = 0;
  int _offRouteSamples = 0;
  DateTime? _lastRouteRecalculatedAt;
  DateTime? _lastNavigationProgressPointAt;
  final NativePlatformService _native = NativePlatformService.instance;
  final AppSettingsService _appSettings = AppSettingsService.instance;
  final RouteExplorerService _routeExplorer = RouteExplorerService.instance;
  final MapConnectivityService _connectivity = MapConnectivityService.instance;
  final MapDestinationSearchService _destinationSearch =
      MapDestinationSearchService.instance;
  final ErrorLogService _logs = ErrorLogService.instance;
  final MapCompassService _compass = const MapCompassService();
  final MapTelemetrySessionTracker _telemetrySession =
      MapTelemetrySessionTracker();
  final MapViewSettingsService _mapViewSettings = MapViewSettingsService.instance;
  final CameraRegistryService _cameraRegistry = CameraRegistryService.instance;
  final MapCameraOverlaySettingsService _cameraOverlaySettings =
      MapCameraOverlaySettingsService.instance;
  final MapWeatherService _weather = MapWeatherService.instance;
  final MapVoiceService _mapVoice = MapVoiceService.instance;

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
  bool _camerasVisible = false;
  bool _stopMapOwnedSourcesWhenHidden = true;
  bool? _fullscreenCameraSecondary;
  bool _navigationPanelMinimized = true;

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
  final ValueNotifier<int> _compassPanelTick = ValueNotifier<int>(0);
  MapCompassReading? _compassReading;
  double? _smoothedSensorHeading;
  _MapPoiQuickFilter _poiFilter = _MapPoiQuickFilter.all;
  String? _selectedPoiId;
  MapDestinationSearchResult? _selectedMapLocation;
  final List<MapDestinationSearchResult> _manualTripStops =
      <MapDestinationSearchResult>[];
  int _mapTapLookupSerial = 0;
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
    _weather.addListener(_onWeatherChanged);
    _bikeRideHistory.addListener(_onBikeRideHistoryChanged);
    _bikeSensors.addListener(_onBikeSensorChanged);
    _bikePressureSafety.addListener(_onBikeSensorChanged);
    _selectedPoiId = widget.initialPointOfInterest?.id;
    unawaited(SystemUiService.edgeToEdge());
    unawaited(_initializeOfflineMaps());
    unawaited(_initializeCameraOverlays());
    unawaited(_connectivity.acquire(this));
    unawaited(_destinationSearch.initialize());
    unawaited(_bikePressureSafety.initialize());
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
    _weather.removeListener(_onWeatherChanged);
    _bikeRideHistory.removeListener(_onBikeRideHistoryChanged);
    _bikeSensors.removeListener(_onBikeSensorChanged);
    _bikePressureSafety.removeListener(_onBikeSensorChanged);
    _connectivity.release(this);
    _routeRecoveryTimer?.cancel();
    unawaited(_compassSubscription?.cancel());
    _compassPanelTick.dispose();
    _offlineTileProvider?.dispose();
    _navigationVoice.resetRoute();
    _mapController.dispose();
    super.dispose();
  }

  static const String _mapLocalBackCameraId = '__map_local_back__';

  bool get _openedFromMonitor =>
      widget.cameraPreviewBuilder != null ||
      widget.secondaryCameraPreviewBuilder != null;

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
      // Entrada direta no mapa começa sem câmera. Câmeras herdadas só existem
      // quando o mapa foi aberto pelo Monitoramento.
      _camerasVisible = _openedFromMonitor
          ? _cameraOverlaySettings.visible
          : false;
      _stopMapOwnedSourcesWhenHidden =
          _cameraOverlaySettings.stopMapOwnedSourcesWhenHidden;
      _primaryCameraLayout = _cameraOverlaySettings.primary;
      _secondaryCameraLayout = _cameraOverlaySettings.secondary;
    });
  }

  void _onBikeSensorChanged() {
    if (!mounted) return;
    setState(() {});
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

  bool _shouldRunMapOwnedCamera(bool secondary) {
    if (!_appActive) return false;
    if (secondary ? _secondaryUsesExternal : _primaryUsesExternal) return false;
    if (!_slotHasCamera(secondary)) return false;
    if (!_stopMapOwnedSourcesWhenHidden) return true;
    final layout = secondary ? _secondaryCameraLayout : _primaryCameraLayout;
    return _camerasVisible && !layout.hidden && !layout.minimized;
  }

  Future<void> _syncMapOwnedCameraRuntime(bool secondary) async {
    final controller = secondary ? _secondaryMapCamera : _primaryMapCamera;
    if (controller == null) return;
    if (_shouldRunMapOwnedCamera(secondary)) {
      await controller.resume();
    } else {
      await controller.suspend();
    }
  }

  Future<void> _resumeVisibleInternalCameras() async {
    await _syncMapOwnedCameraRuntime(false);
    await _syncMapOwnedCameraRuntime(true);
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

    if (source == null && !useExternal && _fullscreenCameraSecondary == secondary) {
      _fullscreenCameraSecondary = null;
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
    if (source != null || useExternal) {
      _camerasVisible = true;
      await _cameraOverlaySettings.saveVisible(true);
    }
    if (mounted) setState(() {});
    if (next != null) {
      await _syncMapOwnedCameraRuntime(secondary);
    }
  }

  Future<void> _setCameraSlotHidden(bool secondary, bool hidden) async {
    if (hidden && _fullscreenCameraSecondary == secondary) {
      _fullscreenCameraSecondary = null;
    }
    if (secondary) {
      _secondaryCameraLayout = _secondaryCameraLayout.copyWith(hidden: hidden);
      await _cameraOverlaySettings.saveSecondary(_secondaryCameraLayout);
      await _syncMapOwnedCameraRuntime(true);
    } else {
      _primaryCameraLayout = _primaryCameraLayout.copyWith(hidden: hidden);
      await _cameraOverlaySettings.savePrimary(_primaryCameraLayout);
      await _syncMapOwnedCameraRuntime(false);
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleCameraSlotMinimized(bool secondary) async {
    final layout = secondary ? _secondaryCameraLayout : _primaryCameraLayout;
    final minimized = !layout.minimized;
    if (secondary) {
      _secondaryCameraLayout = layout.copyWith(minimized: minimized, hidden: false);
      await _cameraOverlaySettings.saveSecondary(_secondaryCameraLayout);
      await _syncMapOwnedCameraRuntime(true);
    } else {
      _primaryCameraLayout = layout.copyWith(minimized: minimized, hidden: false);
      await _cameraOverlaySettings.savePrimary(_primaryCameraLayout);
      await _syncMapOwnedCameraRuntime(false);
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
      await _syncMapOwnedCameraRuntime(true);
    } else {
      _primaryCameraLayout = updated;
      _primaryCameraOffset = null;
      await _cameraOverlaySettings.savePrimary(updated);
      await _syncMapOwnedCameraRuntime(false);
    }
    if (mounted) setState(() {});
  }

  void _openCameraFullscreen(bool secondary) {
    if (!_slotHasCamera(secondary)) return;
    final layout = secondary ? _secondaryCameraLayout : _primaryCameraLayout;
    if (layout.hidden || layout.minimized || !_camerasVisible) return;
    setState(() => _fullscreenCameraSecondary = secondary);
  }

  void _closeCameraFullscreen() {
    if (_fullscreenCameraSecondary == null) return;
    setState(() => _fullscreenCameraSecondary = null);
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
    await Future.wait<void>([
      _cameraOverlaySettings.initialize(),
      _cameraRegistry.initialize(),
    ]);
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
    await Future.wait<void>([
      _cameraOverlaySettings.initialize(),
      _cameraRegistry.initialize(),
    ]);
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
                    subtitle: Text(
                      hasCamera
                          ? (layout.hidden
                              ? ((secondary ? _secondaryUsesExternal : _primaryUsesExternal)
                                  ? 'Oculta · fonte controlada pelo Monitoramento'
                                  : _stopMapOwnedSourcesWhenHidden
                                      ? 'Oculta · fonte encerrada para economizar bateria'
                                      : 'Oculta · fonte mantida ativa')
                              : layout.minimized
                                  ? ((secondary ? _secondaryUsesExternal : _primaryUsesExternal)
                                      ? 'Minimizada · fonte controlada pelo Monitoramento'
                                      : _stopMapOwnedSourcesWhenHidden
                                          ? 'Minimizada · fonte encerrada para economizar bateria'
                                          : 'Minimizada · fonte mantida ativa')
                                  : 'Visível sobre o mapa')
                          : 'Nenhuma fonte selecionada',
                    ),
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
                    'Escolha fontes e organize os PiPs. Arraste para encaixar, toque na imagem para abrir em tela inteira e use Tamanho para alternar o porte; posição e tamanho ficam salvos.',
                  ),
                  const SizedBox(height: 12),
                  slotTile(false),
                  slotTile(true),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: _camerasVisible,
                    title: const Text('Mostrar PiPs no mapa'),
                    subtitle: Text(
                      _openedFromMonitor
                          ? 'As câmeras herdadas do Monitor continuam sob controle do Monitoramento.'
                          : 'Ao entrar diretamente no mapa, nenhuma câmera é iniciada automaticamente.',
                    ),
                    onChanged: (value) async {
                      setState(() {
                        _camerasVisible = value;
                        if (!value) _fullscreenCameraSecondary = null;
                      });
                      setSheetState(() {});
                      await _cameraOverlaySettings.saveVisible(value);
                      await _resumeVisibleInternalCameras();
                    },
                  ),
                  SwitchListTile(
                    value: _stopMapOwnedSourcesWhenHidden,
                    title: const Text('Economizar bateria ao ocultar câmera'),
                    subtitle: const Text(
                      'Encerra a fonte aberta pelo mapa ao ocultar ou minimizar o PiP. Fontes herdadas do Monitoramento não são encerradas pelo mapa.',
                    ),
                    onChanged: (value) async {
                      setState(() => _stopMapOwnedSourcesWhenHidden = value);
                      setSheetState(() {});
                      await _cameraOverlaySettings
                          .saveStopMapOwnedSourcesWhenHidden(value);
                      await _resumeVisibleInternalCameras();
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
      _weather.initialize(),
      _bikeRideHistory.initialize(),
      _bikeMode.initialize().then((_) {}),
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
      final weatherPoint = _routeState.current!;
      unawaited(
        _weather.refreshForLocation(
          latitude: weatherPoint.latitude,
          longitude: weatherPoint.longitude,
        ),
      );
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

  void _onWeatherChanged() {
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
      unawaited(
        _weather.refreshForLocation(
          latitude: current!.latitude,
          longitude: current.longitude,
        ),
      );
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
    _compassPanelTick.value += 1;
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

  void _onBikeRideHistoryChanged() {
    if (!mounted) return;
    setState(() {});
    final target = _routeState.navigationTarget;
    final route = _cyclingRoute;
    if (target != null &&
        target.travelMode == MapTravelMode.bicycle &&
        route != null) {
      unawaited(_refreshBikeTripPlan(route: route, target: target));
    }
  }

  BikeTravelPreferences get _effectiveBikeTravelPreferences {
    final manual = _mapViewSettings.bikeTravelPreferences;
    final history = _bikeRideHistory.summary;
    final learnedSpeed = history.learnedMovingSpeedKmh;
    if (!_mapViewSettings.bikeUseHistoricalSpeed ||
        !history.reliable ||
        learnedSpeed == null ||
        !learnedSpeed.isFinite) {
      return manual;
    }
    return manual.copyWith(averageSpeedKmh: learnedSpeed);
  }

  Future<void> _startRecording() async {
    _routeExplorer.resetAnnouncementSession();
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

  Future<void> _finishRecording() async {
    final segments = _routeState.routeSegments;
    final distanceMeters = _routeState.distanceMeters;
    final elapsedDuration = _routeState.elapsed;
    final startedAt = _routeState.routeStartedAt;
    final navigationTarget = _routeState.navigationTarget;

    await _routeState.finishRecording();
    final bikeConfig = await _bikeMode.initialize();
    final shouldLearn = navigationTarget?.travelMode == MapTravelMode.bicycle ||
        (navigationTarget == null &&
            bikeConfig.enabled &&
            _lastTravelMode == MapTravelMode.bicycle);
    if (!shouldLearn || startedAt == null || segments.isEmpty) return;
    final accepted = await _bikeRideHistory.recordRide(
      segments: segments,
      distanceMeters: distanceMeters,
      elapsedDuration: elapsedDuration,
      startedAt: startedAt,
      endedAt: _routeState.routeEndedAt ?? DateTime.now(),
    );
    if (!mounted || !accepted) return;
    final summary = _bikeRideHistory.summary;
    if (summary.reliable && summary.learnedMovingSpeedKmh != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Histórico Bike atualizado · média real ${summary.learnedMovingSpeedKmh!.toStringAsFixed(1)} km/h.',
          ),
        ),
      );
    }
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
              const SizedBox(height: 12),
              Row(
                children: [
                  for (var index = 0; index < MapTravelMode.values.length; index++) ...[
                    if (index > 0) const SizedBox(width: 6),
                    Expanded(
                      child: _TravelModeChoiceCard(
                        mode: MapTravelMode.values[index],
                        icon: _travelModeIcon(MapTravelMode.values[index]),
                        selected: MapTravelMode.values[index] == _lastTravelMode,
                        onTap: () => Navigator.of(sheetContext).pop(
                          MapTravelMode.values[index],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<_BikeTravelSelection?> _chooseBikeTravelPreferences() async {
    var speed = _mapViewSettings.bikeTravelPreferences.averageSpeedKmh;
    var hours = _mapViewSettings.bikeTravelPreferences.ridingHoursPerDay;
    var balance = _mapViewSettings.bikeTravelPreferences.balanceDays;
    var history = _bikeRideHistory.summary;
    var useHistory = _mapViewSettings.bikeUseHistoricalSpeed && history.reliable;
    final selected = await showModalBottomSheet<_BikeTravelSelection>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final scheme = Theme.of(sheetContext).colorScheme;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              MediaQuery.viewPaddingOf(sheetContext).bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Planejar tempo de bicicleta',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'A rota continua usando as vias do roteador, mas o tempo da Bike será calculado pela sua média realista.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Média aprendida com seus percursos',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        history.rideCount == 0
                            ? 'Ainda não há percursos Bike válidos no histórico.'
                            : history.reliable && history.learnedMovingSpeedKmh != null
                                ? '${history.learnedMovingSpeedKmh!.toStringAsFixed(1)} km/h em movimento · ${history.learnedOverallSpeedKmh?.toStringAsFixed(1) ?? '--'} km/h total · ${history.rideCount} percursos · ${history.totalDistanceKm.toStringAsFixed(0)} km analisados'
                                : '${history.rideCount} percurso(s) · ${history.totalDistanceKm.toStringAsFixed(0)} km. A média aprendida fica disponível após 3 percursos válidos, 20 km e 1h30 de movimento.',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Usar média aprendida no ETA'),
                        subtitle: const Text(
                          'Sua média manual continua salva como alternativa.',
                        ),
                        value: useHistory && history.reliable,
                        onChanged: history.reliable
                            ? (value) => setSheetState(() => useHistory = value)
                            : null,
                      ),
                      if (history.rideCount > 0)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () async {
                              await _bikeRideHistory.clear();
                              await _mapViewSettings.setBikeUseHistoricalSpeed(false);
                              if (!sheetContext.mounted) return;
                              setSheetState(() {
                                history = _bikeRideHistory.summary;
                                useHistory = false;
                              });
                            },
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const Text('Limpar histórico Bike'),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Velocidade média manual',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      '${speed.toStringAsFixed(0)} km/h',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                Slider(
                  value: speed,
                  min: 8,
                  max: 30,
                  divisions: 22,
                  label: '${speed.toStringAsFixed(0)} km/h',
                  onChanged: (value) => setSheetState(() => speed = value),
                ),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Tempo máximo pedalando por dia',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      '${hours.toStringAsFixed(hours % 1 == 0 ? 0 : 1)} h/dia',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                Slider(
                  value: hours,
                  min: 1,
                  max: 12,
                  divisions: 22,
                  label: '${hours.toStringAsFixed(1)} h/dia',
                  onChanged: (value) => setSheetState(() => hours = value),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Equilibrar os dias'),
                  subtitle: const Text(
                    'Distribui o pedal de forma parecida entre os dias em rotas longas.',
                  ),
                  value: balance,
                  onChanged: (value) => setSheetState(() => balance = value),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(sheetContext).pop(
                          _BikeTravelSelection(
                            preferences: BikeTravelPreferences(
                              averageSpeedKmh: speed,
                              ridingHoursPerDay: hours,
                              balanceDays: balance,
                            ),
                            useHistoricalSpeed: useHistory && history.reliable,
                          ),
                        ),
                        child: const Text('Usar nesta rota'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
    return selected;
  }

  Future<bool> _prepareTravelPreferences(MapTravelMode travelMode) async {
    if (travelMode != MapTravelMode.bicycle) return true;
    final selection = await _chooseBikeTravelPreferences();
    if (!mounted || selection == null) return false;
    await _mapViewSettings.setBikeTravelPreferences(selection.preferences);
    await _mapViewSettings.setBikeUseHistoricalSpeed(
      selection.useHistoricalSpeed,
    );
    return true;
  }

  Future<void> _navigateToSearchResult(MapDestinationSearchResult item) async {
    final travelMode = await _chooseTravelMode();
    if (!mounted || travelMode == null) return;
    if (!await _prepareTravelPreferences(travelMode)) return;
    if (!mounted) return;
    _routeExplorer.resetAnnouncementSession();
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
      _selectedPoiId = null;
      _selectedMapLocation = null;
      _cyclingRoute = null;
      _cyclingRouteAlternatives = const <MapCyclingRoute>[];
      _selectedCyclingRouteIndex = 0;
      _navigationProgress = null;
      _bikeTripEstimate = null;
      _bikeTripPlan = null;
      _bikeTripPlanLoading = false;
      _offRouteSamples = 0;
      _lastRouteRecalculatedAt = null;
      _lastNavigationProgressPointAt = null;
      _navigationPanelMinimized = true;
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

  void _focusSearchResult(MapDestinationSearchResult item) {
    try {
      _mapController.move(
        LatLng(item.latitude, item.longitude),
        math.max(_visibleMapZoom, 13.5),
      );
      setState(() {
        _followPosition = false;
        _selectedPoiId = null;
        _selectedMapLocation = item;
      });
    } catch (_) {}
  }

  Future<void> _navigateToPoi(RouteExplorerResult item) async {
    final travelMode = await _chooseTravelMode();
    if (!mounted || travelMode == null) return;
    if (!await _prepareTravelPreferences(travelMode)) return;
    if (!mounted) return;
    _routeExplorer.resetAnnouncementSession();
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
      _selectedMapLocation = null;
      _cyclingRoute = null;
      _cyclingRouteAlternatives = const <MapCyclingRoute>[];
      _selectedCyclingRouteIndex = 0;
      _navigationProgress = null;
      _bikeTripEstimate = null;
      _bikeTripPlan = null;
      _bikeTripPlanLoading = false;
      _offRouteSamples = 0;
      _lastRouteRecalculatedAt = null;
      _lastNavigationProgressPointAt = null;
      _navigationPanelMinimized = true;
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
        _bikeTripEstimate = target.travelMode == MapTravelMode.bicycle
            ? _bikeTripPlanner.estimate(
                distanceMeters: route.distanceMeters,
                preferences: _effectiveBikeTravelPreferences,
              )
            : null;
        _navigationProgress = current == null
            ? null
            : _navigationGuidance.evaluate(route: route, position: current);
      });
      if (target.travelMode == MapTravelMode.bicycle) {
        unawaited(_refreshBikeTripPlan(route: route, target: target));
      }
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
      _bikeTripEstimate = _routeState.navigationTarget?.travelMode ==
              MapTravelMode.bicycle
          ? _bikeTripPlanner.estimate(
              distanceMeters: route.distanceMeters,
              preferences: _effectiveBikeTravelPreferences,
            )
          : null;
      _navigationProgress = current == null
          ? null
          : _navigationGuidance.evaluate(route: route, position: current);
      _offRouteSamples = 0;
      _lastNavigationProgressPointAt = null;
    });
    _navigationVoice.resetRoute();
    unawaited(_navigationVoice.handleProgress(_navigationProgress));
    final target = _routeState.navigationTarget;
    if (target?.travelMode == MapTravelMode.bicycle) {
      unawaited(_refreshBikeTripPlan(route: route, target: target!));
    } else {
      setState(() {
        _bikeTripPlan = null;
        _bikeTripPlanLoading = false;
      });
    }
    if (!_followPosition) _fitCyclingRoute(route.points);
  }

  Future<void> _refreshBikeTripPlan({
    required MapCyclingRoute route,
    required MapNavigationTarget target,
  }) async {
    if (target.travelMode != MapTravelMode.bicycle || route.points.length < 2) {
      if (mounted) {
        setState(() {
          _bikeTripPlan = null;
          _bikeTripPlanLoading = false;
        });
      }
      return;
    }
    final preferences = _effectiveBikeTravelPreferences;
    final estimate = _bikeTripPlanner.estimate(
      distanceMeters: route.distanceMeters,
      preferences: preferences,
    );
    if (mounted) {
      setState(() {
        _bikeTripEstimate = estimate;
        _bikeTripPlanLoading = estimate.dayCount > 1;
      });
    }
    final current = _routeState.current;
    List<MapDestinationSearchResult> candidates =
        const <MapDestinationSearchResult>[];
    if (estimate.dayCount > 1 && current != null) {
      final offlineOnly = _connectivity.isOffline ||
          _offlineMaps.mode == OfflineMapMode.offline;
      candidates = await _destinationSearch.placesAlongRoute(
        route: route.points,
        current: current,
        onlineAllowed: !offlineOnly,
        offlineMaps: _offlineMaps.packages,
        offlinePoiPackages: _routeExplorer.offlinePackages,
      );
      if (_manualTripStops.isNotEmpty) {
        candidates = <MapDestinationSearchResult>[
          ..._manualTripStops,
          ...candidates.where(
            (candidate) => !_manualTripStops.any(
              (manual) => manual.id == candidate.id,
            ),
          ),
        ];
      }
    }
    if (!mounted) return;
    final activeTarget = _routeState.navigationTarget;
    final activeRoute = _cyclingRoute;
    if (!_sameNavigationTarget(activeTarget, target) ||
        activeRoute == null ||
        activeRoute.points != route.points) {
      return;
    }
    final plan = _bikeTripPlanner.buildPlan(
      routePoints: route.points,
      routeDistanceMeters: route.distanceMeters,
      preferences: preferences,
      destinationLabel: target.label,
      candidates: candidates,
    );
    setState(() {
      _bikeTripEstimate = plan.estimate;
      _bikeTripPlan = plan;
      _bikeTripPlanLoading = false;
    });
  }

  String _formatTripDuration(Duration duration) {
    final minutes = duration.inMinutes;
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '${hours}h' : '${hours}h ${rest}min';
  }

  Future<void> _selectFreeMapPoint(LatLng point) async {
    final current = _routeState.current;
    if (current == null) return;
    final serial = ++_mapTapLookupSerial;
    setState(() {
      _selectedPoiId = null;
      _selectedMapLocation = MapDestinationSearchResult(
        id: 'coordinate:${point.latitude.toStringAsFixed(5)}:${point.longitude.toStringAsFixed(5)}',
        title: 'Identificando local…',
        subtitle:
            '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
        latitude: point.latitude,
        longitude: point.longitude,
        distanceMeters: const Distance().as(
          LengthUnit.Meter,
          LatLng(current.latitude, current.longitude),
          point,
        ),
        kind: MapDestinationKind.place,
        source: 'coordinate',
      );
      _followPosition = false;
      _quickView = null;
    });
    final offlineOnly = _connectivity.isOffline ||
        _offlineMaps.mode == OfflineMapMode.offline;
    final resolved = await _destinationSearch.reverseLookup(
      point: point,
      current: current,
      onlineAllowed: !offlineOnly,
      offlinePoiPackages: _routeExplorer.offlinePackages,
    );
    if (!mounted || serial != _mapTapLookupSerial) return;
    setState(() => _selectedMapLocation = resolved);
  }

  Future<void> _showMapLocationDetails(MapDestinationSearchResult item) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.kind.label, style: Theme.of(sheetContext).textTheme.labelLarge),
              Text(item.title, style: Theme.of(sheetContext).textTheme.headlineSmall),
              const SizedBox(height: 10),
              if (item.subtitle.trim().isNotEmpty) Text(item.subtitle),
              const SizedBox(height: 8),
              Text('Coordenadas: ${item.latitude.toStringAsFixed(5)}, '
                  '${item.longitude.toStringAsFixed(5)}'),
              Text('Fonte: ${item.offline ? 'Offline' : item.storedLocally ? 'Salvo no aparelho' : 'Online'}'),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _addManualTripStop(item);
                  },
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('Adicionar parada'),
                )),
                const SizedBox(width: 8),
                Expanded(child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _navigateToSearchResult(item);
                  },
                  icon: const Icon(Icons.navigation_rounded),
                  label: const Text('Navegar'),
                )),
              ]),
            ]),
        ),
      ),
    );
  }

  void _addManualTripStop(MapDestinationSearchResult item) {
    final alreadyAdded = _manualTripStops.any((candidate) => candidate.id == item.id);
    if (!alreadyAdded) _manualTripStops.add(item);
    final route = _cyclingRoute;
    final target = _routeState.navigationTarget;
    if (route != null && target?.travelMode == MapTravelMode.bicycle) {
      unawaited(_refreshBikeTripPlan(route: route, target: target!));
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          alreadyAdded
              ? 'Esse local já está no planejamento.'
              : 'Parada adicionada ao planejamento da cicloviagem.',
        ),
      ),
    );
  }

  Future<void> _showBikeTripPlan() async {
    final plan = _bikeTripPlan;
    if (plan == null || plan.days.isEmpty || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.82,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Plano da cicloviagem',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${plan.estimate.distanceKm.toStringAsFixed(0)} km · '
                    '${_formatTripDuration(plan.estimate.ridingDuration)} pedalando · '
                    '${plan.estimate.dayCount} dia(s) · '
                    '${plan.estimate.preferences.averageSpeedKmh.toStringAsFixed(1)} km/h'
                    '${_mapViewSettings.bikeUseHistoricalSpeed && _bikeRideHistory.summary.reliable ? ' · média aprendida' : ''}',
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                itemCount: plan.days.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final day = plan.days[index];
                  final km = day.distanceMeters / 1000;
                  return Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text('${day.day}'),
                      ),
                      title: Text(
                        'Dia ${day.day} · ${km.toStringAsFixed(km < 100 ? 1 : 0)} km · ${_formatTripDuration(day.ridingDuration)}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                        '${day.stopLabel} · ${day.stopKind}\n'
                        '${day.usesKnownPlace ? 'Local conhecido nos dados disponíveis.' : 'Ponto aproximado da rota; não presume água, comida ou hospedagem.'}',
                      ),
                      isThreeLine: true,
                      trailing: Icon(
                        day.usesKnownPlace
                            ? Icons.place_rounded
                            : Icons.route_rounded,
                      ),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        try {
                          _mapController.move(
                            LatLng(day.stopLatitude, day.stopLongitude),
                            math.max(_visibleMapZoom, 12.5),
                          );
                          setState(() => _followPosition = false);
                        } catch (_) {}
                      },
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'As paradas usam cidades, comunidades ou campings conhecidos quando disponíveis. Pontos aproximados não garantem serviços no local.',
                textAlign: TextAlign.center,
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
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
    _bikeTripEstimate = null;
    _bikeTripPlan = null;
    _bikeTripPlanLoading = false;
    _cyclingRouteLoading = false;
    _offRouteSamples = 0;
    _lastRouteRecalculatedAt = null;
    _lastNavigationProgressPointAt = null;
    _navigation3dEnabled = true;
    _navigation3dRendererReady = false;
    _navigation3dRendererFailed = false;
    _navigation3dFollowing = true;
    _navigationPanelMinimized = true;
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

  Future<void> _showTelemetryPanel({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Listenable> listenables,
    required Widget Function(BuildContext context) contentBuilder,
  }) async {
    if (!mounted) return;

    Widget buildPanel(BuildContext panelContext) {
      final animation = listenables.length == 1
          ? listenables.first
          : Listenable.merge(listenables);
      return AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final scheme = Theme.of(context).colorScheme;
          return Material(
            color: scheme.surface,
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
                    child: MapTelemetryPanelHeader(
                      icon: icon,
                      title: title,
                      subtitle: subtitle,
                      trailing: IconButton(
                        tooltip: 'Fechar',
                        onPressed: () => Navigator.of(panelContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                  ),
                  Divider(height: 1, color: scheme.outlineVariant),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                      child: contentBuilder(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    if (landscape) {
      final width = math.min(MediaQuery.sizeOf(context).width * 0.48, 520.0);
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Fechar painel de $title',
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (dialogContext, animation, secondaryAnimation) => Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: width,
            height: double.infinity,
            child: buildPanel(dialogContext),
          ),
        ),
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          );
        },
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.82,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          child: buildPanel(sheetContext),
        ),
      ),
    );
  }

  String _formatReadingAge(Duration? age) {
    if (age == null) return '--';
    if (age.inSeconds < 2) return 'agora';
    if (age.inMinutes < 1) return '${age.inSeconds} s';
    if (age.inHours < 1) return '${age.inMinutes} min';
    return '${age.inHours} h';
  }

  Future<void> _showSpeedDetails() async {
    await _showTelemetryPanel(
      title: 'Velocidade',
      subtitle: 'Ritmo atual e estatísticas desta sessão',
      icon: Icons.speed_rounded,
      listenables: <Listenable>[_routeState],
      contentBuilder: (context) {
        final current = _routeState.current;
        final speed = MapTelemetryPolicy.currentSpeedKmh(current);
        final speedAccuracy = MapTelemetryPolicy.speedAccuracyKmh(current);
        final average = _telemetrySession.averageSpeedKmh;
        final maximum = _telemetrySession.maximumSpeedKmh;
        final difference = speed == null || average == null ? null : speed - average;
        final comparison = difference == null
            ? 'Aguardando média suficiente para comparar o ritmo.'
            : difference.abs() < 0.5
                ? 'Ritmo atual próximo da média da sessão.'
                : difference > 0
                    ? '${difference.toStringAsFixed(1)} km/h acima da média da sessão.'
                    : '${difference.abs().toStringAsFixed(1)} km/h abaixo da média da sessão.';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MapSpeedDial(
              speedKmh: speed,
              averageKmh: average,
              maximumReferenceKmh: maximum,
            ),
            Text(
              comparison,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
            MapTelemetryMetricGrid(
              children: [
                MapTelemetryMetricTile(
                  label: 'Média da sessão',
                  value: average == null ? '--' : '${average.toStringAsFixed(1)} km/h',
                  icon: Icons.trending_flat_rounded,
                ),
                MapTelemetryMetricTile(
                  label: 'Máxima da sessão',
                  value: maximum == null ? '--' : '${maximum.toStringAsFixed(1)} km/h',
                  icon: Icons.north_east_rounded,
                  emphasized: true,
                ),
                MapTelemetryMetricTile(
                  label: 'Distância gravada',
                  value: _formatDistance(),
                  icon: Icons.route_rounded,
                ),
                MapTelemetryMetricTile(
                  label: 'Tempo de percurso',
                  value: _formatTripDuration(_routeState.elapsed),
                  icon: Icons.timer_outlined,
                ),
                MapTelemetryMetricTile(
                  label: 'Precisão da velocidade',
                  value: speedAccuracy == null
                      ? 'Não informada'
                      : '±${speedAccuracy.toStringAsFixed(1)} km/h',
                  icon: Icons.radar_rounded,
                ),
                MapTelemetryMetricTile(
                  label: 'Amostras válidas',
                  value: '${_telemetrySession.speedSamples}',
                  detail: 'Somente leituras de velocidade fornecidas pelo GPS.',
                  icon: Icons.data_usage_rounded,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Fonte atual: ${speed == null ? 'indisponível' : 'GPS do aparelho'}. O marcador fino no arco representa a média da sessão quando ela existe.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAltitudeDetails() async {
    await _showTelemetryPanel(
      title: 'Altitude',
      subtitle: 'Perfil recente e amplitude do percurso',
      icon: Icons.terrain_rounded,
      listenables: <Listenable>[_routeState],
      contentBuilder: (context) {
        final current = _routeState.current;
        final summary = MapTelemetryPolicy.elevationSummary(
          _routeState.route,
          current: current,
        );
        final accuracy = MapTelemetryPolicy.validAccuracyMeters(
          current?.altitudeAccuracyMeters,
        );
        final delta = summary.recentDeltaMeters;
        final trend = delta == null
            ? '--'
            : delta.abs() < 1
                ? 'Estável'
                : delta > 0
                    ? '+${delta.toStringAsFixed(1)} m'
                    : '${delta.toStringAsFixed(1)} m';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MapElevationProfileChart(valuesMeters: summary.recentProfileMeters),
            const SizedBox(height: 14),
            MapTelemetryMetricGrid(
              children: [
                MapTelemetryMetricTile(
                  label: 'Altitude atual',
                  value: summary.currentMeters == null
                      ? '--'
                      : '${summary.currentMeters!.toStringAsFixed(1)} m',
                  icon: Icons.height_rounded,
                  emphasized: true,
                ),
                MapTelemetryMetricTile(
                  label: 'Tendência recente',
                  value: trend,
                  detail: 'Diferença entre a primeira e a última amostra do perfil.',
                  icon: delta != null && delta < 0
                      ? Icons.south_east_rounded
                      : Icons.north_east_rounded,
                ),
                MapTelemetryMetricTile(
                  label: 'Mínima observada',
                  value: summary.minimumMeters == null
                      ? '--'
                      : '${summary.minimumMeters!.toStringAsFixed(1)} m',
                  icon: Icons.vertical_align_bottom_rounded,
                ),
                MapTelemetryMetricTile(
                  label: 'Máxima observada',
                  value: summary.maximumMeters == null
                      ? '--'
                      : '${summary.maximumMeters!.toStringAsFixed(1)} m',
                  icon: Icons.vertical_align_top_rounded,
                ),
                MapTelemetryMetricTile(
                  label: 'Amplitude',
                  value: summary.rangeMeters == null
                      ? '--'
                      : '${summary.rangeMeters!.toStringAsFixed(1)} m',
                  icon: Icons.swap_vert_rounded,
                ),
                MapTelemetryMetricTile(
                  label: 'Precisão vertical',
                  value: accuracy == null
                      ? 'Não informada'
                      : '±${accuracy.toStringAsFixed(1)} m',
                  detail: '${summary.samples} leituras úteis no percurso.',
                  icon: Icons.radar_rounded,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'O perfil usa somente altitudes realmente fornecidas pelo GPS e descarta leituras com precisão vertical muito ruim. Não calcula ganho acumulado artificialmente a partir de ruído do sensor.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        );
      },
    );
  }

  IconData _weatherIcon(int? code) => switch (code) {
        0 || 1 => Icons.wb_sunny_rounded,
        2 => Icons.wb_cloudy_rounded,
        3 || 45 || 48 => Icons.cloud_rounded,
        51 || 53 || 55 || 56 || 57 => Icons.grain_rounded,
        61 || 63 || 65 || 66 || 67 || 80 || 81 || 82 =>
          Icons.water_drop_rounded,
        71 || 73 || 75 || 77 || 85 || 86 => Icons.ac_unit_rounded,
        95 || 96 || 99 => Icons.thunderstorm_rounded,
        _ => Icons.device_thermostat_rounded,
      };

  Future<void> _speakWeather() async {
    if (!_mapViewSettings.weatherVoiceEnabled) return;
    final message = MapWeatherPolicy.buildVoiceMessage(_weather.snapshot);
    if (message.isEmpty) return;
    await _mapVoice.deliver(message);
  }

  Future<void> _refreshWeatherManually() async {
    final current = _routeState.current;
    if (current == null) return;
    await _weather.refreshForLocation(
      latitude: current.latitude,
      longitude: current.longitude,
      force: true,
    );
  }

  Future<void> _showWeatherDetails() async {
    await _showTelemetryPanel(
      title: 'Clima',
      subtitle: 'Condição local e horizonte das próximas 12 horas',
      icon: _weatherIcon(_weather.snapshot.weatherCode?.value),
      listenables: <Listenable>[_weather, _routeState],
      contentBuilder: (context) {
        final snapshot = _weather.snapshot;
        final condition = MapWeatherPolicy.conditionLabel(snapshot.weatherCode?.value);
        final assessment = MapWeatherPolicy.assessForRide(snapshot);
        final current = _routeState.current;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_weather.loading) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
            ],
            MapWeatherAssessmentBanner(assessment: assessment),
            const SizedBox(height: 14),
            MapTelemetryMetricGrid(
              children: [
                MapTelemetryMetricTile(
                  label: 'Temperatura',
                  value: snapshot.temperatureC == null
                      ? '--'
                      : '${snapshot.temperatureC!.value.toStringAsFixed(1)} °C',
                  detail: snapshot.temperatureC?.source.label,
                  icon: Icons.device_thermostat_rounded,
                  emphasized: true,
                ),
                MapTelemetryMetricTile(
                  label: 'Sensação',
                  value: snapshot.apparentTemperatureC == null
                      ? '--'
                      : '${snapshot.apparentTemperatureC!.value.toStringAsFixed(1)} °C',
                  icon: Icons.thermostat_rounded,
                ),
                MapTelemetryMetricTile(
                  label: 'Condição',
                  value: condition ?? '--',
                  icon: _weatherIcon(snapshot.weatherCode?.value),
                ),
                MapTelemetryMetricTile(
                  label: 'Chuva · próximas horas',
                  value: snapshot.precipitationProbabilityPercent == null
                      ? '--'
                      : '${snapshot.precipitationProbabilityPercent!.value.toStringAsFixed(0)}%',
                  icon: Icons.umbrella_rounded,
                ),
                MapTelemetryMetricTile(
                  label: 'Vento',
                  value: snapshot.windSpeedKmh == null
                      ? '--'
                      : '${snapshot.windSpeedKmh!.value.toStringAsFixed(1)} km/h',
                  detail: snapshot.windDirectionDegrees == null
                      ? null
                      : MapWeatherPolicy.windDirectionLabel(
                          snapshot.windDirectionDegrees!.value,
                        ),
                  icon: Icons.air_rounded,
                ),
                MapTelemetryMetricTile(
                  label: 'Umidade',
                  value: snapshot.humidityPercent == null
                      ? '--'
                      : '${snapshot.humidityPercent!.value.toStringAsFixed(0)}%',
                  detail: snapshot.humidityPercent?.source.label,
                  icon: Icons.water_drop_outlined,
                ),
                MapTelemetryMetricTile(
                  label: 'Pressão atmosférica',
                  value: snapshot.surfacePressureHpa == null
                      ? '--'
                      : '${snapshot.surfacePressureHpa!.value.toStringAsFixed(1)} hPa',
                  detail: snapshot.surfacePressureHpa?.source.label,
                  icon: Icons.compress_rounded,
                ),
                MapTelemetryMetricTile(
                  label: 'Origem dos dados',
                  value: snapshot.origin.label,
                  detail: snapshot.onlineStale ? 'Cache online antigo' : MapWeatherService.providerLabel,
                  icon: Icons.hub_rounded,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Previsão horária',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            MapWeatherForecastStrip(hours: snapshot.hourlyForecast),
            if (_weather.lastError != null) ...[
              const SizedBox(height: 12),
              Text(
                _weather.lastError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: current == null || _weather.loading
                      ? null
                      : () => unawaited(_refreshWeatherManually()),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Atualizar'),
                ),
                OutlinedButton.icon(
                  onPressed: !_mapViewSettings.weatherVoiceEnabled ||
                          MapWeatherPolicy.buildVoiceMessage(snapshot).isEmpty
                      ? null
                      : () => unawaited(_speakWeather()),
                  icon: const Icon(Icons.volume_up_rounded),
                  label: const Text('Ouvir resumo'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'A avaliação para pedal usa limites locais transparentes de chuva, vento, rajadas, trovoadas e sensação térmica; ela não substitui avisos meteorológicos oficiais.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showGpsDetails() async {
    await _showTelemetryPanel(
      title: 'GPS',
      subtitle: 'Qualidade, precisão e dados brutos da localização',
      icon: Icons.gps_fixed_rounded,
      listenables: <Listenable>[_routeState],
      contentBuilder: (context) {
        final current = _routeState.current;
        final accuracy = MapTelemetryPolicy.validAccuracyMeters(
          current?.accuracyMeters,
        );
        final quality = MapTelemetryPolicy.gpsQuality(current);
        final speed = MapTelemetryPolicy.currentSpeedKmh(current);
        final speedAccuracy = MapTelemetryPolicy.speedAccuracyKmh(current);
        final heading = MapTelemetryPolicy.gpsHeadingDegrees(current);
        final headingAccuracy = MapTelemetryPolicy.validAccuracyMeters(
          current?.headingAccuracyDegrees,
        );
        final altitudeAccuracy = MapTelemetryPolicy.validAccuracyMeters(
          current?.altitudeAccuracyMeters,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MapGpsQualityIndicator(
              quality: quality,
              accuracyMeters: accuracy,
            ),
            const SizedBox(height: 14),
            MapTelemetryMetricGrid(
              children: [
                MapTelemetryMetricTile(
                  label: 'Status',
                  value: _gpsStatus(current),
                  icon: Icons.location_searching_rounded,
                  emphasized: true,
                ),
                MapTelemetryMetricTile(
                  label: 'Idade da leitura',
                  value: _formatReadingAge(
                    MapTelemetryPolicy.readingAge(current),
                  ),
                  icon: Icons.schedule_rounded,
                ),
                MapTelemetryMetricTile(
                  label: 'Latitude',
                  value: current == null ? '--' : current.latitude.toStringAsFixed(6),
                  icon: Icons.my_location_rounded,
                ),
                MapTelemetryMetricTile(
                  label: 'Longitude',
                  value: current == null ? '--' : current.longitude.toStringAsFixed(6),
                  icon: Icons.my_location_rounded,
                ),
                MapTelemetryMetricTile(
                  label: 'Velocidade GPS',
                  value: speed == null ? '--' : '${speed.toStringAsFixed(1)} km/h',
                  detail: speedAccuracy == null
                      ? 'Precisão não informada'
                      : '±${speedAccuracy.toStringAsFixed(1)} km/h',
                  icon: Icons.speed_rounded,
                ),
                MapTelemetryMetricTile(
                  label: 'Heading GPS',
                  value: heading == null ? '--' : '${heading.toStringAsFixed(0)}°',
                  detail: headingAccuracy == null
                      ? null
                      : '±${headingAccuracy.toStringAsFixed(0)}°',
                  icon: Icons.explore_rounded,
                ),
                MapTelemetryMetricTile(
                  label: 'Altitude',
                  value: current?.altitudeMeters == null
                      ? '--'
                      : '${current!.altitudeMeters!.toStringAsFixed(1)} m',
                  detail: altitudeAccuracy == null
                      ? 'Precisão vertical não informada'
                      : '±${altitudeAccuracy.toStringAsFixed(1)} m',
                  icon: Icons.terrain_rounded,
                ),
                MapTelemetryMetricTile(
                  label: 'Leituras rejeitadas',
                  value: '${_routeState.rejectedGpsPoints}',
                  detail: _routeState.lastGpsRejectionReason == null
                      ? 'Filtro sem rejeição recente registrada.'
                      : 'Último filtro: ${_routeState.lastGpsRejectionReason!.name}',
                  icon: Icons.filter_alt_rounded,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Qualidade é uma classificação local baseada na precisão horizontal e na idade da leitura: excelente ≤5 m, boa ≤12 m, razoável ≤30 m; acima disso é marcada como fraca.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCompassDetails() async {
    await _showTelemetryPanel(
      title: 'Bússola',
      subtitle: 'Direção, fonte ativa e orientação do mapa',
      icon: Icons.explore_rounded,
      listenables: <Listenable>[
        _routeState,
        _mapViewSettings,
        _compassPanelTick,
      ],
      contentBuilder: (context) {
        final current = _routeState.current;
        final heading = _displayHeadingFor(current);
        final degrees = heading.headingDegrees;
        final sensor = _compassReading;
        final sensorAge = sensor == null
            ? null
            : DateTime.now().difference(sensor.recordedAt);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MapCompassDial(
              headingDegrees: degrees,
              directionLabel: _mapDirectionLabel(degrees),
            ),
            MapTelemetryMetricGrid(
              children: [
                MapTelemetryMetricTile(
                  label: 'Fonte em uso',
                  value: heading.source.label,
                  detail: heading.source == MapHeadingSource.sensor && sensor != null
                      ? sensor.sensor
                      : null,
                  icon: Icons.sensors_rounded,
                  emphasized: true,
                ),
                MapTelemetryMetricTile(
                  label: 'Direção',
                  value: degrees == null
                      ? '--'
                      : '${_mapDirectionLabel(degrees)} · ${degrees.toStringAsFixed(0)}°',
                  icon: Icons.navigation_rounded,
                ),
                MapTelemetryMetricTile(
                  label: 'Sensor físico',
                  value: sensor == null ? 'Indisponível' : sensor.sensor,
                  detail: sensorAge == null
                      ? null
                      : 'Leitura há ${_formatReadingAge(sensorAge)}',
                  icon: Icons.phone_android_rounded,
                ),
                MapTelemetryMetricTile(
                  label: 'Modo do mapa',
                  value: _mapViewSettings.orientationMode.label,
                  icon: Icons.screen_rotation_rounded,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Orientação do mapa',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
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
              selected: <MapOrientationMode>{_mapViewSettings.orientationMode},
              onSelectionChanged: (selection) => unawaited(
                _setOrientationMode(
                  selection.first,
                  showUnavailableNotice: false,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'A direção exibida escolhe a melhor fonte real disponível entre sensor físico, GPS e geometria da rota. Nenhum rumo é fabricado quando as fontes estão ausentes.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        );
      },
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

  MapAppearancePreset _resolvedMapAppearance(Brightness brightness) =>
      MapAppearancePolicy.resolve(
        mode: _mapViewSettings.appearanceMode,
        manualPreset: _mapViewSettings.appearancePreset,
        platformBrightness: brightness,
        now: DateTime.now(),
      );

  Widget _applyRasterAppearance(
    Widget layer,
    MapAppearancePreset appearance,
  ) {
    if (_mapViewSettings.stylePreset == MapStylePreset.satellite) return layer;
    final matrix = MapAppearancePolicy.palette(appearance).rasterColorMatrix;
    if (matrix == null) return layer;
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(matrix),
      child: layer,
    );
  }

  IconData _mapAppearanceIcon(MapAppearancePreset preset) => switch (preset) {
        MapAppearancePreset.standard => Icons.light_mode_outlined,
        MapAppearancePreset.dark => Icons.dark_mode_outlined,
        MapAppearancePreset.highContrast => Icons.contrast_rounded,
        MapAppearancePreset.bikeTravel => Icons.directions_bike_rounded,
      };

  Future<void> _selectMapAppearance(MapAppearancePreset preset) async {
    await _mapViewSettings.setAppearancePreset(preset);
    if (!mounted) return;
    setState(() {
      _navigation3dRendererReady = false;
      _navigation3dRendererFailed = false;
    });
  }

  Future<void> _selectMapAppearanceMode(MapAppearanceMode mode) async {
    await _mapViewSettings.setAppearanceMode(mode);
    if (!mounted) return;
    setState(() {
      _navigation3dRendererReady = false;
      _navigation3dRendererFailed = false;
    });
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
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final selectedLayer = _mapViewSettings.stylePreset;
          final resolvedAppearance = _resolvedMapAppearance(
            Theme.of(sheetContext).brightness,
          );
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'Aparência e camadas',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                    child: Text(
                      'Tema ativo: ${resolvedAppearance.label}',
                      style: Theme.of(sheetContext).textTheme.bodySmall,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'Tema visual',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final preset in MapAppearancePreset.values)
                        ChoiceChip(
                          avatar: Icon(_mapAppearanceIcon(preset), size: 17),
                          label: Text(preset.label),
                          selected: _mapViewSettings.appearanceMode ==
                                  MapAppearanceMode.manual &&
                              _mapViewSettings.appearancePreset == preset,
                          showCheckmark: false,
                          visualDensity: VisualDensity.compact,
                          onSelected: (_) => unawaited(
                            _selectMapAppearance(preset).then((_) {
                              if (sheetContext.mounted) setSheetState(() {});
                            }),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'Modo automático',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SegmentedButton<MapAppearanceMode>(
                    segments: const [
                      ButtonSegment(
                        value: MapAppearanceMode.manual,
                        icon: Icon(Icons.tune_rounded, size: 16),
                        label: Text('Manual'),
                      ),
                      ButtonSegment(
                        value: MapAppearanceMode.followSystem,
                        icon: Icon(Icons.phone_android_rounded, size: 16),
                        label: Text('Sistema'),
                      ),
                      ButtonSegment(
                        value: MapAppearanceMode.dayNight,
                        icon: Icon(Icons.brightness_6_outlined, size: 16),
                        label: Text('Dia/noite'),
                      ),
                    ],
                    selected: <MapAppearanceMode>{
                      _mapViewSettings.appearanceMode,
                    },
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) => unawaited(
                      _selectMapAppearanceMode(selection.first).then((_) {
                        if (sheetContext.mounted) setSheetState(() {});
                      }),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
                    child: Text(
                      _mapViewSettings.appearanceMode == MapAppearanceMode.dayNight
                          ? 'Dia/noite usa somente o horário local do aparelho; não depende da internet.'
                          : _mapViewSettings.appearanceMode == MapAppearanceMode.followSystem
                              ? 'Segue o tema claro/escuro configurado no Android.'
                              : _mapViewSettings.appearancePreset.description,
                      style: Theme.of(sheetContext).textTheme.bodySmall,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 3, 8, 0),
                    child: Text(
                      'No 3D, o tema troca o style vetorial de fundo, água, parques, vias, prédios, nomes e limites. No 2D, adapta os tiles e mantém rota e posição com contraste próprio.',
                      style: Theme.of(sheetContext).textTheme.bodySmall,
                    ),
                  ),
                  const Divider(height: 22),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'Base do mapa',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 2),
                  for (final style in MapStylePreset.values)
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
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
                          : selectedLayer == style
                              ? const Icon(Icons.check_circle_rounded)
                              : null,
                      selected: selectedLayer == style,
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
      ),
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
    await _mapViewSettings.setWeatherVoiceEnabled(false);
    await _navigationVoice.stop();
    if (mounted) setState(() {});
  }

  Future<void> _showAudioQuickControls() async {
    await Future.wait<void>([
      _mapViewSettings.initialize(),
      _routeExplorer.initialize(),
      _appSettings.initialize().then((_) {}),
      _weather.initialize(),
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
          final weatherEnabled = _mapViewSettings.weatherVoiceEnabled;
          final allMuted = !navigationEnabled &&
              !aiEnabled &&
              !nearbyEnabled &&
              !weatherEnabled;

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
                      _QuickAudioSwitch(
                        icon: Icons.cloud_rounded,
                        title: 'Clima',
                        subtitle: 'Leituras do sensor e previsão online',
                        value: weatherEnabled,
                        onChanged: (value) => unawaited(
                          updateAndRefresh(
                            _mapViewSettings.setWeatherVoiceEnabled(value),
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
                              unawaited(_showMapSettings(returnToNearby: true));
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

  String _formatSearchDistance(double meters) {
    if (meters < 1000) return '~${meters.round()} m';
    final km = meters / 1000;
    return '~${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
  }

  String _searchSourceLabel(MapDestinationSearchResult item) {
    if (item.offline) return 'Offline';
    if (item.storedLocally) return 'Salvo';
    return 'Online';
  }

  IconData _destinationKindIcon(MapDestinationSearchResult item) {
    if (item.poiCategory != null) return _poiIcon(item.poiCategory!);
    return switch (item.kind) {
      MapDestinationKind.city => Icons.location_city_rounded,
      MapDestinationKind.town => Icons.location_city_outlined,
      MapDestinationKind.village => Icons.holiday_village_outlined,
      MapDestinationKind.community => Icons.home_work_outlined,
      MapDestinationKind.pointOfInterest => Icons.place_rounded,
      MapDestinationKind.place => Icons.place_outlined,
    };
  }

  Future<void> _showBikePanel() async {
    await _bikePressureSafety.initialize();
    if (!mounted) return;
    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    final panel = _BikeMapPanel(
      sensors: _bikeSensors,
      safety: _bikePressureSafety,
    );
    if (!landscape) {
      await showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => panel,
      );
      return;
    }
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fechar painel da bike',
      barrierColor: Colors.black.withValues(alpha: 0.18),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, _, _) => SafeArea(
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Material(
              elevation: 12,
              borderRadius: BorderRadius.circular(24),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: math.min(390.0, MediaQuery.sizeOf(dialogContext).width * 0.42).toDouble(),
                child: panel,
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (_, animation, _, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.18, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Future<void> _showDestinationSearch() async {
    await Future.wait<void>([
      _destinationSearch.initialize(),
      _offlineMaps.initialize(),
      _routeExplorer.initialize(),
    ]);
    if (!mounted) return;
    final current = _routeState.current;
    if (current == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aguardando GPS para pesquisar destinos.')),
      );
      return;
    }

    final offlineOnly = _connectivity.isOffline ||
        _offlineMaps.mode == OfflineMapMode.offline;
    unawaited(
      _destinationSearch.prepareSuggestions(
        current: current,
        onlineAllowed: !offlineOnly,
        offlineMaps: _offlineMaps.packages,
      ),
    );

    final controller = TextEditingController();
    var query = '';
    var submittedSearch = false;
    try {
      await showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (sheetContext, setSheetState) => FractionallySizedBox(
            heightFactor: 0.88,
            child: ListenableBuilder(
              listenable: _destinationSearch,
              builder: (context, _) {
                final service = _destinationSearch;
                final showingSuggestions = query.trim().isEmpty;
                final items = showingSuggestions
                    ? service.suggestions
                    : service.results;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pesquisar no mapa',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            offlineOnly
                                ? 'Offline · cidades, comunidades e pontos já salvos.'
                                : 'Pesquise cidades, comunidades, endereços e pontos. A busca online ocorre somente ao enviar.',
                            style: Theme.of(sheetContext).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TextField(
                        controller: controller,
                        textInputAction: TextInputAction.search,
                        autofocus: false,
                        decoration: InputDecoration(
                          hintText: 'Ex.: Divinópolis, mercado, camping…',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: IconButton(
                            tooltip: 'Pesquisar',
                            icon: const Icon(Icons.arrow_forward_rounded),
                            onPressed: service.searchLoading
                                ? null
                                : () async {
                                    final submitted = controller.text.trim();
                                    setSheetState(() {
                                      query = submitted;
                                      submittedSearch = true;
                                    });
                                    await service.searchSubmitted(
                                      query: submitted,
                                      current: current,
                                      onlineAllowed: !offlineOnly,
                                      offlineMaps: _offlineMaps.packages,
                                      offlinePoiPackages:
                                          _routeExplorer.offlinePackages,
                                    );
                                  },
                          ),
                        ),
                        onChanged: (value) {
                          final typed = value.trim();
                          setSheetState(() {
                            query = typed;
                            submittedSearch = false;
                          });
                          service.updateLocalQuery(
                            query: typed,
                            current: current,
                            offlineMaps: _offlineMaps.packages,
                            offlinePoiPackages: _routeExplorer.offlinePackages,
                            onlyDownloaded: offlineOnly,
                          );
                        },
                        onSubmitted: service.searchLoading
                            ? null
                            : (value) async {
                                final submitted = value.trim();
                                setSheetState(() {
                                  query = submitted;
                                  submittedSearch = true;
                                });
                                await service.searchSubmitted(
                                  query: submitted,
                                  current: current,
                                  onlineAllowed: !offlineOnly,
                                  offlineMaps: _offlineMaps.packages,
                                  offlinePoiPackages:
                                      _routeExplorer.offlinePackages,
                                );
                              },
                      ),
                    ),
                    if (service.searchLoading || service.suggestionsLoading)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator(
                          minHeight: service.searchLoading ? 3 : 2,
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 9, 16, 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              showingSuggestions
                                  ? 'Cidades e comunidades próximas'
                                  : submittedSearch
                                      ? 'Resultados para “$query”'
                                      : 'Sugestões para “$query”',
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                          if (offlineOnly)
                            const Chip(
                              visualDensity: VisualDensity.compact,
                              avatar: Icon(Icons.offline_bolt_rounded, size: 16),
                              label: Text('Offline'),
                            ),
                        ],
                      ),
                    ),
                    if ((showingSuggestions
                            ? service.suggestionsStatusMessage
                            : service.searchStatusMessage) !=
                        null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 7),
                        child: Text(
                          (showingSuggestions
                              ? service.suggestionsStatusMessage
                              : service.searchStatusMessage)!,
                          style: Theme.of(sheetContext).textTheme.bodySmall,
                        ),
                      ),
                    Expanded(
                      child: items.isEmpty
                          ? _MapEmptyState(
                              message: showingSuggestions && service.suggestionsLoading
                                  ? 'Buscando cidades e comunidades próximas… Você já pode pesquisar acima.'
                                  : showingSuggestions
                                      ? 'Ainda não há sugestões salvas para esta região.'
                                      : service.searchLoading
                                          ? 'Pesquisando…'
                                          : offlineOnly
                                              ? 'Nada encontrado nos dados offline salvos.'
                                              : 'Nenhum resultado encontrado.',
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                              itemCount: items.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 5),
                              itemBuilder: (context, index) {
                                final item = items[index];
                                return Card(
                                  margin: EdgeInsets.zero,
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      child: Icon(
                                        _destinationKindIcon(item),
                                        size: 19,
                                      ),
                                    ),
                                    title: Text(
                                      item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      '${item.kind.label} · ${_searchSourceLabel(item)} · ${_formatSearchDistance(item.distanceMeters)}\n${item.subtitle}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: () {
                                      Navigator.of(sheetContext).pop();
                                      _focusSearchResult(item);
                                    },
                                    trailing: FilledButton.tonalIcon(
                                      icon: const Icon(Icons.navigation_rounded, size: 17),
                                      label: const Text('Navegar'),
                                      onPressed: () {
                                        Navigator.of(sheetContext).pop();
                                        unawaited(_navigateToSearchResult(item));
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    if (!offlineOnly)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Text(
                          'Distâncias da lista são aproximadas em linha reta; ao criar a rota, o app calcula percurso e tempo. Busca: OpenStreetMap/Nominatim · localidades: OpenStreetMap/Overpass.',
                          textAlign: TextAlign.center,
                          style: Theme.of(sheetContext).textTheme.labelSmall,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _showMapSettings({bool returnToNearby = false}) async {
    await Future.wait<void>([
      _routeExplorer.initialize(),
      _mapViewSettings.initialize(),
      _appSettings.initialize().then((_) {}),
      _weather.initialize(),
    ]);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => FractionallySizedBox(
          heightFactor: 0.90,
          child: ListenableBuilder(
          listenable: Listenable.merge([
            _routeExplorer,
            _mapViewSettings,
            _routeState,
          ]),
          builder: (context, _) {
            final settings = _routeExplorer.settings;
            final orientationMode = _mapViewSettings.orientationMode;
            final navigationVoice = _mapViewSettings.navigationVoiceEnabled;
            final weatherVoice = _mapViewSettings.weatherVoiceEnabled;
            final aiVoice = _aiVoiceEnabled;
            final recording = _routeState.recording;
            final paused = _routeState.paused;
            final hasRoutePoints = _routeState.route.length >= 2;
            const radiusOptions = <int>[5, 10, 20, 50];
            const alertDistanceOptions = <int>[1000, 3000, 5000, 10000];

            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 4, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        tooltip: returnToNearby
                            ? 'Voltar para Próximos pontos'
                            : 'Fechar configurações',
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: () => Navigator.of(sheetContext).pop(),
                      ),
                      const SizedBox(width: 2),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Configurações do mapa',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Alterações de busca e categorias são aplicadas automaticamente.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _MapSettingsSection(
                  icon: Icons.search_rounded,
                  title: 'Busca',
                  initiallyExpanded: true,
                  children: [
                    const _MapSettingsTitle('Raio de busca'),
                    Row(
                      children: [
                        for (var index = 0; index < radiusOptions.length; index++) ...[
                          if (index > 0) const SizedBox(width: 6),
                          Expanded(
                            child: ChoiceChip(
                              label: Center(
                                child: Text('${radiusOptions[index]} km'),
                              ),
                              selected: settings.radiusKm == radiusOptions[index],
                              showCheckmark: false,
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              onSelected: (_) => unawaited(
                                _routeExplorer.setRadiusKm(radiusOptions[index]),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    const _MapSettingsTitle('Busca durante o deslocamento'),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment<bool>(
                            value: false,
                            icon: Icon(Icons.my_location_rounded, size: 17),
                            label: Text('Ao redor'),
                          ),
                          ButtonSegment<bool>(
                            value: true,
                            icon: Icon(Icons.route_rounded, size: 17),
                            label: Text('No caminho'),
                          ),
                        ],
                        selected: <bool>{settings.searchAheadWhenMoving},
                        showSelectedIcon: false,
                        onSelectionChanged: (selection) => unawaited(
                          _routeExplorer.setSearchAheadWhenMoving(selection.first),
                        ),
                      ),
                    ),
                  ],
                ),
                _MapSettingsSection(
                  icon: Icons.category_outlined,
                  title: 'Categorias',
                  initiallyExpanded: true,
                  trailingText: '${settings.categories.length}/${RouteExplorerCategory.values.length}',
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 620 ? 4 : 3;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: RouteExplorerCategory.values.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                            mainAxisExtent: 46,
                          ),
                          itemBuilder: (context, index) {
                            final category = RouteExplorerCategory.values[index];
                            return _MapCategoryOption(
                              icon: _poiIcon(category),
                              label: category.label,
                              selected: settings.categories.contains(category),
                              onTap: () => unawaited(
                                _routeExplorer.toggleCategory(category),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
                _MapSettingsSection(
                  icon: Icons.notifications_active_outlined,
                  title: 'Alertas',
                  trailingText: settings.alertsEnabled ? 'Ativos' : 'Desativados',
                  children: [
                    _MapCompactSwitch(
                      icon: Icons.notifications_active_outlined,
                      title: 'Ativar alertas',
                      subtitle: 'Avisos de aproximação das categorias selecionadas.',
                      value: settings.alertsEnabled,
                      onChanged: (value) => unawaited(
                        _routeExplorer.setAlertsEnabled(value),
                      ),
                    ),
                    _MapCompactSwitch(
                      icon: Icons.record_voice_over_outlined,
                      title: 'Falar aviso',
                      value: settings.voiceEnabled,
                      onChanged: settings.alertsEnabled
                          ? (value) => unawaited(
                                _routeExplorer.setVoiceEnabled(value),
                              )
                          : null,
                    ),
                    _MapCompactSwitch(
                      icon: Icons.phone_android_rounded,
                      title: 'Notificação Android',
                      value: settings.notificationEnabled,
                      onChanged: settings.alertsEnabled
                          ? (value) => unawaited(
                                _routeExplorer.setNotificationEnabled(value),
                              )
                          : null,
                    ),
                    const SizedBox(height: 8),
                    const _MapSettingsTitle('Distância do primeiro aviso'),
                    Row(
                      children: [
                        for (var index = 0; index < alertDistanceOptions.length; index++) ...[
                          if (index > 0) const SizedBox(width: 6),
                          Expanded(
                            child: ChoiceChip(
                              label: Center(
                                child: Text(
                                  '${alertDistanceOptions[index] ~/ 1000} km',
                                ),
                              ),
                              selected: settings.alertDistanceMeters == alertDistanceOptions[index],
                              showCheckmark: false,
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              onSelected: settings.alertsEnabled
                                  ? (_) => unawaited(
                                        _routeExplorer.setAlertDistanceMeters(
                                          alertDistanceOptions[index],
                                        ),
                                      )
                                  : null,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                _MapSettingsSection(
                  icon: Icons.volume_up_outlined,
                  title: 'Áudio',
                  trailingText: navigationVoice ||
                          settings.voiceEnabled ||
                          weatherVoice ||
                          aiVoice
                      ? 'Personalizado'
                      : 'Mudo',
                  children: [
                    _MapCompactSwitch(
                      icon: Icons.navigation_rounded,
                      title: 'Navegação',
                      subtitle: 'Manobras, recálculo e orientação.',
                      value: navigationVoice,
                      onChanged: (value) => unawaited(
                        _mapViewSettings.setNavigationVoiceEnabled(value),
                      ),
                    ),
                    _MapCompactSwitch(
                      icon: Icons.location_on_outlined,
                      title: 'Pontos próximos',
                      value: settings.voiceEnabled,
                      onChanged: (value) => unawaited(
                        _routeExplorer.setVoiceEnabled(value),
                      ),
                    ),
                    _MapCompactSwitch(
                      icon: Icons.cloud_outlined,
                      title: 'Clima',
                      value: weatherVoice,
                      onChanged: (value) => unawaited(
                        _mapViewSettings.setWeatherVoiceEnabled(value),
                      ),
                    ),
                    _MapCompactSwitch(
                      icon: Icons.visibility_outlined,
                      title: 'IA / Detecções',
                      value: aiVoice,
                      onChanged: (value) => unawaited(
                        _setAiVoiceEnabled(value).then((_) {
                          if (sheetContext.mounted) setSheetState(() {});
                        }),
                      ),
                    ),
                  ],
                ),
                _MapSettingsSection(
                  icon: Icons.download_for_offline_outlined,
                  title: 'Mapas offline',
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          unawaited(_openOfflineMaps());
                        },
                        icon: const Icon(Icons.download_for_offline_outlined),
                        label: const Text('Gerenciar mapas offline'),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pacotes MBTiles e mapas baixados continuam disponíveis como fallback sem internet.',
                      style: Theme.of(sheetContext).textTheme.bodySmall,
                    ),
                  ],
                ),
                _MapSettingsSection(
                  icon: Icons.timeline_rounded,
                  title: 'Gravação de percurso',
                  trailingText: recording ? (paused ? 'Pausada' : 'Gravando') : 'Parada',
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: recording
                                ? _togglePauseRecording
                                : () => unawaited(_startRecording()),
                            icon: Icon(
                              recording
                                  ? (paused
                                      ? Icons.play_arrow_rounded
                                      : Icons.pause_rounded)
                                  : Icons.fiber_manual_record_rounded,
                            ),
                            label: Text(
                              recording
                                  ? (paused ? 'Continuar' : 'Pausar')
                                  : 'Iniciar',
                            ),
                          ),
                        ),
                        if (recording) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => unawaited(_finishRecording()),
                              icon: const Icon(Icons.stop_rounded),
                              label: const Text('Finalizar'),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: hasRoutePoints
                            ? () => unawaited(_exportGpx())
                            : null,
                        icon: const Icon(Icons.file_upload_outlined),
                        label: const Text('Exportar percurso em GPX'),
                      ),
                    ),
                  ],
                ),
                _MapSettingsSection(
                  icon: Icons.navigation_outlined,
                  title: 'Navegação',
                  trailingText: orientationMode.label,
                  children: [
                    const _MapSettingsTitle('Orientação do mapa'),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<MapOrientationMode>(
                        segments: const [
                          ButtonSegment(
                            value: MapOrientationMode.northUp,
                            icon: Icon(Icons.north_rounded, size: 17),
                            label: Text('Norte'),
                          ),
                          ButtonSegment(
                            value: MapOrientationMode.directionUp,
                            icon: Icon(Icons.explore_rounded, size: 17),
                            label: Text('Direção'),
                          ),
                          ButtonSegment(
                            value: MapOrientationMode.routeUp,
                            icon: Icon(Icons.alt_route_rounded, size: 17),
                            label: Text('Rota'),
                          ),
                        ],
                        selected: <MapOrientationMode>{orientationMode},
                        showSelectedIcon: false,
                        onSelectionChanged: (selection) => unawaited(
                          _setOrientationMode(
                            selection.first,
                            showUnavailableNotice: false,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'O modo de transporte continua sendo escolhido antes de iniciar cada rota e a última opção fica salva.',
                      style: Theme.of(sheetContext).textTheme.bodySmall,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Text(
                    'A busca “No caminho” pode se atualizar durante o deslocamento mesmo sem gravar percurso. Se a rede falhar, o mapa usa o conteúdo offline disponível.',
                    style: Theme.of(sheetContext).textTheme.bodySmall,
                  ),
                ),
              ],
            );
            },
          ),
        ),
      ),
    );
    if (returnToNearby && mounted) {
      unawaited(_showNearbyPoints());
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

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mapAppearance = _resolvedMapAppearance(theme.brightness);
    final mapPalette = MapAppearancePolicy.palette(mapAppearance);
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
    final selectedMapLocation = _selectedMapLocation;
    final showSelectedMapLocationCard = selectedMapLocation != null &&
        navigationTarget?.sourceId != selectedMapLocation.id;

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
    final stadiaVectorStyle = switch (mapAppearance) {
      MapAppearancePreset.dark =>
        _offlineMaps.stadiaVectorStyleUrl('alidade_smooth_dark'),
      MapAppearancePreset.bikeTravel =>
        _offlineMaps.stadiaVectorStyleUrl('outdoors'),
      MapAppearancePreset.standard =>
        _offlineMaps.stadiaVectorStyleUrl('outdoors'),
      MapAppearancePreset.highContrast => null,
    };
    final navigation3dStyleUrl =
        stadiaVectorStyle ?? mapPalette.vectorStyleUrl;
    final navigation3dFallbackStyleUrl = stadiaVectorStyle != null
        ? mapPalette.vectorStyleUrl
        : mapPalette.vectorStyleUrl != _openFreeMapVectorStyleUrl
            ? _openFreeMapVectorStyleUrl
            : null;
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
    final bikeSnapshot = _bikeSensors.snapshot;
    final rapidPressureLoss = _bikePressureSafety.mostRecentRapidLoss;
    final bikeHealth = bikeSnapshot?.health ?? BikeSensorHealth.disconnected;
    final bikeButtonColor = rapidPressureLoss != null ||
            bikeHealth == BikeSensorHealth.critical
        ? scheme.error
        : bikeHealth == BikeSensorHealth.warning
            ? Colors.orange.shade800
            : bikeHealth == BikeSensorHealth.normal
                ? Colors.green.shade700
                : scheme.surfaceContainerHighest;
    final bikeButtonForeground = bikeHealth == BikeSensorHealth.disconnected &&
            rapidPressureLoss == null
        ? scheme.onSurfaceVariant
        : Colors.white;

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
          final showDockedNavigationBanner = compactHud &&
              navigationTarget != null &&
              _navigationPanelMinimized &&
              !_routeState.recording;
          final floatingCardBottomInset = !compactHud
              ? 82.0
              : navigationTarget == null
                  ? 82.0
                  : showDockedNavigationBanner
                      ? 96.0
                      : (_navigationPanelMinimized ? 176.0 : 360.0);
          final telemetryTop = topInset + MapUxPolicy.controlSize + 10;
          final telemetryHeight = compactHud ? 42.0 : 64.0;
          final nearbyTop = telemetryTop + telemetryHeight + 8;
          final nearbyHeight = compactHud ? 44.0 : 52.0;
          final routeOverviewTop = nearbyTop + nearbyHeight + 7;
          final cameraButtonTop = routeOverviewTop +
              (navigationTarget != null && !compactHud ? 62.0 : 0.0) + 8;
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
                  onTap: (_, point) {
                    unawaited(_selectFreeMapPoint(point));
                  },
                ),
                children: [
                  if (useOfflineLayer)
                    _applyRasterAppearance(
                      TileLayer(
                        key: ValueKey<String>(
                          'offline-${_offlineTilePackageId ?? 'active'}',
                        ),
                        tileProvider: offlineProvider,
                        tileDisplay: TileDisplay.instantaneous(opacity: 1),
                        minNativeZoom: _offlineMinNativeZoom,
                        maxNativeZoom: _offlineMaxNativeZoom,
                      ),
                      mapAppearance,
                    ),
                  if (useOnline)
                    _applyRasterAppearance(
                      TileLayer(
                        key: ValueKey<String>(
                          'online-${_mapViewSettings.stylePreset.name}-${mapAppearance.name}',
                        ),
                        urlTemplate: onlineLayer.urlTemplate,
                        userAgentPackageName: 'com.vigiaia.app',
                        maxNativeZoom: onlineLayer.maxNativeZoom,
                        subdomains: onlineLayer.subdomains,
                      ),
                      mapAppearance,
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
                              color: mapPalette.routeCasingColor.withValues(
                                alpha: 0.46,
                              ),
                            ),
                        if (_cyclingRoute != null)
                          Polyline(
                            points: _cyclingRoute!.points,
                            strokeWidth: 10,
                            color: mapPalette.routeCasingColor.withValues(
                              alpha: 0.92,
                            ),
                          ),
                        if (_cyclingRoute != null)
                          Polyline(
                            points: _cyclingRoute!.points,
                            strokeWidth: 6,
                            color: mapPalette.routeColor,
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
                              color: mapPalette.routeColor,
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
                      if (selectedMapLocation != null &&
                          navigationTarget?.sourceId != selectedMapLocation.id)
                        Marker(
                          point: LatLng(
                            selectedMapLocation.latitude,
                            selectedMapLocation.longitude,
                          ),
                          width: 46,
                          height: 46,
                          rotate: true,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: scheme.primaryContainer.withValues(alpha: 0.95),
                              border: Border.all(color: scheme.primary, width: 2.5),
                              boxShadow: const [
                                BoxShadow(blurRadius: 6, color: Color(0x40000000)),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.place_rounded,
                              color: scheme.onPrimaryContainer,
                              size: 25,
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
                                color: mapPalette.destinationColor.withValues(alpha: 0.18),
                                border: Border.all(
                                  color: mapPalette.destinationColor,
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
                                color: mapPalette.destinationColor,
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
                              color: mapPalette.currentPositionColor.withValues(alpha: 0.18),
                            ),
                            alignment: Alignment.center,
                            child: Container(
                              width: 31,
                              height: 31,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: mapPalette.currentPositionColor,
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
                          'nav3d-${navigationTarget.sourceId ?? navigationTarget.label}-${navigationTarget.travelMode.storageValue}-${mapAppearance.name}-${stadiaVectorStyle != null ? 'stadia' : 'openfreemap'}',
                        ),
                        target: navigationTarget,
                        route: _cyclingRoute!,
                        current: current,
                        orientationMode: _mapViewSettings.orientationMode,
                        sensorHeadingDegrees: _sensorHeadingDegrees,
                        distanceToNextManeuverMeters:
                            _navigationProgress?.distanceToNextManeuverMeters,
                        vectorStyleUrl: navigation3dStyleUrl,
                        fallbackVectorStyleUrl: navigation3dFallbackStyleUrl,
                        appearancePreset: mapAppearance,
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
                height: cameraButtonTop + 18,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          const Color(0xED061D30),
                          const Color(0xBA09283B),
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
                child: compactHud
                    ? _MapControlButton(
                        tooltip: 'Configurações do mapa',
                        icon: Icons.settings_rounded,
                        onPressed: () => unawaited(_showMapOptions()),
                      )
                    : _MapBrandButton(onTap: () => unawaited(_showMapOptions())),
              ),
              Positioned(
                top: topInset,
                left: MapUxPolicy.controlEdge +
                    (compactHud ? MapUxPolicy.controlSize : 89) + 6,
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
                  tooltip: 'Aparência e camadas do mapa',
                  icon: Icons.layers_rounded,
                  active: offlineProvider != null ||
                      networkOffline ||
                      mapAppearance != MapAppearancePreset.standard,
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
                  weather: _weather.snapshot,
                  onSpeedTap: () => unawaited(_showSpeedDetails()),
                  onAltitudeTap: () => unawaited(_showAltitudeDetails()),
                  onCompassTap: () => unawaited(_showCompassDetails()),
                  onGpsTap: () => unawaited(_showGpsDetails()),
                  onWeatherTap: () => unawaited(_showWeatherDetails()),
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
                  routeActive: navigationTarget != null && _routeExplorer.settings.searchAheadWhenMoving,
                  points: _routeExplorer.activeResults,
                  onTap: () => unawaited(_showNearbyPoints()),
                ),
              ),
              if (navigationTarget != null && !compactHud)
                Positioned(
                  top: routeOverviewTop,
                  left: MapUxPolicy.controlEdge,
                  right: MapUxPolicy.controlEdge,
                  height: 62,
                  child: _MapRouteOverview(
                    target: navigationTarget,
                    route: _cyclingRoute,
                    progress: _navigationProgress,
                    bikeEstimate: _bikeTripEstimate,
                    onTap: () => setState(() {
                      _selectedPoiId = null;
                      _selectedMapLocation = null;
                      _navigationPanelMinimized = false;
                    }),
                  ),
                ),
              if (rapidPressureLoss != null)
                Positioned(
                  top: cameraButtonTop,
                  left: MapUxPolicy.controlEdge + MapUxPolicy.controlSize + 12,
                  right: MapUxPolicy.controlEdge + MapUxPolicy.controlSize + 12,
                  child: _BikeRapidPressureAlertBanner(
                    alert: rapidPressureLoss,
                    onTap: () => unawaited(_showBikePanel()),
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
                    _MapControlGap(horizontal: horizontalControls),
                    _MapControlButton(
                      tooltip: 'Pesquisar no mapa',
                      icon: Icons.search_rounded,
                      onPressed: current == null
                          ? null
                          : () => unawaited(_showDestinationSearch()),
                    ),
                    _MapControlGap(horizontal: horizontalControls),
                    _MapControlButton(
                      tooltip: rapidPressureLoss != null
                          ? 'Bike · perda rápida de pressão'
                          : bikeSnapshot?.connected == true
                              ? 'Bike · sensores conectados'
                              : 'Bike · ESP32 sem dados',
                      icon: Icons.pedal_bike_rounded,
                      active: bikeSnapshot?.connected == true || rapidPressureLoss != null,
                      backgroundColor: bikeButtonColor,
                      foregroundColor: bikeButtonForeground,
                      badge: rapidPressureLoss != null ? '!' : null,
                      onPressed: () => unawaited(_showBikePanel()),
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
                        badge: MapUxPolicy.compactCountBadge(
                          _routeExplorer.activeResults.length,
                        ),
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
              if (showSelectedMapLocationCard)
                Positioned(
                  left: compactHud ? 10 : 8,
                  right: compactHud ? 10 : 8,
                  bottom: bottomInset + floatingCardBottomInset,
                  child: _SelectedMapLocationCard(
                    item: selectedMapLocation,
                    distanceLabel: _formatSearchDistance(
                      selectedMapLocation.distanceMeters,
                    ),
                    onClose: () => setState(() => _selectedMapLocation = null),
                    onDetails: () => unawaited(_showMapLocationDetails(selectedMapLocation)),
                    onNavigate: () => _navigateToSearchResult(selectedMapLocation),
                    onAddStop: () => _addManualTripStop(selectedMapLocation),
                  ),
                ),
              if (showSelectedPoiCard)
                Positioned(
                  left: compactHud ? 10 : 8,
                  right: compactHud ? 10 : 8,
                  bottom: bottomInset + floatingCardBottomInset,
                  child: _SelectedPoiCard(
                    item: selectedPoi,
                    distanceLabel:
                        _routeExplorer.formatDistance(selectedPoi.distanceMeters),
                    icon: _poiIcon(selectedPoi.category),
                    compact: compactHud,
                    onClose: () => setState(() => _selectedPoiId = null),
                    onDetails: () => unawaited(_showPoiDetails(selectedPoi)),
                    onAddStop: () => _addManualTripStop(MapDestinationSearchResult(
                      id: selectedPoi.id,
                      title: selectedPoi.title,
                      subtitle: selectedPoi.subtitle,
                      latitude: selectedPoi.latitude,
                      longitude: selectedPoi.longitude,
                      distanceMeters: selectedPoi.distanceMeters,
                      kind: MapDestinationKind.pointOfInterest,
                      source: selectedPoi.source,
                      poiCategory: selectedPoi.category,
                    )),
                    onNavigate: () => _navigateToPoi(selectedPoi),
                  ),
                ),
              if (navigationTarget != null &&
                  (compactHud || (!showSelectedPoiCard && !showSelectedMapLocationCard)) &&
                  !showDockedNavigationBanner)
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
                    bikeEstimate: _bikeTripEstimate,
                    bikeTripPlan: _bikeTripPlan,
                    bikeTripPlanLoading: _bikeTripPlanLoading,
                    loadingRoadRoute: _cyclingRouteLoading,
                    fallbackMessage: _routeFallback?.message,
                    networkOffline: networkOffline,
                    compact: compactHud,
                    minimized: _navigationPanelMinimized,
                    docked: false,
                    following: navigation3dActive ? _navigation3dFollowing : _followPosition,
                    nearbyPoints: _routeExplorer.activeResults,
                    onRouteSelected: _selectCyclingRoute,
                    onToggleMinimized: () => setState(
                      () => _navigationPanelMinimized = !_navigationPanelMinimized,
                    ),
                    onFollowRequested: current == null
                        ? null
                        : () {
                            if (navigation3dActive) {
                              _recenterNavigation3d();
                            } else if (!_followPosition) {
                              _toggleFollow();
                            }
                          },
                    onTripPlan: _bikeTripPlan == null
                        ? null
                        : () => unawaited(_showBikeTripPlan()),
                    onStop: _stopNavigation,
                  ),
                ),
              if (showDockedNavigationBanner)
                Positioned(
                  left: 8,
                  right: MapUxPolicy.controlEdge,
                  bottom: bottomInset + 2,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: _NavigationBanner(
                          target: navigationTarget,
                          distanceMeters: _routeState.navigationDistanceMeters,
                          bearingDegrees: _routeState.navigationBearingDegrees,
                          roadRoute: _cyclingRoute,
                          routeAlternatives: _cyclingRouteAlternatives,
                          selectedRouteIndex: _selectedCyclingRouteIndex,
                          guidance: _navigationProgress,
                          bikeEstimate: _bikeTripEstimate,
                          bikeTripPlan: _bikeTripPlan,
                          bikeTripPlanLoading: _bikeTripPlanLoading,
                          loadingRoadRoute: _cyclingRouteLoading,
                          fallbackMessage: _routeFallback?.message,
                          networkOffline: networkOffline,
                          compact: true,
                          minimized: true,
                          docked: true,
                          following: navigation3dActive
                              ? _navigation3dFollowing
                              : _followPosition,
                          nearbyPoints: _routeExplorer.activeResults,
                          onRouteSelected: _selectCyclingRoute,
                          onToggleMinimized: () => setState(
                            () => _navigationPanelMinimized = false,
                          ),
                          onFollowRequested: current == null
                              ? null
                              : () {
                                  if (navigation3dActive) {
                                    _recenterNavigation3d();
                                  } else if (!_followPosition) {
                                    _toggleFollow();
                                  }
                                },
                          onTripPlan: _bikeTripPlan == null
                              ? null
                              : () => unawaited(_showBikeTripPlan()),
                          onStop: _stopNavigation,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _RouteButtonBar(
                        recording: _routeState.recording,
                        paused: _routeState.paused,
                        hasRoute: _routeState.route.length >= 2,
                        routeState: _routeState,
                        distanceLabel: _formatDistance(),
                        onToggleRecording: current == null
                            ? null
                            : _routeState.recording
                                ? () => unawaited(_finishRecording())
                                : () => unawaited(_startRecording()),
                        onTogglePause: _routeState.recording
                            ? _togglePauseRecording
                            : null,
                        onExport: _routeState.route.length >= 2
                            ? () => unawaited(_exportGpx())
                            : null,
                      ),
                    ],
                  ),
                )
              else
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
                            ? () => unawaited(_finishRecording())
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
              if (_fullscreenCameraSecondary != null)
                _buildFullscreenCamera(
                  context,
                  secondary: _fullscreenCameraSecondary!,
                ),
            ],
          );
        },
      ),
    ),
    );
  }

  Widget _buildFullscreenCamera(
    BuildContext context, {
    required bool secondary,
  }) {
    final previewBuilder = _cameraPreviewBuilderFor(secondary);
    if (previewBuilder == null) {
      return const SizedBox.shrink();
    }
    final listenable = _cameraListenableFor(secondary);

    Widget buildFullscreen(BuildContext context) {
      final safePadding = MediaQuery.paddingOf(context);
      final label = _activeCameraLabel(secondary);
      final aiStatus = _aiStatusForPip(secondary);
      final bikeApproach = _bikeApproachForPip(secondary);

      return Positioned.fill(
        child: Material(
          color: Colors.black,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: _closeCameraFullscreen,
            child: Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(child: previewBuilder(context)),
                Positioned(
                  left: 12,
                  top: safePadding.top + 10,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.58),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              secondary
                                  ? Icons.filter_2_rounded
                                  : Icons.videocam_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  top: safePadding.top + 6,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.58),
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Voltar ao mapa',
                      onPressed: _closeCameraFullscreen,
                      icon: const Icon(
                        Icons.fullscreen_exit_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                if (aiStatus != null)
                  Positioned(
                    left: 12,
                    right: 72,
                    bottom: safePadding.bottom +
                        (bikeApproach == null ? 46 : 82),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: MapAiStatusOverlay(status: aiStatus),
                    ),
                  ),
                if (bikeApproach != null)
                  Positioned(
                    left: 12,
                    right: 72,
                    bottom: safePadding.bottom + 44,
                    child: MapBikeApproachOverlay(status: bikeApproach),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: safePadding.bottom + 8,
                  child: const IgnorePointer(
                    child: Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0x99000000),
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          child: Text(
                            'Toque duas vezes para voltar ao mapa',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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

    if (listenable == null) return buildFullscreen(context);
    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) => buildFullscreen(context),
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
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _openCameraFullscreen(secondary),
                        child: RepaintBoundary(child: previewBuilder(context)),
                      ),
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

class _MapBrandButton extends StatelessWidget {
  const _MapBrandButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Vigia IA · configurações do mapa',
    child: Material(
      color: const Color(0xF0081D31),
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: SizedBox(
          width: 89,
          height: MapUxPolicy.controlSize,
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.terrain_rounded, size: 22, color: Color(0xFF19D2BC)),
            SizedBox(width: 3),
            Text('Vigia IA', style: TextStyle(color: Colors.white,
              fontWeight: FontWeight.w900, fontSize: 11)),
          ]),
        ),
      ),
    ),
  );
}

class _MapRouteOverview extends StatelessWidget {
  const _MapRouteOverview({
    required this.target,
    required this.route,
    required this.progress,
    required this.bikeEstimate,
    required this.onTap,
  });

  final MapNavigationTarget target;
  final MapCyclingRoute? route;
  final MapNavigationProgress? progress;
  final BikeTripEstimate? bikeEstimate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final distance = progress?.remainingDistanceMeters ?? route?.distanceMeters;
    final seconds = bikeEstimate == null
        ? progress?.remainingDurationSeconds ?? route?.durationSeconds
        : distance == null || bikeEstimate!.preferences.averageSpeedKmh <= 0
            ? null
            : distance / 1000 / bikeEstimate!.preferences.averageSpeedKmh * 3600;
    final arrival = seconds != null && seconds.isFinite && seconds >= 0
        ? DateTime.now().add(Duration(seconds: seconds.round()))
        : null;
    final eta = arrival == null
        ? '--:--'
        : '${arrival.hour.toString().padLeft(2, '0')}:${arrival.minute.toString().padLeft(2, '0')}';
    final distanceLabel = distance == null
        ? 'Calculando rota'
        : '${(distance / 1000).toStringAsFixed(1)} km · '
          '${seconds == null ? '--' : '${(seconds / 60).round()} min'}';
    const accent = Color(0xFF10B9F5);
    return Material(
      color: const Color(0xF3071B2D),
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: const BorderSide(color: accent, width: 4),
                top: BorderSide(color: accent.withValues(alpha: 0.25)),
                right: BorderSide(color: accent.withValues(alpha: 0.25)),
                bottom: BorderSide(color: accent.withValues(alpha: 0.25))),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 9),
          child: Row(children: [
            const Icon(Icons.near_me_rounded, color: accent, size: 24),
            const SizedBox(width: 7),
            Expanded(
              flex: 5,
              child: Column(mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Rota ativa', style: TextStyle(color: accent,
                    fontSize: 11, fontWeight: FontWeight.w900)),
                  Text(target.label, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 10)),
                ]),
            ),
            const _MapOverviewDivider(),
            const Tooltip(
              message: 'O provedor desta rota ainda não informa o perfil de elevação.',
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('Subidas', style: TextStyle(color: Color(0xFFB6C8D7), fontSize: 9)),
                Text('--', style: TextStyle(color: Colors.white,
                  fontSize: 15, fontWeight: FontWeight.w900)),
              ]),
            ),
            const SizedBox(width: 7),
            const _MapOverviewDivider(),
            const SizedBox(width: 7),
            Expanded(flex: 4, child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Chegada', style: TextStyle(
                  color: Color(0xFFB6C8D7), fontSize: 9)),
                Text(eta, style: const TextStyle(color: Colors.white,
                  fontSize: 16, fontWeight: FontWeight.w900)),
                Text(distanceLabel, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFFB6C8D7), fontSize: 9)),
              ],
            )),
            const Icon(Icons.chevron_right_rounded, color: accent, size: 20),
          ]),
        ),
      ),
    );
  }
}

class _MapOverviewDivider extends StatelessWidget {
  const _MapOverviewDivider();

  @override
  Widget build(BuildContext context) => Container(
    height: 34, width: 1, margin: const EdgeInsets.symmetric(horizontal: 7),
    color: const Color(0xFF38546A),
  );
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
    return Material(
      elevation: 4,
      color: const Color(0xF2081D31),
      borderRadius: BorderRadius.circular(30),
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

    return SizedBox(
      height: 76,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: borderColor,
            width: selected ? 1.6 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 27, color: foreground),
                      const SizedBox(height: 5),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          mode.label,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (selected)
                Positioned(
                  top: 5,
                  right: 5,
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 15,
                    color: scheme.primary,
                  ),
                ),
            ],
          ),
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
    final enabled = onPressed != null;
    final foreground = !enabled
        ? Colors.white38
        : active ? Colors.white : const Color(0xFFC5D4E0);
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
          color: active ? const Color(0xFF0D3955) : Colors.transparent,
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
    required this.routeActive,
    required this.points,
    required this.onTap,
  });

  final int count;
  final bool loading;
  final bool offline;
  final bool routeActive;
  final List<RouteExplorerResult> points;
  final VoidCallback onTap;

  String _distance(double meters) {
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _categoryLabel(RouteExplorerCategory category) => switch (category) {
        RouteExplorerCategory.water => 'Água',
        RouteExplorerCategory.fuel => 'Posto',
        RouteExplorerCategory.restaurant => 'Comida',
        RouteExplorerCategory.market => 'Mercado',
        RouteExplorerCategory.health => 'Saúde',
        RouteExplorerCategory.camping => 'Camping',
        RouteExplorerCategory.stop => 'Parada',
        RouteExplorerCategory.workshop => 'Oficina',
        RouteExplorerCategory.viewpoint => 'Mirante',
        RouteExplorerCategory.waterfall => 'Cachoeira',
        RouteExplorerCategory.riverBridge => 'Rio/ponte',
      };

  String _summary() {
    if (points.isEmpty) {
      return 'Postos, comida, saúde, água e outros';
    }
    final sorted = List<RouteExplorerResult>.from(points)
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    final seen = <RouteExplorerCategory>{};
    final parts = <String>[];
    for (final item in sorted) {
      if (!seen.add(item.category)) continue;
      parts.add('${_categoryLabel(item.category)} ${_distance(item.distanceMeters)}');
      if (parts.length == 2) break;
    }
    return parts.isEmpty ? 'Pontos disponíveis no mapa' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final badge = MapUxPolicy.compactCountBadge(count) ?? '0';
    final sourceLabel = offline ? 'Offline' : 'Online';
    final title = routeActive ? 'Próximos na rota' : 'Locais próximos';
    final subtitle = count > 0 ? _summary() : 'Postos, comida, saúde, água e outros';

    return Material(
      elevation: 2,
      color: const Color(0xF3071B2D),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            children: [
              Icon(
                Icons.location_on_rounded,
                size: 26,
                color: const Color(0xFF12BDFC),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (loading) ...[
                          const SizedBox(width: 6),
                          const SizedBox(
                            width: 11,
                            height: 11,
                            child: CircularProgressIndicator(strokeWidth: 1.6),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFFB6C8D7),
                            fontSize: 9.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                constraints: const BoxConstraints(minWidth: 24),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF007C72),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  badge,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF123D54),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  sourceLabel,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right_rounded,
                size: 19,
                color: Colors.white,
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
        width: horizontal ? 1 : 24,
        height: horizontal ? 24 : 1,
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
      elevation: 2,
      color: scheme.surface.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(20),
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

class _BikeRapidPressureAlertBanner extends StatelessWidget {
  const _BikeRapidPressureAlertBanner({
    required this.alert,
    required this.onTap,
  });

  final BikeRapidPressureLoss alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label:
          '${alert.tire.label}. Perda rápida de pressão. ${alert.previousPsi.toStringAsFixed(0)} para ${alert.currentPsi.toStringAsFixed(0)} PSI.',
      child: Material(
        elevation: 8,
        color: scheme.errorContainer.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(alert.prominent ? 18 : 28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: alert.prominent
                ? const EdgeInsets.symmetric(horizontal: 14, vertical: 12)
                : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: scheme.onErrorContainer,
                  size: alert.prominent ? 28 : 20,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${alert.tire.label.toUpperCase()} · PERDA RÁPIDA',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onErrorContainer,
                          fontWeight: FontWeight.w900,
                          fontSize: alert.prominent ? 14 : 12,
                        ),
                      ),
                      Text(
                        '${alert.previousPsi.toStringAsFixed(0)} → ${alert.currentPsi.toStringAsFixed(0)} PSI'
                        '${alert.prominent ? ' · Reduza e pare em segurança.' : ''}',
                        maxLines: alert.prominent ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onErrorContainer,
                          fontWeight: FontWeight.w700,
                          fontSize: alert.prominent ? 13 : 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onErrorContainer,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BikeMapPanel extends StatelessWidget {
  const _BikeMapPanel({
    required this.sensors,
    required this.safety,
  });

  final BikeSensorService sensors;
  final BikePressureSafetyService safety;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: safety,
        builder: (context, _) => ListenableBuilder(
          listenable: sensors,
          builder: (context, _) {
            final snapshot = sensors.snapshot;
            final frontRapid =
                safety.activeRapidLosses[BikeTirePosition.front];
            final rearRapid = safety.activeRapidLosses[BikeTirePosition.rear];
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.pedal_bike_rounded, size: 26),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Bike · pneus e ESP32',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              snapshot?.simulated == true
                                  ? 'SIMULAÇÃO · mesma fonte de dados do Monitoramento'
                                  : snapshot?.connected == true
                                      ? 'ESP32 conectado · telemetria compartilhada'
                                      : 'ESP32 desconectado ou sem dados',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _BikeTireCard(
                    title: 'PNEU DIANTEIRO',
                    psi: snapshot?.frontTirePsi,
                    available: snapshot?.frontTirePressureAvailable == true,
                    connected: snapshot?.connected == true,
                    minimumPsi: snapshot?.minimumTirePressurePsi ?? 30,
                    criticalPsi: snapshot?.criticalTirePressurePsi ?? 24,
                    rapidLoss: frontRapid,
                  ),
                  const SizedBox(height: 10),
                  _BikeTireCard(
                    title: 'PNEU TRASEIRO',
                    psi: snapshot?.rearTirePsi,
                    available: snapshot?.rearTirePressureAvailable == true,
                    connected: snapshot?.connected == true,
                    minimumPsi: snapshot?.minimumTirePressurePsi ?? 30,
                    criticalPsi: snapshot?.criticalTirePressurePsi ?? 24,
                    rapidLoss: rearRapid,
                  ),
                  const SizedBox(height: 12),
                  _BikeSensorMetaCard(snapshot: snapshot),
                  if (frontRapid != null || rearRapid != null) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Perda rápida é calculada pela variação temporal e confirmada por leituras subsequentes. Ela é diferente do alerta de pressão baixa.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      );
}

class _BikeTireCard extends StatelessWidget {
  const _BikeTireCard({
    required this.title,
    required this.psi,
    required this.available,
    required this.connected,
    required this.minimumPsi,
    required this.criticalPsi,
    required this.rapidLoss,
  });

  final String title;
  final double? psi;
  final bool available;
  final bool connected;
  final double minimumPsi;
  final double criticalPsi;
  final BikeRapidPressureLoss? rapidLoss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final value = psi ?? 0;
    final (label, color, icon) = rapidLoss != null
        ? ('PERDA RÁPIDA', scheme.error, Icons.trending_down_rounded)
        : !connected || !available
            ? ('SEM DADOS', scheme.outline, Icons.link_off_rounded)
            : value <= criticalPsi
                ? ('CRÍTICA', scheme.error, Icons.error_rounded)
                : value < minimumPsi
                    ? ('PRESSÃO BAIXA', Colors.orange.shade800,
                        Icons.warning_amber_rounded)
                    : ('NORMAL', Colors.green.shade700,
                        Icons.check_circle_rounded);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.36)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (rapidLoss != null)
                    Text(
                      '${rapidLoss!.previousPsi.toStringAsFixed(0)} → ${rapidLoss!.currentPsi.toStringAsFixed(0)} PSI · queda ${rapidLoss!.dropPsi.toStringAsFixed(1)} PSI',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  connected && available ? value.toStringAsFixed(1) : '--',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const Text('PSI', style: TextStyle(fontSize: 11)),
                Text(
                  'limite ${minimumPsi.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BikeSensorMetaCard extends StatelessWidget {
  const _BikeSensorMetaCard({required this.snapshot});

  final BikeSensorSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final item = snapshot;
    final captured = item?.capturedAt;
    final time = captured == null
        ? '--'
        : '${captured.hour.toString().padLeft(2, '0')}:'
            '${captured.minute.toString().padLeft(2, '0')}:'
            '${captured.second.toString().padLeft(2, '0')}';
    final module = item?.simulated == true
        ? 'Emulador ESP32'
        : (item?.moduleId?.trim().isNotEmpty == true
            ? item!.moduleId!
            : 'Não identificado');
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Wrap(
          spacing: 18,
          runSpacing: 10,
          children: [
            _BikeMetaItem(
              icon: item?.connected == true
                  ? Icons.link_rounded
                  : Icons.link_off_rounded,
              label: 'Conexão',
              value: item?.connected == true ? 'Conectado' : 'Sem dados',
            ),
            _BikeMetaItem(
              icon: Icons.memory_rounded,
              label: 'Módulo',
              value: module,
            ),
            _BikeMetaItem(
              icon: Icons.schedule_rounded,
              label: 'Atualização',
              value: time,
            ),
            if (item?.batteryAvailable == true)
              _BikeMetaItem(
                icon: Icons.battery_5_bar_rounded,
                label: 'Bateria sensores',
                value: '${item!.sensorBatteryPercent}%',
              ),
            if (item?.temperatureAvailable == true &&
                item?.ambientTemperatureC != null)
              _BikeMetaItem(
                icon: Icons.thermostat_rounded,
                label: 'Temperatura',
                value: '${item!.ambientTemperatureC!.toStringAsFixed(1)} °C',
              ),
          ],
        ),
      ),
    );
  }
}

class _BikeMetaItem extends StatelessWidget {
  const _BikeMetaItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 142,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.labelSmall),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
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
    this.backgroundColor,
    this.foregroundColor,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool active;
  final String? badge;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    final background = backgroundColor ??
        (active
            ? scheme.primaryContainer.withValues(alpha: 0.96)
            : scheme.surface.withValues(alpha: enabled ? 0.94 : 0.78));
    final foreground = foregroundColor ??
        (active
            ? scheme.onPrimaryContainer
            : enabled
                ? scheme.onSurface
                : scheme.onSurface.withValues(alpha: 0.38));
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: MapUxPolicy.controlSize,
        height: MapUxPolicy.controlSize,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Material(
                elevation: enabled ? 2 : 0,
                color: background,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onPressed,
                  customBorder: const CircleBorder(),
                  child: Center(
                    child: Icon(icon, color: foreground, size: 20),
                  ),
                ),
              ),
            ),
            if (badge != null)
              Positioned(
                right: -4,
                top: -4,
                child: IgnorePointer(
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 16,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: scheme.error,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: scheme.surface, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      badge!,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: TextStyle(
                        color: scheme.onError,
                        fontSize: badge!.length >= 3 ? 8 : 9,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
          ],
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

class _MapSettingsSection extends StatelessWidget {
  const _MapSettingsSection({
    required this.icon,
    required this.title,
    required this.children,
    this.trailingText,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final String? trailingText;
  final bool initiallyExpanded;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 7),
      clipBehavior: Clip.antiAlias,
      color: scheme.surfaceContainerLow,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          minTileHeight: 46,
          leading: Icon(icon, size: 20, color: scheme.primary),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailingText != null) ...[
                Text(
                  trailingText!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              const Icon(Icons.expand_more_rounded),
            ],
          ),
          children: children,
        ),
      ),
    );
  }
}

class _MapCategoryOption extends StatelessWidget {
  const _MapCategoryOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected ? scheme.onPrimaryContainer : scheme.onSurface;
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 1.4 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Icon(icon, size: 17, color: foreground),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 3),
                Icon(Icons.check_rounded, size: 15, color: scheme.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MapCompactSwitch extends StatelessWidget {
  const _MapCompactSwitch({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      dense: true,
      visualDensity: const VisualDensity(vertical: -3),
      secondary: Icon(icon, size: 19, color: scheme.onSurfaceVariant),
      title: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: const TextStyle(fontSize: 10.5),
            ),
      value: value,
      onChanged: onChanged,
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
    required this.onAddStop,
    required this.onNavigate,
    this.compact = false,
  });

  final RouteExplorerResult item;
  final String distanceLabel;
  final IconData icon;
  final VoidCallback onClose;
  final VoidCallback onDetails;
  final VoidCallback onAddStop;
  final VoidCallback onNavigate;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final subtitle = item.subtitle.trim().isNotEmpty
        ? item.subtitle.trim()
        : item.category.label;

    return Material(
      elevation: 9,
      color: const Color(0xF8082033),
      borderRadius: BorderRadius.circular(20),
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
                Container(
                  width: compact ? 45 : 62,
                  height: compact ? 45 : 62,
                  decoration: BoxDecoration(color: const Color(0xFF154962),
                    borderRadius: BorderRadius.circular(13)),
                  child: Icon(
                    icon,
                    size: compact ? 23 : 28,
                    color: const Color(0xFF28C8EF),
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
                          item.category.label,
                          style: const TextStyle(color: Color(0xFFADBED0), fontSize: 10),
                        ),
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFFB7CBD9), fontSize: 11),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Aprox. $distanceLabel · '
                          '${item.source == 'offline' ? 'Offline' : 'Online'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFFB7CBD9), fontSize: 11),
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
                  icon: const Icon(Icons.close_rounded, size: 20, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDetails,
                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact,
                      foregroundColor: const Color(0xFF29C0F6)),
                    icon: const Icon(Icons.info_outline_rounded, size: 18),
                    label: const Text('Detalhes'),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(child: OutlinedButton.icon(
                  onPressed: onAddStop,
                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xFF29C0F6)),
                  icon: const Icon(Icons.bookmark_add_outlined, size: 17),
                  label: const Text('Parada', style: TextStyle(fontSize: 11)),
                )),
                const SizedBox(width: 4),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onNavigate,
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: const Color(0xFF0CB7F4),
                      foregroundColor: const Color(0xFF061B2B),
                    ),
                    icon: const Icon(Icons.navigation_rounded, size: 18),
                    label: const Text('Navegar', style: TextStyle(fontSize: 11)),
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

class _SelectedMapLocationCard extends StatelessWidget {
  const _SelectedMapLocationCard({
    required this.item,
    required this.distanceLabel,
    required this.onClose,
    required this.onDetails,
    required this.onNavigate,
    required this.onAddStop,
  });

  final MapDestinationSearchResult item;
  final String distanceLabel;
  final VoidCallback onClose;
  final VoidCallback onDetails;
  final VoidCallback onNavigate;
  final VoidCallback onAddStop;

  @override
  Widget build(BuildContext context) {
    final identifying = item.title == 'Identificando local…';
    return Material(
      elevation: 9,
      color: const Color(0xF8082033),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(color: const Color(0xFF154962),
                    borderRadius: BorderRadius.circular(13)),
                  child: Icon(
                    item.poiCategory == null
                        ? Icons.place_rounded
                        : Icons.location_on_rounded,
                    color: const Color(0xFF28C8EF),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(onTap: identifying ? null : onDetails,
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.kind.label,
                        style: const TextStyle(color: Color(0xFFADBED0), fontSize: 10)),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle.trim().isEmpty
                            ? '${item.latitude.toStringAsFixed(5)}, ${item.longitude.toStringAsFixed(5)}'
                            : item.subtitle.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFFB7CBD9), fontSize: 11),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$distanceLabel · ${item.kind.label}',
                        style: const TextStyle(color: Color(0xFFB7CBD9), fontSize: 11),
                      ),
                    ],
                  )),
                ),
                if (identifying)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  IconButton(
                    tooltip: 'Fechar',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(
                      width: 34,
                      height: 34,
                    ),
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded, size: 20, color: Colors.white),
                  ),
              ],
            ),
            if (!identifying) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: OutlinedButton.icon(
                    onPressed: onDetails,
                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact,
                      foregroundColor: const Color(0xFF29C0F6)),
                    icon: const Icon(Icons.info_outline_rounded, size: 17),
                    label: const Text('Detalhes', style: TextStyle(fontSize: 11)),
                  )),
                  const SizedBox(width: 4),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onAddStop,
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: const Color(0xFF29C0F6),
                      ),
                      icon: const Icon(Icons.bookmark_add_outlined, size: 17),
                      label: const Text('Parada', style: TextStyle(fontSize: 11)),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onNavigate,
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: const Color(0xFF0CB7F4),
                        foregroundColor: const Color(0xFF061B2B),
                      ),
                      icon: const Icon(Icons.navigation_rounded, size: 18),
                      label: const Text('Navegar', style: TextStyle(fontSize: 11)),
                    ),
                  ),
                ],
              ),
            ],
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

class _MapTelemetryStrip extends StatelessWidget {
  const _MapTelemetryStrip({
    required this.speedKmh,
    required this.altitudeMeters,
    required this.headingDegrees,
    required this.gpsAccuracyMeters,
    required this.orientationMode,
    required this.weather,
    required this.onSpeedTap,
    required this.onAltitudeTap,
    required this.onCompassTap,
    required this.onGpsTap,
    required this.onWeatherTap,
    this.compact = false,
  });

  final double? speedKmh;
  final double? altitudeMeters;
  final double? headingDegrees;
  final double? gpsAccuracyMeters;
  final MapOrientationMode orientationMode;
  final MapWeatherSnapshot weather;
  final VoidCallback onSpeedTap;
  final VoidCallback onAltitudeTap;
  final VoidCallback onCompassTap;
  final VoidCallback onGpsTap;
  final VoidCallback onWeatherTap;
  final bool compact;

  String _direction(double? degrees) {
    if (degrees == null || degrees.isNaN) return '--';
    const labels = ['N', 'NE', 'L', 'SE', 'S', 'SO', 'O', 'NO'];
    final normalized = ((degrees % 360) + 360) % 360;
    final index = ((normalized + 22.5) ~/ 45) % 8;
    return labels[index];
  }

  IconData _weatherIcon(int? code) => switch (code) {
        0 || 1 => Icons.wb_sunny_rounded,
        2 => Icons.wb_cloudy_rounded,
        3 || 45 || 48 => Icons.cloud_rounded,
        51 || 53 || 55 || 56 || 57 => Icons.grain_rounded,
        61 || 63 || 65 || 66 || 67 || 80 || 81 || 82 =>
          Icons.water_drop_rounded,
        71 || 73 || 75 || 77 || 85 || 86 => Icons.ac_unit_rounded,
        95 || 96 || 99 => Icons.thunderstorm_rounded,
        _ => Icons.device_thermostat_rounded,
      };

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
        const SizedBox(width: 5),
        Expanded(
          child: _MapTelemetryCard(
            icon: _weatherIcon(weather.weatherCode?.value),
            value: weather.temperatureC == null
                ? '--'
                : weather.temperatureC!.value.toStringAsFixed(0),
            unit: weather.temperatureC == null ? null : '°C',
            label: weather.origin == MapWeatherOrigin.unavailable
                ? 'Clima'
                : 'Clima · ${weather.origin.label}',
            emphasized: weather.onlineStale,
            onTap: onWeatherTap,
            tooltip:
                'Clima: toque para ver sensores ESP32, dados online e fontes.',
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
    final background = emphasized
        ? const Color(0xF500625F)
        : const Color(0xF2081D31);
    const foreground = Colors.white;
    const iconColor = Color(0xFF16BDF8);

    Widget card = Material(
      elevation: 2,
      color: background,
      borderRadius: BorderRadius.circular(13),
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
                  Icon(icon, size: compact ? 13 : 17, color: iconColor),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: TextStyle(
                        color: foreground.withValues(alpha: 0.72),
                        fontSize: compact ? 7.5 : 9,
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
                          fontSize: compact ? 15 : 20,
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
                            fontSize: compact ? 7 : 9,
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
    required this.bikeEstimate,
    required this.bikeTripPlan,
    required this.bikeTripPlanLoading,
    required this.loadingRoadRoute,
    required this.fallbackMessage,
    required this.networkOffline,
    required this.compact,
    required this.minimized,
    this.docked = false,
    required this.following,
    required this.nearbyPoints,
    required this.onRouteSelected,
    required this.onToggleMinimized,
    required this.onFollowRequested,
    required this.onTripPlan,
    required this.onStop,
  });

  final MapNavigationTarget target;
  final double? distanceMeters;
  final double? bearingDegrees;
  final MapCyclingRoute? roadRoute;
  final List<MapCyclingRoute> routeAlternatives;
  final int selectedRouteIndex;
  final MapNavigationProgress? guidance;
  final BikeTripEstimate? bikeEstimate;
  final BikeTripPlan? bikeTripPlan;
  final bool bikeTripPlanLoading;
  final bool loadingRoadRoute;
  final String? fallbackMessage;
  final bool networkOffline;
  final bool compact;
  final bool minimized;
  final bool docked;
  final bool following;
  final List<RouteExplorerResult> nearbyPoints;
  final ValueChanged<int> onRouteSelected;
  final VoidCallback onToggleMinimized;
  final VoidCallback? onFollowRequested;
  final VoidCallback? onTripPlan;
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
    return rest == 0 ? '${hours}h' : '${hours}h${rest.toString().padLeft(2, '0')}';
  }

  String _bikeDurationForDistance(double meters) {
    final estimate = bikeEstimate;
    if (estimate == null) return '--';
    final speed = estimate.preferences.averageSpeedKmh;
    if (speed <= 0) return '--';
    final seconds = (meters / 1000 / speed * 3600).round();
    return _duration(seconds.toDouble());
  }

  String _bearing(double? degrees) {
    if (degrees == null || !degrees.isFinite) return '--';
    const labels = <String>['N', 'NE', 'L', 'SE', 'S', 'SO', 'O', 'NO'];
    final normalized = ((degrees % 360) + 360) % 360;
    final index = ((normalized + 22.5) ~/ 45) % 8;
    return '${labels[index]} ${normalized.toStringAsFixed(0)}°';
  }

  String _cleanInstruction(String value) {
    final trimmed = value.trim();
    if (trimmed.endsWith('.') || trimmed.endsWith(':')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  IconData _maneuverIcon(String text) {
    final value = text.toLowerCase();
    if (value.contains('esquerda')) return Icons.turn_left_rounded;
    if (value.contains('direita')) return Icons.turn_right_rounded;
    if (value.contains('retorno') || value.contains('volte')) {
      return Icons.u_turn_left_rounded;
    }
    if (value.contains('destino') || value.contains('chegou')) {
      return Icons.flag_rounded;
    }
    return Icons.navigation_rounded;
  }

  RouteExplorerResult? _nearest(Set<RouteExplorerCategory> categories) {
    RouteExplorerResult? best;
    for (final item in nearbyPoints) {
      if (!categories.contains(item.category)) continue;
      if (best == null || item.distanceMeters < best.distanceMeters) {
        best = item;
      }
    }
    return best;
  }

  String _routeDuration(MapCyclingRoute route) {
    final estimate = bikeEstimate;
    if (estimate != null && estimate.preferences.averageSpeedKmh > 0) {
      final seconds = route.distanceMeters / 1000 /
          estimate.preferences.averageSpeedKmh * 3600;
      return _duration(seconds);
    }
    return _duration(route.durationSeconds);
  }

  String _routeDelta(MapCyclingRoute route) {
    if (routeAlternatives.isEmpty ||
        selectedRouteIndex < 0 ||
        selectedRouteIndex >= routeAlternatives.length) {
      return '';
    }
    final selected = routeAlternatives[selectedRouteIndex];
    final distanceDelta = route.distanceMeters - selected.distanceMeters;
    final selectedSeconds = bikeEstimate != null &&
            bikeEstimate!.preferences.averageSpeedKmh > 0
        ? selected.distanceMeters / 1000 /
            bikeEstimate!.preferences.averageSpeedKmh * 3600
        : selected.durationSeconds;
    final routeSeconds = bikeEstimate != null &&
            bikeEstimate!.preferences.averageSpeedKmh > 0
        ? route.distanceMeters / 1000 /
            bikeEstimate!.preferences.averageSpeedKmh * 3600
        : route.durationSeconds;
    final timeDeltaMinutes = ((routeSeconds - selectedSeconds) / 60).round();
    if (distanceDelta.abs() < 50 && timeDeltaMinutes.abs() < 1) return 'Atual';
    final distanceText = distanceDelta.abs() < 50
        ? null
        : '${distanceDelta >= 0 ? '+' : '−'}${_distance(distanceDelta.abs())}';
    final timeText = timeDeltaMinutes == 0
        ? null
        : '${timeDeltaMinutes >= 0 ? '+' : '−'}${timeDeltaMinutes.abs()} min';
    return <String>[?distanceText, ?timeText].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = guidance;
    final route = roadRoute;
    final warning = fallbackMessage != null || networkOffline;

    final currentInstruction = progress?.arrived == true
        ? 'Destino alcançado'
        : progress?.currentInstruction ?? target.label;
    final nextManeuver = progress?.nextInstruction;
    final nextManeuverDistance = progress?.distanceToNextManeuverMeters;
    final hasUpcomingManeuver = progress?.arrived != true &&
        nextManeuver != null &&
        nextManeuverDistance != null;

    final primaryInstruction = hasUpcomingManeuver
        ? '${_cleanInstruction(nextManeuver)} em ${_distance(nextManeuverDistance)}'
        : currentInstruction;

    late final String secondaryInstruction;
    if (progress?.arrived == true) {
      secondaryInstruction = 'Você chegou ao destino.';
    } else if (fallbackMessage != null) {
      secondaryInstruction = fallbackMessage!;
    } else if (loadingRoadRoute && route != null) {
      secondaryInstruction = 'Recalculando rota…';
    } else if (hasUpcomingManeuver) {
      secondaryInstruction = currentInstruction;
    } else if (loadingRoadRoute) {
      secondaryInstruction = 'Calculando rota de ${target.travelMode.routeLabel}…';
    } else if (route != null) {
      secondaryInstruction = 'Siga pela rota destacada até o destino.';
    } else {
      secondaryInstruction =
          '${_distance(distanceMeters)} · ${_bearing(bearingDegrees)} · direção direta';
    }

    final remainingDistance = progress?.remainingDistanceMeters ??
        route?.distanceMeters ??
        distanceMeters;
    final remainingDuration = route == null
        ? null
        : bikeEstimate == null
            ? (progress?.remainingDurationSeconds ?? route.durationSeconds)
            : null;
    final remainingTime = remainingDistance == null
        ? '--'
        : bikeEstimate == null
            ? (remainingDuration == null ? '--' : _duration(remainingDuration))
            : _bikeDurationForDistance(remainingDistance);
    final progressFraction = progress?.progressFraction.clamp(0.0, 1.0).toDouble() ?? 0.0;
    final speedValue = bikeEstimate == null
        ? target.travelMode.routeLabel
        : '${bikeEstimate!.preferences.averageSpeedKmh.toStringAsFixed(0)} km/h';

    final water = _nearest(const <RouteExplorerCategory>{RouteExplorerCategory.water});
    final food = _nearest(const <RouteExplorerCategory>{
      RouteExplorerCategory.restaurant,
      RouteExplorerCategory.market,
    });
    final rest = _nearest(const <RouteExplorerCategory>{
      RouteExplorerCategory.camping,
      RouteExplorerCategory.stop,
      RouteExplorerCategory.viewpoint,
    });
    final stop = _nearest(const <RouteExplorerCategory>{
      RouteExplorerCategory.fuel,
      RouteExplorerCategory.health,
      RouteExplorerCategory.workshop,
    });

    final panelColor = warning
        ? scheme.secondaryContainer.withValues(alpha: 0.97)
        : scheme.surfaceContainerHighest.withValues(alpha: 0.97);
    final foreground = warning ? scheme.onSecondaryContainer : scheme.onSurface;
    final accent = warning ? scheme.secondary : scheme.primary;

    if (minimized) {
      final iconSize = docked ? 40.0 : 52.0;
      final iconGlyphSize = docked ? 24.0 : 31.0;
      return Material(
        elevation: 10,
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(docked ? 18 : 20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: docked ? onToggleMinimized : null,
          child: Container(
            decoration: BoxDecoration(
              color: panelColor,
              border: Border.all(color: accent.withValues(alpha: 0.22)),
            ),
            padding: EdgeInsets.fromLTRB(
              docked ? 9 : 12,
              docked ? 7 : 9,
              docked ? 4 : 8,
              docked ? 7 : 9,
            ),
            child: Row(
              children: [
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.15),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.65),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    _maneuverIcon(primaryInstruction),
                    color: accent,
                    size: iconGlyphSize,
                  ),
                ),
                SizedBox(width: docked ? 8 : 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        primaryInstruction,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground,
                          fontSize: docked ? 13.5 : 15,
                          height: 1.0,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_distance(remainingDistance)} · $remainingTime${following ? '' : ' · mapa livre'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground.withValues(alpha: 0.70),
                          fontSize: docked ? 10.5 : 11,
                          height: 1.0,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!docked && !following && onFollowRequested != null)
                  IconButton(
                    tooltip: 'Voltar a seguir posição',
                    onPressed: onFollowRequested,
                    icon: const Icon(Icons.my_location_rounded),
                  ),
                IconButton(
                  tooltip: 'Expandir navegação',
                  onPressed: onToggleMinimized,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  icon: const Icon(Icons.keyboard_arrow_up_rounded),
                ),
                if (!docked)
                  IconButton(
                    tooltip: 'Parar navegação',
                    onPressed: onStop,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      elevation: 12,
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(compact ? 22 : 26),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              panelColor,
              panelColor.withValues(alpha: 0.94),
              scheme.surface.withValues(alpha: 0.98),
            ],
          ),
          border: Border.all(
            color: accent.withValues(alpha: 0.22),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          compact ? 12 : 16,
          compact ? 9 : 12,
          compact ? 10 : 14,
          compact ? 10 : 14,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Spacer(),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: foreground.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Minimizar navegação',
                  visualDensity: VisualDensity.compact,
                  onPressed: onToggleMinimized,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                ),
              ],
            ),
            if (!following && onFollowRequested != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onFollowRequested,
                  icon: const Icon(Icons.pan_tool_alt_rounded, size: 16),
                  label: const Text('Mapa livre · tocar para seguir'),
                ),
              ),
            SizedBox(height: compact ? 4 : 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: compact ? 68 : 80,
                  height: compact ? 68 : 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.16),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.72),
                      width: 2,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: accent.withValues(alpha: 0.20),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    networkOffline
                        ? Icons.wifi_off_rounded
                        : progress?.offRoute == true
                            ? Icons.alt_route_rounded
                            : _maneuverIcon(primaryInstruction),
                    size: compact ? 40 : 48,
                    color: accent,
                  ),
                ),
                SizedBox(width: compact ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        primaryInstruction,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground,
                          fontSize: compact ? 18 : 22,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        secondaryInstruction,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground.withValues(alpha: 0.72),
                          fontSize: compact ? 12 : 14,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Parar navegação',
                  onPressed: onStop,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            SizedBox(height: compact ? 9 : 12),
            Divider(height: 1, color: foreground.withValues(alpha: 0.12)),
            SizedBox(height: compact ? 9 : 12),
            Row(
              children: [
                Expanded(
                  child: _NavigationMetricCell(
                    icon: Icons.flag_rounded,
                    value: _distance(remainingDistance),
                    label: 'restantes',
                    accent: accent,
                    foreground: foreground,
                    compact: compact,
                  ),
                ),
                Expanded(
                  child: _NavigationMetricCell(
                    icon: Icons.schedule_rounded,
                    value: remainingTime,
                    label: 'tempo estimado',
                    accent: accent,
                    foreground: foreground,
                    compact: compact,
                  ),
                ),
                Expanded(
                  child: _NavigationMetricCell(
                    icon: Icons.speed_rounded,
                    value: speedValue,
                    label: bikeEstimate == null ? 'modo da rota' : 'média no percurso',
                    accent: accent,
                    foreground: foreground,
                    compact: compact,
                  ),
                ),
                Expanded(
                  child: _NavigationMetricCell(
                    icon: Icons.route_rounded,
                    value: '${(progressFraction * 100).round()}%',
                    label: 'concluído',
                    accent: accent,
                    foreground: foreground,
                    compact: compact,
                  ),
                ),
                Expanded(
                  child: _RouteAlternativesButton(
                    routes: routeAlternatives,
                    selectedIndex: selectedRouteIndex,
                    accent: accent,
                    foreground: foreground,
                    compact: compact,
                    distanceLabel: _distance,
                    durationLabel: _routeDuration,
                    deltaLabel: _routeDelta,
                    onSelected: onRouteSelected,
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 9 : 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progressFraction,
                minHeight: compact ? 5 : 7,
                backgroundColor: foreground.withValues(alpha: 0.13),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
            SizedBox(height: compact ? 9 : 12),
            Row(
              children: [
                Expanded(
                  child: _NavigationPoiChip(
                    icon: Icons.water_drop_rounded,
                    label: 'Água',
                    distance: water == null ? '--' : _distance(water.distanceMeters),
                    foreground: foreground,
                    accent: accent,
                    compact: compact,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _NavigationPoiChip(
                    icon: Icons.restaurant_rounded,
                    label: 'Comida',
                    distance: food == null ? '--' : _distance(food.distanceMeters),
                    foreground: foreground,
                    accent: accent,
                    compact: compact,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _NavigationPoiChip(
                    icon: Icons.chair_alt_rounded,
                    label: 'Descanso',
                    distance: rest == null ? '--' : _distance(rest.distanceMeters),
                    foreground: foreground,
                    accent: accent,
                    compact: compact,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _NavigationPoiChip(
                    icon: Icons.local_gas_station_rounded,
                    label: 'Parada',
                    distance: stop == null ? '--' : _distance(stop.distanceMeters),
                    foreground: foreground,
                    accent: accent,
                    compact: compact,
                  ),
                ),
              ],
            ),
            if (bikeTripPlanLoading ||
                (bikeTripPlan != null && bikeTripPlan!.estimate.dayCount > 1)) ...[
              SizedBox(height: compact ? 8 : 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (bikeTripPlanLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (bikeTripPlan != null &&
                      bikeTripPlan!.estimate.dayCount > 1)
                    Tooltip(
                      message: 'Ver plano por dias',
                      child: TextButton.icon(
                        onPressed: onTripPlan,
                        icon: const Icon(Icons.calendar_month_rounded, size: 18),
                        label: Text('Plano de ${bikeTripPlan!.estimate.dayCount} dias'),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RouteAlternativesButton extends StatelessWidget {
  const _RouteAlternativesButton({
    required this.routes,
    required this.selectedIndex,
    required this.accent,
    required this.foreground,
    required this.compact,
    required this.distanceLabel,
    required this.durationLabel,
    required this.deltaLabel,
    required this.onSelected,
  });

  final List<MapCyclingRoute> routes;
  final int selectedIndex;
  final Color accent;
  final Color foreground;
  final bool compact;
  final String Function(double) distanceLabel;
  final String Function(MapCyclingRoute) durationLabel;
  final String Function(MapCyclingRoute) deltaLabel;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final enabled = routes.length > 1;
    return PopupMenuButton<int>(
      enabled: enabled,
      tooltip: enabled ? 'Comparar rotas alternativas' : 'Sem rotas alternativas',
      initialValue: selectedIndex,
      onSelected: onSelected,
      position: PopupMenuPosition.over,
      constraints: const BoxConstraints(minWidth: 245, maxWidth: 310),
      itemBuilder: (context) => <PopupMenuEntry<int>>[
        for (var index = 0; index < routes.length; index++)
          PopupMenuItem<int>(
            value: index,
            child: Row(
              children: [
                Icon(
                  index == selectedIndex ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  size: 18,
                  color: index == selectedIndex ? accent : foreground.withValues(alpha: 0.55),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Rota ${index + 1} · ${distanceLabel(routes[index].distanceMeters)} · ${durationLabel(routes[index])}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      _deltaText(routes[index], deltaLabel, foreground),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 28 : 32,
              height: compact ? 24 : 28,
              decoration: BoxDecoration(
                color: enabled ? accent.withValues(alpha: 0.16) : foreground.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: enabled ? accent.withValues(alpha: 0.36) : foreground.withValues(alpha: 0.08)),
              ),
              child: Icon(Icons.alt_route_rounded, size: compact ? 16 : 18, color: enabled ? accent : foreground.withValues(alpha: 0.42)),
            ),
            const SizedBox(height: 3),
            Text(
              enabled ? '${routes.length} opções' : '1 opção',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: foreground, fontSize: compact ? 10 : 11.5, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 1),
            Text(
              'rotas',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: foreground.withValues(alpha: 0.62), fontSize: compact ? 7.5 : 8.5, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deltaText(
    MapCyclingRoute route,
    String Function(MapCyclingRoute) formatter,
    Color textColor,
  ) {
    final value = formatter(route);
    return Text(
      value.isEmpty ? 'Sem comparação disponível' : value,
      style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.62)),
    );
  }
}

class _NavigationMetricCell extends StatelessWidget {
  const _NavigationMetricCell({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
    required this.foreground,
    required this.compact,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color accent;
  final Color foreground;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 16 : 18, color: accent),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: foreground,
              fontSize: compact ? 12 : 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: foreground.withValues(alpha: 0.62),
              fontSize: compact ? 8 : 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationPoiChip extends StatelessWidget {
  const _NavigationPoiChip({
    required this.icon,
    required this.label,
    required this.distance,
    required this.foreground,
    required this.accent,
    required this.compact,
  });

  final IconData icon;
  final String label;
  final String distance;
  final Color foreground;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 7,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: foreground.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 17 : 20, color: accent),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground,
              fontSize: compact ? 9 : 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            distance,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground.withValues(alpha: 0.68),
              fontSize: compact ? 8 : 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
