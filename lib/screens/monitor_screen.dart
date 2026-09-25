import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_mbtiles/flutter_map_mbtiles.dart';
import 'package:latlong2/latlong.dart';
import '../core/adaptive_camera_layout.dart';
import '../controllers/monitor_controller.dart';
import '../controllers/secondary_camera_controller.dart';
import '../services/app_orientation_service.dart';
import '../services/system_ui_service.dart';
import '../services/bike_sensor_service.dart';
import '../core/video_source_status.dart';
import '../models/bike_approach_status.dart';
import '../models/bike_sensor_snapshot.dart';
import '../models/camera_endpoint.dart';
import '../models/monitoring_zone.dart';
import '../models/device_telemetry.dart';
import '../models/map_route_point.dart';
import '../models/route_explorer_models.dart';
import '../models/offline_map_package.dart';
import '../models/remote_phone_status.dart';
import '../models/video_source_config.dart';
import '../services/native_platform_service.dart';
import '../services/location_tracking_service.dart';
import '../services/map_route_service.dart';
import '../services/offline_map_service.dart';
import '../services/route_explorer_service.dart';
import '../services/camera_registry_service.dart';
import '../services/remote_camera_pairing_service.dart';
import '../widgets/detection_overlay.dart';
import '../widgets/bike_approach_banner.dart';
import '../widgets/bike_ride_hud.dart';
import '../widgets/monitoring_zone_overlay.dart';
import '../widgets/object_filter_dialog.dart';
import '../widgets/remote_bike_status_panel.dart';
import '../widgets/offline_map_manager_sheet.dart';
import '../widgets/session_status_panel.dart';
import '../widgets/smart_alert_rules_dialog.dart';
import 'events_screen.dart';
import 'launch_mode_screen.dart';
import 'map_monitoring_screen.dart';
import 'phone_pairing_scanner_screen.dart';
import 'settings_screen.dart';
part 'monitor_screen_components.dart';
part 'monitor_screen_fullscreen.dart';
part 'monitor_screen_multicamera.dart';
part 'monitor_screen_offline_map.dart';
part 'monitor_screen_portrait.dart';
part 'monitor_screen_landscape_dashboard.dart';
part 'monitor_screen_map_explorer.dart';

enum _MonitorPrimaryContentMode { camera, cameraOff, map }
class MonitorScreen extends StatefulWidget {
  const MonitorScreen({
    super.key,
    required this.initialSource,
    required this.settings,
    this.secondarySource,
  });

  final VideoSourceConfig initialSource;
  final MonitorSettings settings;
  final VideoSourceConfig? secondarySource;

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen>
    with WidgetsBindingObserver {
  late final MonitorController _controller;
  SecondaryCameraController? _secondaryController;
  final CameraRegistryService _cameraRegistry = CameraRegistryService.instance;
  final BikeSensorService _bikeSensors = BikeSensorService.instance;
  final MapRouteService _mapRoute = MapRouteService.instance;
  final OfflineMapService _offlineMaps = OfflineMapService.instance;
  final RouteExplorerService _routeExplorer = RouteExplorerService.instance;
  final MapController _miniMapController = MapController();
  MbTilesTileProvider? _miniOfflineTileProvider;
  String? _miniOfflinePackageId;
  int _miniOfflineMinZoom = 0;
  int _miniOfflineMaxZoom = 19;
  bool _miniMapReady = false;

  List<MapRoutePoint> get _miniMapRoute => _mapRoute.route;
  List<List<MapRoutePoint>> get _miniMapSegments => _mapRoute.routeSegments;
  MapRoutePoint? get _miniMapCurrent => _mapRoute.current;
  LocationTrackingAvailability? get _miniMapAvailability =>
      _mapRoute.availability;
  bool get _miniMapLoading => _mapRoute.loading;
  String? _editingZoneId;
  bool _hudExpanded = false;
  bool _fillPreview = false;
  bool _fullscreen = false;
  bool _fullscreenChanging = false;
  bool _fullscreenControlsVisible = true;
  bool _fillBeforeFullscreen = false;
  Timer? _fullscreenControlsTimer;
  bool _landscapePanelExpanded = false; _MonitorPrimaryContentMode _primaryContentMode = _MonitorPrimaryContentMode.camera;
  Offset? _portraitPipOffset;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(SystemUiService.edgeToEdge());
    _controller = MonitorController(
      sourceConfig: widget.initialSource,
      settings: widget.settings,
    )..addListener(_refresh);
    final secondarySource = widget.secondarySource;
    if (secondarySource != null) {
      _secondaryController = SecondaryCameraController(
        sourceConfig: secondarySource,
      )..addListener(_refresh);
      unawaited(_secondaryController!.start());
    }
    _bikeSensors.addListener(_refresh);
    _mapRoute.addListener(_onMapRouteChanged);
    _offlineMaps.addListener(_onOfflineMapsChanged);
    _routeExplorer.addListener(_refresh);
    unawaited(_initializeOfflineMiniMap());
    unawaited(_routeExplorer.initialize());
    unawaited(_bikeSensors.initialize());
    unawaited(_controller.initialize());
    unawaited(_initializeMiniMap(requestPermission: false));
  }

