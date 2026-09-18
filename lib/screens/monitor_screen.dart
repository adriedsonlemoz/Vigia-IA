import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/monitor_controller.dart';
import '../core/video_source_status.dart';
import '../models/monitoring_zone.dart';
import '../models/video_source_config.dart';
import '../widgets/detection_overlay.dart';
import '../widgets/monitoring_zone_overlay.dart';
import '../widgets/object_filter_dialog.dart';
import '../widgets/smart_alert_rules_dialog.dart';
import 'events_screen.dart';
import 'settings_screen.dart';

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({
    super.key,
    required this.initialSource,
    required this.settings,
  });

  final VideoSourceConfig initialSource;
  final MonitorSettings settings;

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen>
    with WidgetsBindingObserver {
  late final MonitorController _controller;
  String? _editingZoneId;
  bool _detectionsExpanded = false;
  bool _hudExpanded = false;
  int _lastDetectionCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MonitorController(
      sourceConfig: widget.initialSource,
      settings: widget.settings,
    )..addListener(_refresh);
    unawaited(_controller.initialize());
  }

  void _refresh() {
    if (!mounted) return;
    final currentCount = _controller.trackingEnabled
        ? _controller.trackedDetections.length
        : _controller.detections.length;
    setState(() {
      if (currentCount > 0 && _lastDetectionCount == 0) {
        _detectionsExpanded = true;
      }
      _lastDetectionCount = currentCount;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_controller.resume());
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_controller.suspend());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_refresh);
    _controller.dispose();
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
                subtitle: const Text('MP4 local com GIF de fallback, associado ao evento.'),
              ),
              SwitchListTile(
                value: _controller.trackingEnabled,
                onChanged: (value) {
                  _controller.setTrackingEnabled(value);
                  setSheetState(() {});
                },
                secondary: const Icon(Icons.track_changes),
                title: const Text('Rastreamento individual'),
                subtitle: const Text('Mantém um ID temporário para acompanhar o mesmo objeto entre quadros.'),
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
                subtitle: const Text('Registra quando um objeto entra ou sai de uma área. Isso não é um contador.'),
              ),
              SwitchListTile(
                value: _controller.backgroundMonitoringEnabled,
                onChanged: (value) async {
                  final applied =
                      await _controller.setBackgroundMonitoringEnabled(value);
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
                subtitle: const Text('Mantém câmera/IA com notificação persistente.'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSourceSwitcher() async {
    final current = _controller.sourceConfig;
    var type = current.type;
    final rtspController = TextEditingController(text: current.rtspUrl ?? '');
    final remoteUrlController = TextEditingController(text: current.remoteBaseUrl ?? '');
    final remoteKeyController = TextEditingController(text: current.remoteAccessKey ?? '');
    final next = await showDialog<VideoSourceConfig>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Trocar fonte'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<VideoSourceType>(
                    segments: const [
                      ButtonSegment(
                        value: VideoSourceType.localCamera,
                        icon: Icon(Icons.smartphone_rounded),
                        label: Text('Local'),
                      ),
                      ButtonSegment(
                        value: VideoSourceType.rtsp,
                        icon: Icon(Icons.router_outlined),
                        label: Text('RTSP'),
                      ),
                      ButtonSegment(
                        value: VideoSourceType.remotePhone,
                        icon: Icon(Icons.phone_android_rounded),
                        label: Text('Celular'),
                      ),
                    ],
                    selected: {type},
                    onSelectionChanged: (values) =>
                        setDialogState(() => type = values.first),
                  ),
                  if (type == VideoSourceType.rtsp) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: rtspController,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'URL RTSP',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  if (type == VideoSourceType.remotePhone) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: remoteUrlController,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Endereço do celular',
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
                        border: OutlineInputBorder(),
                      ),
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
                  if (uri == null || uri.scheme != 'rtsp' || uri.host.isEmpty) return;
                }
                if (type == VideoSourceType.remotePhone) {
                  final uri = Uri.tryParse(remoteUrl);
                  if (uri == null ||
                      !(uri.scheme == 'http' || uri.scheme == 'https') ||
                      uri.host.isEmpty ||
                      remoteKey.isEmpty) {
                    return;
                  }
                }
                Navigator.pop(
                  context,
                  VideoSourceConfig(
                    type: type,
                    rtspUrl: type == VideoSourceType.rtsp ? rtsp : null,
                    remoteBaseUrl: type == VideoSourceType.remotePhone ? remoteUrl : null,
                    remoteAccessKey: type == VideoSourceType.remotePhone ? remoteKey : null,
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
    if (next != null && mounted) await _controller.switchSource(next);
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
                  if (running && viewerUrl != null) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'Endereço para assistir',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(sheetContext)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: SelectableText(viewerUrl),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: viewerUrl));
                        if (!sheetContext.mounted) return;
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          const SnackBar(
                            content: Text('Endereço da transmissão copiado.'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copiar endereço'),
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
                      'A chave de acesso já está incluída no endereço. Ela muda quando a sessão de monitoramento é reiniciada.',
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final landscape = MediaQuery.of(context).orientation == Orientation.landscape &&
        size.width >= 700;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            _StatusDot(active: _controller.sourceStatus.state == VideoSourceState.streaming),
            const SizedBox(width: 9),
            const Text('Monitor ao vivo', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Rede local',
            onPressed: _showLanAccess,
            icon: _controller.lanConnectedViewers > 0
                ? Badge(
                    label: Text('${_controller.lanConnectedViewers}'),
                    child: const Icon(Icons.wifi_tethering_rounded),
                  )
                : Icon(
                    _controller.lanStreamRunning
                        ? Icons.wifi_tethering_rounded
                        : Icons.lan_outlined,
                  ),
          ),
          IconButton(
            tooltip: 'Eventos',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const EventsScreen()),
            ),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          IconButton(
            tooltip: 'Configurações',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: _controller.voiceEnabled ? 'Desativar voz' : 'Ativar voz',
            onPressed: () => _controller.setVoiceEnabled(!_controller.voiceEnabled),
            icon: Icon(
              _controller.voiceEnabled
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: landscape ? _buildLandscape(context) : _buildPortrait(context),
      ),
    );
  }

  Widget _buildPortrait(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final expandedHeight = (size.height * 0.38).clamp(260.0, 360.0).toDouble();
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildCameraStage(context),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildControlDock(context, overlay: true),
              Material(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.97),
                elevation: 8,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  height: _detectionsExpanded ? expandedHeight : 58,
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () => setState(() => _detectionsExpanded = !_detectionsExpanded),
                        child: SizedBox(
                          height: 58,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              children: [
                                const Icon(Icons.radar_rounded, size: 20),
                                const SizedBox(width: 9),
                                const Expanded(
                                  child: Text(
                                    'Detectados agora',
                                    style: TextStyle(fontWeight: FontWeight.w900),
                                  ),
                                ),
                                _CountBadge(count: _currentDetectionCount),
                                const SizedBox(width: 4),
                                Icon(
                                  _detectionsExpanded
                                      ? Icons.keyboard_arrow_down_rounded
                                      : Icons.keyboard_arrow_up_rounded,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_detectionsExpanded)
                        Expanded(child: _buildDetectionPanel(context, showHeader: false)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  int get _currentDetectionCount => _controller.trackingEnabled
      ? _controller.trackedDetections.length
      : _controller.detections.length;

  Widget _buildLandscape(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final panelWidth = (width * 0.32).clamp(300.0, 420.0).toDouble();
    return Row(
      children: [
        Expanded(child: _buildCameraStage(context)),
        SizedBox(
          width: panelWidth,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                left: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
              ),
            ),
            child: Column(
              children: [
                _buildControlDock(context, compact: true),
                Expanded(child: _buildDetectionPanel(context, compact: true)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCameraStage(BuildContext context) {
    final status = _controller.sourceStatus;
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!_controller.initializing) _controller.buildPreview(),
          if (_controller.initializing)
            const Center(child: CircularProgressIndicator()),
          if (!_controller.initializing)
            DetectionOverlay(
              detections: _controller.detections,
              trackedDetections: _controller.trackedDetections,
              previewAspectRatio: _controller.previewAspectRatio,
            ),
          if (!_controller.initializing)
            MonitoringZoneOverlay(
              zones: _controller.monitoringZones,
              editingZoneId: _editingZoneId,
              previewAspectRatio: _controller.previewAspectRatio,
              onChanged: _applyZone,
            ),
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _HudPill(
                      icon: status.state == VideoSourceState.streaming
                          ? Icons.fiber_manual_record_rounded
                          : Icons.videocam_off_outlined,
                      label: _statusText(status),
                      active: status.state == VideoSourceState.streaming,
                    ),
                    _HudPill(
                      icon: Icons.psychology_alt_outlined,
                      label: _controller.processing ? 'IA analisando' : 'IA pronta',
                      active: !_controller.initializing,
                    ),
                    _HudPill(
                      icon: _hudExpanded
                          ? Icons.expand_less_rounded
                          : Icons.more_horiz_rounded,
                      label: _hudExpanded ? 'Menos' : 'Status',
                      active: false,
                      onTap: () => setState(() => _hudExpanded = !_hudExpanded),
                    ),
                  ],
                ),
                if (_hudExpanded) ...[
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _HudPill(
                        icon: Icons.grid_view_rounded,
                        label: _controller.activeMonitoringZones.isEmpty
                            ? 'Tela inteira'
                            : '${_controller.activeMonitoringZones.length} áreas',
                        active: true,
                      ),
                      if (_controller.backgroundMonitoringEnabled)
                        const _HudPill(
                          icon: Icons.phone_android_rounded,
                          label: '2º plano',
                          active: true,
                        ),
                      if (_controller.clipRecordingEnabled)
                        _HudPill(
                          icon: Icons.movie_outlined,
                          label: _controller.clipRecording ? 'Gravando clipe' : 'Clipes',
                          active: _controller.clipRecording,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (_editingZoneId != null)
            Positioned(
              right: 12,
              bottom: 12,
              child: IconButton.filledTonal(
                tooltip: 'Cancelar edição da área',
                onPressed: () => setState(() => _editingZoneId = null),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          if (_controller.error != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: _editingZoneId == null ? 12 : 72,
              child: _CameraErrorCard(
                message: _controller.error!,
                onRetry: _controller.initializing
                    ? null
                    : () => unawaited(_controller.retry()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlDock(BuildContext context, {bool compact = false, bool overlay = false}) {
    final buttons = <Widget>[
      _MonitorActionButton(
        icon: Icons.grid_view_rounded,
        label: 'Áreas',
        onTap: () => unawaited(_showZones()),
      ),
      _MonitorActionButton(
        icon: Icons.filter_alt_outlined,
        label: 'Objetos',
        onTap: () => unawaited(_showObjectFilter()),
      ),
      _MonitorActionButton(
        icon: Icons.rule_outlined,
        label: 'Regras',
        onTap: () => unawaited(_showSmartAlertRules()),
      ),
      _MonitorActionButton(
        icon: Icons.cameraswitch_outlined,
        label: 'Fonte',
        onTap: () => unawaited(_showSourceSwitcher()),
      ),
      _MonitorActionButton(
        icon: Icons.auto_awesome_motion_outlined,
        label: 'Recursos',
        onTap: () => unawaited(_showFeatureToggles()),
      ),
    ];

    if (compact) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(
          spacing: 7,
          runSpacing: 7,
          alignment: WrapAlignment.center,
          children: buttons,
        ),
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

  Widget _buildDetectionPanel(BuildContext context, {bool compact = false, bool showHeader = true}) {
    final tracked = _controller.trackingEnabled;
    final count = tracked
        ? _controller.trackedDetections.length
        : _controller.detections.length;
    return ListView(
      padding: EdgeInsets.fromLTRB(compact ? 12 : 14, 12, compact ? 12 : 14, 22),
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
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    Text('Quantidade visível neste instante; não é uma contagem acumulada.'),
                  ],
                ),
              ),
              _CountBadge(count: count),
            ],
          ),
          const SizedBox(height: 10),
        ],
        _RuntimeSummary(controller: _controller),
        if (!_controller.voiceLanguageInstalled && !_controller.initializing) ...[
          const SizedBox(height: 8),
          const _InfoStrip(
            icon: Icons.volume_off_outlined,
            text: 'A voz pt-BR não está instalada. A IA continua funcionando.',
          ),
        ],
        const SizedBox(height: 10),
        if (count == 0 && !_controller.initializing)
          _EmptyDetectionState(
            text: !_controller.scheduleActive
                ? 'Pausado pela agenda. O monitor retomará no próximo horário.'
                : _controller.motionOnly
                    ? 'Aguardando movimento relevante.'
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

  String _statusText(VideoSourceStatus status) {
    return status.message ?? switch (status.state) {
      VideoSourceState.idle => 'Aguardando',
      VideoSourceState.connecting => 'Conectando',
      VideoSourceState.streaming => 'AO VIVO',
      VideoSourceState.reconnecting => 'Reconectando',
      VideoSourceState.stopped => 'Pausado',
      VideoSourceState.error => 'Erro na câmera',
    };
  }
}

class _MonitorActionButton extends StatelessWidget {
  const _MonitorActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 68,
            height: 50,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: scheme.primary, size: 19),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HudPill extends StatelessWidget {
  const _HudPill({
    required this.icon,
    required this.label,
    required this.active,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = active
        ? Theme.of(context).colorScheme.primary
        : Colors.white70;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accent, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ],
      ),
        ),
      ),
    );
  }
}

class _RuntimeSummary extends StatelessWidget {
  const _RuntimeSummary({required this.controller});

  final MonitorController controller;

  @override
  Widget build(BuildContext context) {
    final percent = (controller.motionScore * 100).clamp(0, 100).toStringAsFixed(0);
    final motion = !controller.motionOnly
        ? 'Movimento livre'
        : controller.cameraMotion
            ? 'Movimento da câmera ignorado'
            : controller.motionActive
                ? 'Movimento $percent%'
                : 'Aguardando movimento';
    final schedule = controller.schedule.enabled
        ? (controller.scheduleActive ? 'Agenda ativa agora' : 'Fora da agenda')
        : 'Modo manual';
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        _MiniStatus(icon: Icons.directions_run_rounded, text: motion),
        _MiniStatus(icon: Icons.schedule_rounded, text: schedule),
        _MiniStatus(
          icon: Icons.grid_view_rounded,
          text: controller.activeMonitoringZones.isEmpty
              ? 'Tela inteira'
              : '${controller.activeMonitoringZones.length} áreas',
        ),
        _MiniStatus(
          icon: Icons.filter_alt_outlined,
          text: '${controller.alertLabels.length} objetos',
        ),
      ],
    );
  }
}

class _MiniStatus extends StatelessWidget {
  const _MiniStatus({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _DetectionCard extends StatelessWidget {
  const _DetectionCard({
    required this.label,
    required this.confidence,
    this.trackId,
  });

  final String label;
  final double confidence;
  final int? trackId;

  @override
  Widget build(BuildContext context) {
    final percent = (confidence * 100).round();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outline.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: scheme.primary.withValues(alpha: 0.12),
            child: trackId == null
                ? Icon(Icons.center_focus_strong, color: scheme.primary, size: 18)
                : Text(
                    '#$trackId',
                    style: TextStyle(
                      color: scheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$percent%',
              style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDetectionState extends StatelessWidget {
  const _EmptyDetectionState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Icon(
            Icons.radar_rounded,
            size: 42,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.65),
          ),
          const SizedBox(height: 9),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? Theme.of(context).colorScheme.primary : Colors.white38;
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: active
            ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 8)]
            : null,
      ),
    );
  }
}

class _CameraErrorCard extends StatelessWidget {
  const _CameraErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: error.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          TextButton(onPressed: onRetry, child: const Text('Repetir')),
        ],
      ),
    );
  }
}
