import 'dart:async';

import 'package:flutter/material.dart';

import '../models/camera_endpoint.dart';
import '../models/monitor_event.dart';
import '../models/object_filter_catalog.dart';
import '../models/video_source_config.dart';
import '../services/app_settings_service.dart';
import '../services/camera_registry_service.dart';
import '../services/event_history_service.dart';
import '../services/native_platform_service.dart';
import '../services/remote_camera_pairing_service.dart';
import '../widgets/main_navigation_bar.dart';
import 'bike_mode_screen.dart';
import 'events_screen.dart';
import 'home_screen.dart';
import 'monitor_screen.dart';
import 'settings_screen.dart';
import 'phone_pairing_scanner_screen.dart';

class MultiCameraScreen extends StatefulWidget {
  const MultiCameraScreen({super.key});

  @override
  State<MultiCameraScreen> createState() => _MultiCameraScreenState();
}

class _MultiCameraScreenState extends State<MultiCameraScreen> {
  static const Duration _automaticRefreshInterval = Duration(seconds: 15);

  final _registry = CameraRegistryService.instance;
  final _settings = AppSettingsService.instance;
  final _history = EventHistoryService.instance;
  final _native = NativePlatformService.instance;
  final Map<String, CameraProbeResult> _status = <String, CameraProbeResult>{};