  void _updateFullscreenState(VoidCallback update) => setState(update);

  void _updateMulticameraState(VoidCallback update) => setState(update);

  void _refresh() {
    if (!mounted) return;
    setState(() {});
  }

  void _onMapRouteChanged() {
    if (!mounted) return;
    setState(() {});
    final point = _mapRoute.current;
    if (_miniMapReady && _shouldShowMonitorMap && point != null) {
      try {
        _miniMapController.move(
          LatLng(point.latitude, point.longitude),
          15.8,
        );
      } catch (_) {
        _miniMapReady = false;
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        _fullscreen
            ? SystemUiService.immersive()
            : SystemUiService.edgeToEdge(),
      );
      if (_primaryContentMode == _MonitorPrimaryContentMode.camera) unawaited(_controller.resume());
      if (_primaryContentMode == _MonitorPrimaryContentMode.camera) unawaited(_secondaryController?.resume());
      return;
    }
    if (state == AppLifecycleState.inactive && _fullscreenChanging) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_controller.suspend());
      unawaited(_secondaryController?.suspend());
    }
  }

  @override
  void dispose() {
    _fullscreenControlsTimer?.cancel();
    unawaited(AppOrientationService.lockPortrait());
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_refresh);
    _secondaryController?.removeListener(_refresh);
    _secondaryController?.dispose();
    _bikeSensors.removeListener(_refresh);
    _mapRoute.removeListener(_onMapRouteChanged); _mapRoute.releaseLocationConsumer(this);
    _offlineMaps.removeListener(_onOfflineMapsChanged);
    _routeExplorer.removeListener(_refresh);
    _miniOfflineTileProvider?.dispose();
    _miniMapController.dispose();
    _controller.dispose();
    unawaited(SystemUiService.edgeToEdge());
    super.dispose();
  }

  Future<void> _showObjectFilter() async {
    final result = await showObjectFilterDialog(
      context: context,
      selectedLabels: _controller.alertLabels,
    );
    if (result == null || !mounted) return;
    _controller.setAlertLabels(result);
  }

  Future<void> _showSmartAlertRules() async {
    final result = await showSmartAlertRulesDialog(
      context: context,
      initialRules: _controller.smartAlertRules,
    );
    if (result == null || !mounted) return;
    _controller.setSmartAlertRules(result);
  }

  Future<void> _renameZone(MonitoringZoneProfile zone) async {
    final text = TextEditingController(text: zone.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nome da área'),
        content: TextField(
          controller: text,
          autofocus: true,
          maxLength: 24,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, text.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    text.dispose();
    if (name != null && name.isNotEmpty) {
      _controller.renameMonitoringZone(zone.id, name);
    }
  }

  Future<void> _showZones() async {
    final editId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final zones = _controller.monitoringZones;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                height: MediaQuery.sizeOf(sheetContext).height * 0.65,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Áreas de monitoramento',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text('${zones.length}/6'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'A IA analisa o retângulo que engloba as áreas ativas e '
                      'descarta detecções fora delas.',
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.separated(
                        itemCount: zones.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final zone = zones[index];
                          final percent = (zone.zone.area * 100).round();
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Switch(
                              value: zone.enabled,
                              onChanged: (value) {
                                _controller.setMonitoringZoneEnabled(
                                  zone.id,
                                  value,
                                );
                                setSheetState(() {});
                              },
                            ),
                            title: Text(zone.name),
                            subtitle: Text(
                              zone.enabled
                                  ? 'Ativa · aproximadamente $percent% da imagem'
                                  : 'Desativada',
                            ),
                            onTap: () => Navigator.pop(sheetContext, zone.id),
                            trailing: Wrap(
                              spacing: 0,
                              children: [
                                IconButton(
                                  tooltip: 'Renomear',
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () {
                                    Navigator.pop(sheetContext);
                                    unawaited(_renameZone(zone));
                                  },
                                ),
                                if (zones.length > 1)
                                  IconButton(
                                    tooltip: 'Excluir área',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () {
                                      _controller.removeMonitoringZone(zone.id);
                                      setSheetState(() {});
                                    },
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      onPressed: zones.length >= 6
                          ? null
                          : () {
                              final id = _controller.addMonitoringZone();
                              Navigator.pop(sheetContext, id);
                            },
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar e desenhar nova área'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (!mounted || editId == null) return;
    setState(() => _editingZoneId = editId);
  }

  void _applyZone(String id, MonitoringZone zone) {
    _controller.updateMonitoringZone(id, zone);
    setState(() => _editingZoneId = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Área de monitoramento atualizada.')),
    );
  }

  Future<void> _showFeatureToggles() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            children: [
              const ListTile(
                title: Text(
                  'Recursos do monitor',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              SwitchListTile(
                value: _controller.clipRecordingEnabled,
                onChanged: (value) {
                  _controller.setClipRecordingEnabled(value);
                  setSheetState(() {});
                },
                secondary: const Icon(Icons.movie_outlined),
                title: const Text('Clipes automáticos'),
                subtitle: const Text(
                  'Salva um clipe local quando houver alerta confirmado.',
                ),
              ),
              SwitchListTile(
                value: _controller.trackingEnabled,
                onChanged: (value) {
                  _controller.setTrackingEnabled(value);
                  setSheetState(() {});
                },
                secondary: const Icon(Icons.track_changes),
                title: const Text('Rastreamento individual'),
                subtitle: const Text(
                  'Mantém um ID temporário para acompanhar o mesmo objeto entre quadros e reduzir repetições.',
                ),
              ),
              SwitchListTile(
                value: _controller.announceEntryExit,
                onChanged: _controller.trackingEnabled
                    ? (value) {
                        _controller.setAnnounceEntryExit(value);
                        setSheetState(() {});
                      }
                    : null,
                secondary: const Icon(Icons.compare_arrows),
                title: const Text('Entrada e saída'),
                subtitle: const Text(
                  'Registra quando um objeto entra ou sai de uma área monitorada. Não é uma contagem acumulada.',
                ),
              ),
              SwitchListTile(
                value: _controller.backgroundMonitoringEnabled,
                onChanged: (value) async {
                  final applied = await _controller
                      .setBackgroundMonitoringEnabled(value);
                  if (!mounted || !context.mounted) return;
                  setSheetState(() {});
                  if (value && !applied) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'O Android não permitiu iniciar o serviço em segundo plano.',
                        ),
                      ),
                    );
                  }
                },
                secondary: const Icon(Icons.phone_android),
                title: const Text('Segundo plano'),
                subtitle: const Text(
                  'Tenta manter câmera e IA ativas com notificação persistente quando você sai da tela.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _scanRemotePhoneQr(
    TextEditingController remoteUrlController,
    TextEditingController remoteKeyController,
    StateSetter setDialogState,
  ) async {
    final native = NativePlatformService.instance;
    final cameraGranted = await native.requestCameraPermission();
    if (!mounted) return;
    if (!cameraGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Permita a câmera para escanear o QR do outro celular.',
          ),
          action: SnackBarAction(
            label: 'AJUSTES',
            onPressed: () => unawaited(native.openAppSettings()),
          ),
        ),
      );
      return;
    }

    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => const PhonePairingScannerScreen(),
      ),
    );
    if (!mounted || raw == null || raw.trim().isEmpty) return;

    try {
      final pairing = RemoteCameraPairingService.decode(raw);
      setDialogState(() {
        remoteUrlController.text = pairing.address;
        remoteKeyController.text = pairing.accessKey;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Celular remoto preenchido: ${pairing.name}.')),
      );
    } on FormatException catch (error) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message.toString())));
    }
  }

  Future<void> _showSourceSwitcher() async {
    await _cameraRegistry.initialize();
    if (!mounted) return;
    final current = _controller.sourceConfig;
    var type = current.type;
    final esp32Cameras = _cameraRegistry.items
        .where(
          (camera) =>
              camera.enabled &&
              camera.type == CameraEndpointType.esp32 &&
              camera.esp32CameraEnabled,
        )
        .toList(growable: false);
    var selectedEsp32Id =
        esp32Cameras.any((camera) => camera.id == current.cameraId)
        ? current.cameraId
        : (esp32Cameras.isEmpty ? null : esp32Cameras.first.id);
    final rtspController = TextEditingController(text: current.rtspUrl ?? '');
    final remoteUrlController = TextEditingController(
      text: current.remoteBaseUrl ?? '',
    );
    final remoteKeyController = TextEditingController(
      text: current.remoteAccessKey ?? '',
    );
    final next = await showDialog<VideoSourceConfig>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Selecionar fonte'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Escolha de onde o vídeo será recebido. Os textos abaixo explicam cada opção.',
                  ),
                  const SizedBox(height: 14),
                  _SourceOptionTile(
                    icon: Icons.smartphone_rounded,
                    title: 'Este aparelho',
                    subtitle: 'Usa a câmera do próprio celular.',
                    selected: type == VideoSourceType.localCamera,
                    onTap: () => setDialogState(
                      () => type = VideoSourceType.localCamera,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SourceOptionTile(
                    icon: Icons.memory_rounded,
                    title: 'Câmera ESP32',
                    subtitle: 'Recebe imagem do módulo pela rede local.',
                    selected: type == VideoSourceType.esp32,
                    onTap: () =>
                        setDialogState(() => type = VideoSourceType.esp32),
                  ),
                  const SizedBox(height: 8),
                  _SourceOptionTile(
                    icon: Icons.router_outlined,
                    title: 'Câmera RTSP',
                    subtitle: 'Conecta a uma câmera ou DVR pela URL RTSP.',
                    selected: type == VideoSourceType.rtsp,
                    onTap: () =>
                        setDialogState(() => type = VideoSourceType.rtsp),
                  ),
                  const SizedBox(height: 8),
                  _SourceOptionTile(
                    icon: Icons.phone_android_rounded,
                    title: 'Outro celular',
                    subtitle: 'Recebe vídeo de outro aparelho da mesma rede.',
                    selected: type == VideoSourceType.remotePhone,
                    onTap: () => setDialogState(
                      () => type = VideoSourceType.remotePhone,
                    ),
                  ),
                  if (type == VideoSourceType.rtsp) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: rtspController,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Endereço RTSP',
                        hintText:
                            'rtsp://usuario:senha@192.168.1.20:554/stream',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  if (type == VideoSourceType.remotePhone) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Você pode ler o QR do outro aparelho ou preencher os campos manualmente.',
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () => unawaited(
                            _scanRemotePhoneQr(
                              remoteUrlController,
                              remoteKeyController,
                              setDialogState,
                            ),
                          ),
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                          label: const Text('Escanear QR'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => setDialogState(() {
                            remoteUrlController.clear();
                            remoteKeyController.clear();
                          }),
                          icon: const Icon(Icons.clear_rounded),
                          label: const Text('Limpar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: remoteUrlController,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Endereço do outro celular',
                        hintText: 'http://192.168.0.20:8765',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: remoteKeyController,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Chave de sessão',
                        helperText: 'A chave aparece no Modo Câmera do aparelho remoto.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  if (type == VideoSourceType.esp32) ...[
                    const SizedBox(height: 16),
                    if (esp32Cameras.isEmpty)
                      const Text(
                        'Nenhum ESP32 com câmera está ativo. Cadastre o módulo em Configurações > ESP32 e sensores.',
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue: selectedEsp32Id,
                        decoration: const InputDecoration(
                          labelText: 'Módulo ESP32',
                          prefixIcon: Icon(Icons.memory_rounded),
                          border: OutlineInputBorder(),
                        ),
                        items: esp32Cameras
                            .map(
                              (camera) => DropdownMenuItem<String>(
                                value: camera.id,
                                child: Text(camera.name),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) =>
                            setDialogState(() => selectedEsp32Id = value),
                      ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final rtsp = rtspController.text.trim();
                final remoteUrl = remoteUrlController.text.trim();
                final remoteKey = remoteKeyController.text.trim();
                if (type == VideoSourceType.rtsp) {
                  final uri = Uri.tryParse(rtsp);
                  if (uri == null || uri.scheme != 'rtsp' || uri.host.isEmpty) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('Informe uma URL RTSP válida.'),
                      ),
                    );
                    return;
                  }
                }
                if (type == VideoSourceType.remotePhone) {
                  final uri = Uri.tryParse(remoteUrl);
                  if (uri == null ||
                      !(uri.scheme == 'http' || uri.scheme == 'https') ||
                      uri.host.isEmpty ||
                      remoteKey.isEmpty) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Preencha o endereço local e a chave do outro celular.',
                        ),
                      ),
                    );
                    return;
                  }
                }
                CameraEndpoint? selectedEsp32;
                if (type == VideoSourceType.esp32 && selectedEsp32Id != null) {
                  for (final camera in esp32Cameras) {
                    if (camera.id == selectedEsp32Id) {
                      selectedEsp32 = camera;
                      break;
                    }
                  }
                }
                if (type == VideoSourceType.esp32 && selectedEsp32 == null) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Cadastre e ative uma câmera ESP32 primeiro.',
                      ),
                    ),
                  );
                  return;
                }
                Navigator.pop(
                  context,
                  VideoSourceConfig(
                    type: type,
                    rtspUrl: type == VideoSourceType.rtsp ? rtsp : null,
                    remoteBaseUrl: type == VideoSourceType.remotePhone
                        ? remoteUrl
                        : selectedEsp32?.address,
                    remoteAccessKey: type == VideoSourceType.remotePhone
                        ? remoteKey
                        : selectedEsp32?.accessKey,
                    displayName: selectedEsp32?.name,
                    cameraId: selectedEsp32?.id,
                    analysisInterval: current.analysisInterval,
                  ),
                );
              },
              child: const Text('Trocar'),
            ),
          ],
        ),
      ),
    );
    rtspController.dispose();
    remoteUrlController.dispose();
    remoteKeyController.dispose();
    if (next != null && mounted) {
      final secondary = _secondaryController?.sourceConfig;
      if (secondary != null && _sameSource(next, secondary)) {
        await _replaceSecondarySource(null);
      }
      await _controller.switchSource(next);
    }
  }

  Future<void> _showLanAccess() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => ListenableBuilder(
        listenable: _controller,
        builder: (sheetContext, _) {
          final running = _controller.lanStreamRunning;
          final viewerUrl = _controller.lanViewerUrl;
          final baseAddress = _controller.lanBaseAddress;
          final error = _controller.lanStreamError;
          final viewers = _controller.lanConnectedViewers;
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        running
                            ? Icons.wifi_tethering_rounded
                            : Icons.wifi_tethering_off_rounded,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          running
                              ? 'Transmissão pela rede local ativa'
                              : 'Transmissão pela rede local indisponível',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Outro celular conectado à mesma rede pode abrir o endereço abaixo no navegador. '
                    'A transmissão usa os mesmos quadros do monitor e não abre uma segunda câmera.',
                  ),
                  if (running && viewerUrl != null && baseAddress != null) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'Abrir manualmente',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    _LanValueRow(
                      label: 'Endereço',
                      value: baseAddress,
                      onCopy: () =>
                          Clipboard.setData(ClipboardData(text: baseAddress)),
                    ),
                    const SizedBox(height: 8),
                    _LanValueRow(
                      label: 'Chave',
                      value: _controller.lanAccessKey,
                      onCopy: () => Clipboard.setData(
                        ClipboardData(text: _controller.lanAccessKey),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: viewerUrl));
                        if (!sheetContext.mounted) return;
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          const SnackBar(
                            content: Text('Link automático copiado.'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.link_rounded),
                      label: const Text('Copiar link automático'),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      viewers == 0
                          ? 'Nenhum outro aparelho assistindo agora.'
                          : viewers == 1
                          ? '1 aparelho assistindo agora.'
                          : '$viewers aparelhos assistindo agora.',
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'O link automático usa a chave apenas para criar a sessão do navegador e depois remove o segredo da barra. A chave muda quando a transmissão é reiniciada.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(sheetContext).colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (!running) ...[
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _controller.lanStreamStarting
                          ? null
                          : () => _controller.ensureLanStreaming(
                              requestPermission: true,
                            ),
                      icon: _controller.lanStreamStarting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded),
                      label: const Text('Tentar ativar'),
                    ),
                  ],
                  const SizedBox(height: 10),
                  const Text(
                    'Acesso restrito à rede local: não há publicação automática na internet. '
                    'A disponibilidade depende de Wi-Fi/hotspot, permissões do Android e do monitor permanecer ativo.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showRightSidePanel({
    required WidgetBuilder builder,
    double maxWidth = 560,
  }) async {
    final size = MediaQuery.sizeOf(context);
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fechar painel',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, secondaryAnimation) => Align(
        alignment: Alignment.centerRight,
        child: SafeArea(
          child: Material(
            color: Theme.of(dialogContext).colorScheme.surface,
            elevation: 12,
            clipBehavior: Clip.antiAlias,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(24),
            ),
            child: SizedBox(
              width: size.width < maxWidth ? size.width : maxWidth,
              height: double.infinity,
              child: builder(dialogContext),
            ),
          ),
        ),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final offset =
            Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
        return SlideTransition(position: offset, child: child);
      },
    );
  }

  Future<void> _showSessionStatus() async {
    final size = MediaQuery.sizeOf(context);
    final largeSurface = size.width >= 840;
    if (largeSurface) {
      await _showRightSidePanel(
        maxWidth: size.width >= 1200 ? 600 : 520,
        builder: (dialogContext) => ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => SessionStatusPanel(
            data: _controller.sessionStatus,
            showCloseButton: true,
          ),
        ),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.86,
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) =>
              SessionStatusPanel(data: _controller.sessionStatus),
        ),
      ),
    );
  }

  Future<void> _showRemoteBikeStatus() async {
    if (!_controller.isRemotePhoneSource) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.82,
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => RemoteBikeStatusPanel(
            status: _controller.remotePhoneStatus,
            sourceOnline:
                _controller.sourceStatus.state == VideoSourceState.streaming,
          ),
        ),
      ),
    );
  }


  Future<void> _openStandardScreen(Widget screen) async {
    if (_fullscreen) await _toggleFullscreen();
    await SystemUiService.edgeToEdge();
    if (!mounted) return;
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) await SystemUiService.edgeToEdge();
  }

  Future<void> _closeMonitor() async {
    if (_fullscreen) await _toggleFullscreen();
    if (mounted) await Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final permanentLandscapePanel =
        size.shortestSide >= 600 && size.width >= 980;

    return PopScope<void>(
      canPop: !_fullscreen && !_fullscreenChanging,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _fullscreen) unawaited(_toggleFullscreen());
      },
      child: Scaffold(
        extendBodyBehindAppBar: landscape || _fullscreen,
        appBar: _fullscreen || landscape
            ? null
            : AppBar(
                title: Row(
                  children: [
                    _StatusDot(
                      active:
                          _controller.sourceStatus.state ==
                          VideoSourceState.streaming,
                    ),
                    const SizedBox(width: 9),
                    const Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ao vivo',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'Monitoramento em tempo real',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    tooltip: 'Tela inteira',
                    onPressed: _fullscreenChanging
                        ? null
                        : () => unawaited(_toggleFullscreen()),
                    icon: const Icon(Icons.fullscreen_rounded),
                  ),
                  _monitorMenu(),
                ],
              ),
        body: _fullscreen
            ? _buildFullscreen(context)
            : landscape
            ? _buildLandscape(context, permanentPanel: permanentLandscapePanel)
            : SafeArea(child: _buildPortrait(context)),
      ),
    );
  }

  int get _currentDetectionCount => _controller.trackingEnabled
      ? _controller.trackedDetections.length
      : _controller.detections.length;

  BikeSensorSnapshot? get _effectiveBikeSnapshot {
    final local = _bikeSensors.snapshot;
    final primaryRemote = _controller.remotePhoneStatus?.bikeSensors;
    final secondaryRemote = _secondaryController?.remoteStatus?.bikeSensors;
    if (local?.connected == true) return local;
    if (primaryRemote?.connected == true) return primaryRemote;
    if (secondaryRemote?.connected == true) return secondaryRemote;
    return local ?? primaryRemote ?? secondaryRemote;
  }

  Widget _buildLandscape(BuildContext context, {required bool permanentPanel}) {
    if (_secondaryController == null) {
      return _buildLandscapeDashboard(context);
    }

    final width = MediaQuery.sizeOf(context).width;
    final panelWidth = (width * 0.31).clamp(300.0, 420.0).toDouble();
    final panel = DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.98),
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.outline
                .withValues(alpha: 0.14),
          ),
        ),
      ),
      child: Column(
        children: [
          if (!permanentPanel)
            SizedBox(
              height: 42,
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Controles e detecções',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Ocultar painel',
                    onPressed: () =>
                        setState(() => _landscapePanelExpanded = false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
          _buildControlDock(context, compact: true),
          Expanded(child: _buildDetectionPanel(context, compact: true)),
        ],
      ),
    );

    if (permanentPanel) {
      return Row(
        children: [
          Expanded(child: _buildAdaptiveCameraStage(context)),
          SizedBox(width: panelWidth, child: panel),
        ],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        _buildAdaptiveCameraStage(context),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          top: 0,
          bottom: 0,
          right: _landscapePanelExpanded ? 0 : -panelWidth,
          width: panelWidth,
          child: Material(elevation: 12, child: panel),
        ),
        if (!_landscapePanelExpanded)
          Positioned(
            right: 10,
            bottom: 10,
            child: FilledButton.tonalIcon(
              onPressed: () => setState(() => _landscapePanelExpanded = true),
              icon: const Icon(Icons.radar_rounded),
              label: Text('Detectados $_currentDetectionCount'),
            ),
          ),
      ],
    );
  }


  Widget _buildPreviewLayer(BuildContext context) {
    final preview = _controller.buildPreview();
    final forceFill =
        _fullscreen ||
        MediaQuery.orientationOf(context) == Orientation.landscape;
    if (!_fillPreview && !forceFill) return preview;
    final ratio = _controller.previewAspectRatio;
    if (ratio == null || ratio <= 0) return preview;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
          return preview;
        }
        final containerRatio = constraints.maxWidth / constraints.maxHeight;
        final scale = containerRatio > ratio
            ? containerRatio / ratio
            : ratio / containerRatio;
        return ClipRect(
          child: Transform.scale(scale: scale, child: preview),
        );
      },
    );
  }

  Widget _buildControlDock(
    BuildContext context, {
    bool compact = false,
    bool overlay = false,
  }) {
    final buttons = <Widget>[
      _MonitorActionButton(
        icon: Icons.grid_view_rounded,
        label: 'Áreas',
        dense: compact,
        onTap: () => unawaited(_showZones()),
      ),
      _MonitorActionButton(
        icon: Icons.filter_alt_outlined,
        label: 'Objetos',
        dense: compact,
        onTap: () => unawaited(_showObjectFilter()),
      ),
      _MonitorActionButton(
        icon: Icons.rule_outlined,
        label: 'Regras',
        dense: compact,
        onTap: () => unawaited(_showSmartAlertRules()),
      ),
      _MonitorActionButton(
        icon: Icons.cameraswitch_outlined,
        label: 'Fonte',
        dense: compact,
        onTap: () => unawaited(_showSourceSwitcher()),
      ),
      _MonitorActionButton(
        icon: Icons.video_collection_outlined,
        label: '2ª câmera',
        dense: compact,
        onTap: () => unawaited(_showSecondaryCameraSelector()),
      ),
      _MonitorActionButton(
        icon: Icons.auto_awesome_motion_outlined,
        label: 'Recursos',
        dense: compact,
        onTap: () => unawaited(_showFeatureToggles()),
      ),
    ];

    if (compact) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final available = constraints.maxWidth;
          if (available >= 330) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Row(
                children: [
                  for (var index = 0; index < buttons.length; index++) ...[
                    if (index > 0) const SizedBox(width: 4),
                    Expanded(child: buttons[index]),
                  ],
                ],
              ),
            );
          }
          final columns = available >= 220 ? 3 : 2;
          final spacing = 5.0;
          final cellWidth =
              (available - 12 - spacing * (columns - 1)) / columns;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Wrap(
              spacing: spacing,
              runSpacing: 5,
              alignment: WrapAlignment.center,
              children: [
                for (final button in buttons)
                  SizedBox(width: cellWidth, child: button),
              ],
            ),
          );
        },
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: overlay
            ? Colors.black.withValues(alpha: 0.68)
            : Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: overlay
                ? Colors.white.withValues(alpha: 0.08)
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.16),
          ),
          bottom: BorderSide(
            color: overlay
                ? Colors.white.withValues(alpha: 0.06)
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: buttons),
      ),
    );
  }

  Widget _buildDetectionPanel(
    BuildContext context, {
    bool compact = false,
    bool showHeader = true,
    ScrollController? scrollController,
  }) {
    final tracked = _controller.trackingEnabled;
    final count = tracked
        ? _controller.trackedDetections.length
        : _controller.detections.length;
    return ListView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 14,
        12,
        compact ? 12 : 14,
        22,
      ),
      children: [
        if (showHeader) ...[
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detectados agora',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Quantidade visível neste instante; não é uma contagem acumulada.',
                    ),
                  ],
                ),
              ),
              _CountBadge(count: count),
            ],
          ),
          const SizedBox(height: 10),
        ],
        _RuntimeSummary(controller: _controller),
        if (!_controller.voiceLanguageInstalled &&
            !_controller.initializing) ...[
          const SizedBox(height: 8),
          const _InfoStrip(
            icon: Icons.volume_off_outlined,
            text: 'A voz do Android em pt-BR não está instalada. Os áudios integrados continuam disponíveis.',
          ),
        ],
        const SizedBox(height: 10),
        if (count == 0 && !_controller.initializing)
          _EmptyDetectionState(
            text: !_controller.scheduleActive
                ? 'Pausado pela agenda. O monitor retomará no próximo horário.'
                : _controller.motionOnly
                ? 'Aguardando atividade relevante.'
                : 'Nenhum objeto acima do limite de confiança.',
          )
        else if (tracked)
          ..._controller.trackedDetections.map(
            (trackedDetection) => _DetectionCard(
              label: trackedDetection.detection.displayLabel,
              confidence: trackedDetection.detection.confidence,
              trackId: trackedDetection.trackId,
            ),
          )
        else
          ..._controller.detections.map(
            (detection) => _DetectionCard(
              label: detection.displayLabel,
              confidence: detection.confidence,
            ),
          ),
      ],
    );
  }

  String _statusText(VideoSourceStatus status) =>
      status.message ??
      switch (status.state) {
        VideoSourceState.idle => 'Aguardando',
        VideoSourceState.connecting => 'Conectando',
        VideoSourceState.streaming => 'Ao vivo',
        VideoSourceState.reconnecting => 'Reconectando',
        VideoSourceState.stopped => 'Pausado',
        VideoSourceState.error => 'Erro na câmera',
      };
}
