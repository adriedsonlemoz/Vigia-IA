import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/monitor_controller.dart';
import '../services/system_ui_service.dart';
import '../core/video_source_status.dart';
import '../models/monitoring_zone.dart';
import '../models/video_source_config.dart';
import '../services/native_platform_service.dart';
import '../services/remote_camera_pairing_service.dart';
import '../widgets/detection_overlay.dart';
import '../widgets/monitoring_zone_overlay.dart';
import '../widgets/object_filter_dialog.dart';
import '../widgets/remote_bike_status_panel.dart';
import '../widgets/session_status_panel.dart';
import '../widgets/smart_alert_rules_dialog.dart';
import 'events_screen.dart';
import 'phone_pairing_scanner_screen.dart';
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
    unawaited(SystemUiService.immersive());
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
      unawaited(SystemUiService.immersive());
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
                subtitle: const Text('Salva um clipe local quando houver alerta confirmado.'),
              ),
              SwitchListTile(
                value: _controller.trackingEnabled,
                onChanged: (value) {
                  _controller.setTrackingEnabled(value);
                  setSheetState(() {});
                },
                secondary: const Icon(Icons.track_changes),
                title: const Text('Rastreamento individual'),
                subtitle: const Text('Mantém um ID temporário para acompanhar o mesmo objeto entre quadros e reduzir repetições.'),
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
                subtitle: const Text('Registra quando um objeto entra ou sai de uma área monitorada. Não é uma contagem acumulada.'),
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
                subtitle: const Text('Tenta manter câmera e IA ativas com notificação persistente quando você sai da tela.'),
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
          content: const Text('Permita a câmera para escanear o QR do outro celular.'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message.toString())),
      );
    }
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
                    icon: Icons.router_outlined,
                    title: 'Câmera RTSP',
                    subtitle: 'Conecta a uma câmera ou DVR pela URL RTSP.',
                    selected: type == VideoSourceType.rtsp,
                    onTap: () => setDialogState(
                      () => type = VideoSourceType.rtsp,
                    ),
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
                        hintText: 'rtsp://usuario:senha@192.168.1.20:554/stream',
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
                      const SnackBar(content: Text('Informe uma URL RTSP válida.')),
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
                        content: Text('Preencha o endereço local e a chave do outro celular.'),
                      ),
                    );
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
                      onCopy: () => Clipboard.setData(
                        ClipboardData(text: baseAddress),
                      ),
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

  Future<void> _showSessionStatus() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.86,
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => SessionStatusPanel(
            data: _controller.sessionStatus,
          ),
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
    await SystemUiService.edgeToEdge();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
    if (mounted) await SystemUiService.immersive();
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
            const Text('Ao vivo', style: TextStyle(fontWeight: FontWeight.w800)),
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
            tooltip: 'Status da sessão',
            onPressed: _showSessionStatus,
            icon: _controller.remotePhoneWarningCount > 0
                ? Badge(
                    label: Text('${_controller.remotePhoneWarningCount}'),
                    child: const Icon(Icons.monitor_heart_outlined),
                  )
                : const Icon(Icons.monitor_heart_outlined),
          ),
          IconButton(
            tooltip: 'Eventos',
            onPressed: () => unawaited(
              _openStandardScreen(const EventsScreen()),
            ),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          IconButton(
            tooltip: 'Configurações',
            onPressed: () => unawaited(
              _openStandardScreen(const SettingsScreen()),
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
    final remoteStatus = _controller.remotePhoneStatus;
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
                      label: _controller.processing ? 'IA analisando' : 'IA ativa',
                      active: !_controller.initializing,
                    ),
                    if (_controller.isRemotePhoneSource)
                      _HudPill(
                        icon: remoteStatus?.device?.batteryCharging == true
                            ? Icons.battery_charging_full_rounded
                            : Icons.directions_bike_rounded,
                        label: remoteBikeCompactSummary(remoteStatus),
                        active: remoteStatus != null && remoteStatus.warnings().isEmpty,
                        onTap: _showRemoteBikeStatus,
                      ),
                    _HudPill(
                      icon: _hudExpanded
                          ? Icons.expand_less_rounded
                          : Icons.more_horiz_rounded,
                      label: _hudExpanded ? 'Ocultar' : 'Painel',
                      active: false,
                      onTap: () => setState(() => _hudExpanded = !_hudExpanded),
                    ),
                  ],
                ),
                if (remoteStatus != null && remoteStatus.warnings().isNotEmpty) ...[
                  const SizedBox(height: 7),
                  RemoteBikeWarningBanner(
                    status: remoteStatus,
                    onTap: _showRemoteBikeStatus,
                  ),
                ],
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

  String _statusText(VideoSourceStatus status) {
    return status.message ?? switch (status.state) {
      VideoSourceState.idle => 'Aguardando',
      VideoSourceState.connecting => 'Conectando',
      VideoSourceState.streaming => 'Ao vivo',
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

class _SourceOptionTile extends StatelessWidget {
  const _SourceOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary.withValues(alpha: 0.10) : scheme.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.52)
                  : scheme.outline.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(subtitle),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ],
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 184),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 14),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
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

class _LanValueRow extends StatelessWidget {
  const _LanValueRow({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final String label;
  final String value;
  final Future<void> Function() onCopy;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 2),
                    SelectableText(
                      value,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Copiar $label',
                onPressed: () => unawaited(onCopy()),
                icon: const Icon(Icons.copy_rounded),
              ),
            ],
          ),
        ),
      );
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