  Timer? _statusTimer;
  bool _loading = true;
  bool _refreshing = false;
  DateTime? _lastRefresh;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    await Future.wait(<Future<void>>[
      _registry.initialize(),
      _history.initialize(),
    ]);
    if (!mounted) return;
    setState(() => _loading = false);
    await _refreshStatuses();
    _statusTimer = Timer.periodic(
      _automaticRefreshInterval,
      (_) => unawaited(_refreshStatuses()),
    );
  }

  List<CameraEndpoint> get _cameras => <CameraEndpoint>[
        const CameraEndpoint(
          id: '__local__',
          name: 'Câmera deste aparelho',
          type: CameraEndpointType.local,
        ),
        ..._registry.items,
      ];

  Future<void> _refreshStatuses() async {
    if (_refreshing) return;
    _refreshing = true;
    if (mounted) setState(() {});
    try {
      final results = await _registry.probeAll(_cameras);
      if (!mounted) return;
      setState(() {
        _status
          ..clear()
          ..addAll(results);
        _lastRefresh = DateTime.now();
      });
    } finally {
      _refreshing = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _addCamera(CameraEndpointType type) async {
    final endpoint = await _showCameraEditor(type: type);
    if (endpoint == null) return;
    await _registry.save(endpoint);
    if (mounted) setState(() {});
    await _refreshStatuses();
  }

  CameraEndpoint? _findRemotePhoneByAddress(String address) {
    for (final item in _registry.items) {
      if (item.type == CameraEndpointType.remotePhone && item.address == address) {
        return item;
      }
    }
    return null;
  }

  Future<void> _scanPhoneQr() async {
    final raw = await Navigator.push<String>(
      context,
      MaterialPageRoute<String>(
        builder: (_) => const PhonePairingScannerScreen(),
      ),
    );
    if (raw == null || !mounted) return;

    late final RemoteCameraPairingData pairing;
    try {
      pairing = RemoteCameraPairingService.decode(raw);
    } on FormatException catch (error) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('QR não reconhecido'),
          content: Text(error.message.toString()),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final existing = _findRemotePhoneByAddress(pairing.address);

    final candidate = CameraEndpoint(
      id: existing?.id ?? 'cam_${DateTime.now().microsecondsSinceEpoch}',
      name: existing?.name ?? pairing.name,
      type: CameraEndpointType.remotePhone,
      address: pairing.address,
      accessKey: pairing.accessKey,
      enabled: true,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('QR válido. Testando conexão com o celular…')),
    );
    final probe = await _registry.probe(candidate);
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (!probe.online) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Celular não respondeu'),
          content: Text(
            '${probe.message ?? 'Não foi possível conectar.'}\n\n'
            'Confira se o Modo Câmera continua ligado e se os dois aparelhos estão na mesma rede Wi‑Fi ou hotspot.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendi'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await _confirmScannedPhone(
      candidate,
      probe,
      updatingExisting: existing != null,
    );
    if (confirmed == null) return;
    await _registry.save(confirmed);
    if (!mounted) return;
    setState(() => _status[confirmed.id] = probe);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          existing == null
              ? '${confirmed.name} conectado e salvo.'
              : '${confirmed.name} atualizado com a nova chave de sessão.',
        ),
      ),
    );
    unawaited(_refreshStatuses());
  }

  Future<CameraEndpoint?> _confirmScannedPhone(
    CameraEndpoint endpoint,
    CameraProbeResult probe, {
    required bool updatingExisting,
  }) async {
    final name = TextEditingController(text: endpoint.name);
    final result = await showDialog<CameraEndpoint>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(updatingExisting ? 'Atualizar celular' : 'Celular encontrado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF4ADE80)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    probe.latency == null
                        ? 'Conexão validada.'
                        : 'Conexão validada em ${probe.latency!.inMilliseconds} ms.',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: name,
              autofocus: false,
              decoration: const InputDecoration(labelText: 'Nome da câmera'),
            ),
            const SizedBox(height: 10),
            Text(
              endpoint.address ?? '',
              style: Theme.of(dialogContext).textTheme.bodySmall,
            ),
            if (updatingExisting) ...[
              const SizedBox(height: 8),
              const Text(
                'Este endereço já estava cadastrado. A nova chave será atualizada sem duplicar a câmera.',
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(
              dialogContext,
              endpoint.copyWith(
                name: name.text.trim().isEmpty ? 'Celular remoto' : name.text.trim(),
              ),
            ),
            icon: const Icon(Icons.link_rounded),
            label: Text(updatingExisting ? 'Atualizar' : 'Conectar'),
          ),
        ],
      ),
    );
    name.dispose();
    return result;
  }

  Future<void> _editCamera(CameraEndpoint camera) async {
    final endpoint = await _showCameraEditor(
      type: camera.type,
      existing: camera,
    );
    if (endpoint == null) return;
    await _registry.save(endpoint);
    if (mounted) setState(() {});
    await _refreshStatuses();
  }

  Future<CameraEndpoint?> _showCameraEditor({
    required CameraEndpointType type,
    CameraEndpoint? existing,
  }) async {
    final isRtsp = type == CameraEndpointType.rtsp;
    final name = TextEditingController(
      text: existing?.name ?? (isRtsp ? 'Câmera RTSP' : 'Celular remoto'),
    );
    final address = TextEditingController(text: existing?.address ?? '');
    final key = TextEditingController(text: existing?.accessKey ?? '');
    String? error;

    final result = await showDialog<CameraEndpoint>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            existing == null
                ? (isRtsp ? 'Adicionar RTSP' : 'Adicionar celular')
                : 'Editar ${existing.name}',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nome da câmera'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: address,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: isRtsp ? 'URL RTSP' : 'Endereço local',
                    hintText: isRtsp
                        ? 'rtsp://192.168.1.20/stream'
                        : 'http://192.168.1.10:8765',
                  ),
                ),
                if (type == CameraEndpointType.remotePhone) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: key,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(labelText: 'Chave de sessão'),
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final value = address.text.trim();
                final uri = Uri.tryParse(value);
                final validRtsp = isRtsp &&
                    uri != null &&
                    uri.scheme.toLowerCase() == 'rtsp' &&
                    uri.host.isNotEmpty;
                final validRemote = !isRtsp &&
                    uri != null &&
                    (uri.scheme == 'http' || uri.scheme == 'https') &&
                    uri.host.isNotEmpty &&
                    key.text.trim().isNotEmpty;
                if (!(validRtsp || validRemote)) {
                  setDialogState(() {
                    error = isRtsp
                        ? 'Informe uma URL RTSP válida.'
                        : 'Informe o endereço HTTP local e a chave de sessão.';
                  });
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  CameraEndpoint(
                    id: existing?.id ??
                        'cam_${DateTime.now().microsecondsSinceEpoch}',
                    name: name.text.trim().isEmpty
                        ? (isRtsp ? 'Câmera RTSP' : 'Celular remoto')
                        : name.text.trim(),
                    type: type,
                    address: value,
                    accessKey: type == CameraEndpointType.remotePhone
                        ? key.text.trim()
                        : null,
                    enabled: existing?.enabled ?? true,
                  ),
                );
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    name.dispose();
    address.dispose();
    key.dispose();
    return result;
  }

  Future<void> _toggleCamera(CameraEndpoint camera) async {
    await _registry.save(camera.copyWith(enabled: !camera.enabled));
    if (mounted) setState(() {});
    await _refreshStatuses();
  }

  Future<void> _deleteCamera(CameraEndpoint camera) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remover ${camera.name}?'),
        content: const Text(
          'O histórico já registrado será preservado. Apenas o cadastro desta câmera será removido.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _registry.delete(camera.id);
    if (!mounted) return;
    setState(() => _status.remove(camera.id));
  }

  Future<void> _open(CameraEndpoint camera) async {
    if (!camera.enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ative esta câmera antes de monitorar.')),
      );
      return;
    }
    final profile = await _settings.initialize();
    if (camera.type == CameraEndpointType.local) {
      final granted = await _native.requestCameraPermission();
      if (!mounted) return;
      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'A permissão da câmera é necessária para monitorar este dispositivo.',
            ),
            action: SnackBarAction(
              label: 'AJUSTES',
              onPressed: () => unawaited(_native.openAppSettings()),
            ),
          ),
        );
        return;
      }
    }
    if (profile.settings.backgroundMonitoringEnabled) {
      await _native.requestNotificationPermission();
      if (!mounted) return;
    }
    final source = switch (camera.type) {
      CameraEndpointType.local => VideoSourceConfig(
          type: VideoSourceType.localCamera,
          displayName: camera.name,
          cameraId: camera.id,
          analysisInterval: profile.source.analysisInterval,
        ),
      CameraEndpointType.rtsp => VideoSourceConfig(
          type: VideoSourceType.rtsp,
          rtspUrl: camera.address,
          displayName: camera.name,
          cameraId: camera.id,
          analysisInterval: profile.source.analysisInterval,
        ),
      CameraEndpointType.remotePhone => VideoSourceConfig(
          type: VideoSourceType.remotePhone,
          remoteBaseUrl: camera.address,
          remoteAccessKey: camera.accessKey,
          displayName: camera.name,
          cameraId: camera.id,
          analysisInterval: profile.source.analysisInterval,
        ),
    };
    if (!mounted) return;
    _statusTimer?.cancel();
    _statusTimer = null;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => MonitorScreen(
          initialSource: source,
          settings: profile.settings,
        ),
      ),
    );
    await _history.initialize();
    if (!mounted) return;
    _statusTimer = Timer.periodic(
      _automaticRefreshInterval,
      (_) => unawaited(_refreshStatuses()),
    );
    setState(() {});
    unawaited(_refreshStatuses());
  }

  MonitorEvent? _lastEvent(CameraEndpoint camera) {
    for (final event in _history.events) {
      if (ObjectFilterCatalog.groupKeyForLabel(event.label) == null) continue;
      if (event.cameraId == camera.id) return event;
      if (event.cameraId == null &&
          (event.source == camera.name ||
              (camera.type == CameraEndpointType.local &&
                  event.source == 'Câmera do dispositivo'))) {
        return event;
      }
    }
    return null;
  }

  void _navigateMain(int index) {
    if (index == 3) return;
    final Widget target = switch (index) {
      0 => const HomeScreen(),
      1 => const EventsScreen(),
      2 => const HomeScreen(startMonitorOnLoad: true),
      4 => const BikeModeScreen(),
      _ => const MultiCameraScreen(),
    };
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => target),
      (route) => false,
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveMainScaffold(
      currentIndex: 3,
      onDestinationSelected: _navigateMain,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Central multicâmera'),
            Text(
              'Câmeras independentes · sem contagem automática',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _openSettings,
            tooltip: 'Configurações',
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            onPressed: _refreshing ? null : _refreshStatuses,
            tooltip: 'Atualizar agora',
            icon: _refreshing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1000
                    ? 3
                    : constraints.maxWidth >= 620
                        ? 2
                        : 1;
                final cameras = _cameras;
                final online = cameras.where((camera) {
                  return camera.enabled && (_status[camera.id]?.online ?? false);
                }).length;
                final disabled = cameras.where((camera) => !camera.enabled).length;
                return CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                      sliver: SliverToBoxAdapter(
                        child: _CentralHeader(
                          total: cameras.length,
                          online: online,
                          disabled: disabled,
                          lastRefresh: _lastRefresh,
                          onScanPhone: _scanPhoneQr,
                          onAddPhone: () => _addCamera(CameraEndpointType.remotePhone),
                          onAddRtsp: () => _addCamera(CameraEndpointType.rtsp),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          mainAxisExtent: 224,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final camera = cameras[index];
                            return _CameraCard(
                              camera: camera,
                              status: _status[camera.id],
                              lastEvent: _lastEvent(camera),
                              onOpen: () => _open(camera),
                              onEdit: camera.id == '__local__'
                                  ? null
                                  : () => _editCamera(camera),
                              onToggle: camera.id == '__local__'
                                  ? null
                                  : () => _toggleCamera(camera),
                              onDelete: camera.id == '__local__'
                                  ? null
                                  : () => _deleteCamera(camera),
                            );
                          },
                          childCount: cameras.length,
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

class _CentralHeader extends StatelessWidget {
  const _CentralHeader({
    required this.total,
    required this.online,
    required this.disabled,
    required this.lastRefresh,
    required this.onScanPhone,
    required this.onAddPhone,
    required this.onAddRtsp,
  });

  final int total;
  final int online;
  final int disabled;
  final DateTime? lastRefresh;
  final VoidCallback onScanPhone;
  final VoidCallback onAddPhone;
  final VoidCallback onAddRtsp;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricChip(icon: Icons.videocam_outlined, label: '$total câmeras'),
                _MetricChip(icon: Icons.wifi_rounded, label: '$online online'),
                if (disabled > 0)
                  _MetricChip(
                    icon: Icons.pause_circle_outline_rounded,
                    label: '$disabled desativadas',
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              lastRefresh == null
                  ? 'Verificando disponibilidade…'
                  : 'Status automático a cada 15 s · atualizado ${_formatTime(lastRefresh!)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 19),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cada câmera é independente. Adicionar outra câmera não ativa contador. Uma futura contagem poderá ser habilitada por câmera, separadamente.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onScanPhone,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('ESCANEAR QR DO CELULAR'),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onAddPhone,
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Adicionar manual'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onAddRtsp,
                    icon: const Icon(Icons.router_outlined),
                    label: const Text('Adicionar RTSP'),
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

class _CameraCard extends StatelessWidget {
  const _CameraCard({
    required this.camera,
    required this.status,
    required this.lastEvent,
    required this.onOpen,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final CameraEndpoint camera;
  final CameraProbeResult? status;
  final MonitorEvent? lastEvent;
  final VoidCallback onOpen;
  final VoidCallback? onEdit;
  final VoidCallback? onToggle;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final online = camera.enabled && (status?.online ?? false);
    final statusColor = !camera.enabled
        ? scheme.outline
        : online
            ? const Color(0xFF4ADE80)
            : status == null
                ? scheme.primary
                : scheme.error;
    final statusText = !camera.enabled
        ? 'Desativada'
        : status == null
            ? 'Verificando…'
            : online
                ? 'Online'
                : 'Offline';
    final latency = status?.latency;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Icon(
                    switch (camera.type) {
                      CameraEndpointType.local => Icons.camera_alt_outlined,
                      CameraEndpointType.rtsp => Icons.router_outlined,
                      CameraEndpointType.remotePhone => Icons.phone_android_rounded,
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        camera.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            statusText,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (online && latency != null) ...[
                            const Text(' · '),
                            Text(
                              '${latency.inMilliseconds} ms',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (onEdit != null || onToggle != null || onDelete != null)
                  PopupMenuButton<String>(
                    tooltip: 'Opções da câmera',
                    onSelected: (value) {
                      if (value == 'edit') onEdit?.call();
                      if (value == 'toggle') onToggle?.call();
                      if (value == 'delete') onDelete?.call();
                    },
                    itemBuilder: (_) => [
                      if (onEdit != null)
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Editar / renomear'),
                        ),
                      if (onToggle != null)
                        PopupMenuItem(
                          value: 'toggle',
                          child: Text(camera.enabled ? 'Desativar' : 'Ativar'),
                        ),
                      if (onDelete != null)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Remover'),
                        ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              status?.message ?? 'Aguardando a primeira verificação.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: lastEvent == null
                  ? const Text('Último evento: nenhum registrado')
                  : Text(
                      'Último: ${ObjectFilterCatalog.singularNameForLabel(lastEvent!.label) ?? 'Detecção'} · ${_eventKind(lastEvent!.type)} · ${_formatDateTime(lastEvent!.createdAt)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: camera.enabled ? onOpen : null,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Monitorar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

String _eventKind(MonitorEventType type) => switch (type) {
      MonitorEventType.alert => 'alerta',
      MonitorEventType.entered => 'entrada',
      MonitorEventType.exited => 'saída',
      MonitorEventType.cameraObstructed => 'câmera obstruída',
      MonitorEventType.cameraMoved => 'câmera deslocada',
    };

String _formatTime(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';

String _formatDateTime(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
