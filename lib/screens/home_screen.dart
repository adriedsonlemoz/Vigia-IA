import 'dart:async';

import 'package:flutter/material.dart';

import '../models/monitor_schedule.dart';
import '../models/monitoring_zone.dart';
import '../models/object_filter_catalog.dart';
import '../models/smart_alert_rules.dart';
import '../models/video_source_config.dart';
import '../services/app_settings_service.dart';
import '../services/background_monitor_service.dart';
import '../services/native_platform_service.dart';
import '../services/remote_camera_pairing_service.dart';
import '../widgets/main_navigation_bar.dart';
import '../widgets/object_filter_dialog.dart';
import '../widgets/smart_alert_rules_dialog.dart';
import 'events_screen.dart';
import 'settings_screen.dart';
import 'monitor_screen.dart';
import 'multi_camera_screen.dart';
import 'phone_pairing_scanner_screen.dart';

part 'home_screen_components.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.startMonitorOnLoad = false});

  final bool startMonitorOnLoad;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AppSettingsService _settingsService = AppSettingsService.instance;
  final NativePlatformService _native = NativePlatformService.instance;
  VideoSourceType _sourceType = VideoSourceType.localCamera;
  final _rtspController = TextEditingController();
  final _remoteUrlController = TextEditingController();
  final _remoteKeyController = TextEditingController();
  MonitorSettings _loadedSettings = const MonitorSettings();
  Timer? _persistDebounce;
  bool _loading = true;
  double _confidence = 0.55;
  bool _motionOnly = true;
  double _analysisMs = 400;
  double _repeatSeconds = 60;
  double _absenceSeconds = 1;
  int _maxResults = 10;
  int _motionConfirmationHits = 2;
  Set<String> _alertLabels = <String>{...ObjectFilterCatalog.recommended};
  SmartAlertRules _smartAlertRules = const SmartAlertRules();
  List<MonitoringZoneProfile> _monitoringZones = const <MonitoringZoneProfile>[
    MonitoringZoneProfile.primary(),
  ];
  MonitorSchedule _schedule = const MonitorSchedule();
  bool _clipRecordingEnabled = true;
  bool _trackingEnabled = true;
  bool _announceEntryExit = true;
  bool _backgroundMonitoringEnabled = false;
  bool _voiceEnabled = true;
  bool _autoStartTriggered = false;

  @override
  void initState() {
    super.initState();
    _rtspController.addListener(_onSourceDetailsChanged);
    _remoteUrlController.addListener(_onSourceDetailsChanged);
    _remoteKeyController.addListener(_onSourceDetailsChanged);
    unawaited(_loadSettings());
  }

  @override
  void dispose() {
    _persistDebounce?.cancel();
    _rtspController
      ..removeListener(_onSourceDetailsChanged)
      ..dispose();
    _remoteUrlController
      ..removeListener(_onSourceDetailsChanged)
      ..dispose();
    _remoteKeyController
      ..removeListener(_onSourceDetailsChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final profile = await _settingsService.initialize();
    if (!mounted) return;
    final source = profile.source;
    final settings = profile.settings;
    setState(() {
      _sourceType = source.type;
      _rtspController.text = source.rtspUrl ?? '';
      _remoteUrlController.text = source.remoteBaseUrl ?? '';
      _remoteKeyController.text = source.remoteAccessKey ?? '';
      _loadedSettings = settings;
      _analysisMs = source.analysisInterval.inMilliseconds.toDouble();
      _confidence = settings.confidenceThreshold;
      _motionOnly = settings.motionOnly;
      _repeatSeconds = settings.repeatInterval.inMilliseconds / 1000;
      _absenceSeconds = settings.absenceReset.inMilliseconds / 1000;
      _maxResults = settings.maxResults;
      _motionConfirmationHits = settings.motionConfirmationHits;
      _alertLabels = <String>{...settings.alertLabels};
      _smartAlertRules = settings.smartAlertRules;
      _monitoringZones = List<MonitoringZoneProfile>.from(settings.monitoringZones);
      _schedule = settings.schedule;
      _clipRecordingEnabled = settings.clipRecordingEnabled;
      _trackingEnabled = settings.trackingEnabled;
      _announceEntryExit = settings.announceEntryExit;
      _backgroundMonitoringEnabled = settings.backgroundMonitoringEnabled;
      _voiceEnabled = settings.voiceEnabled;
      _loading = false;
    });
    final resumeRequested = await BackgroundMonitorService.consumeResumeRequest();
    if (!mounted) return;
    if ((widget.startMonitorOnLoad || resumeRequested) && !_autoStartTriggered) {
      _autoStartTriggered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_start());
      });
    }
  }

  void _onSourceDetailsChanged() {
    if (_loading) return;
    _schedulePersist();
  }

  void _schedulePersist() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(
      const Duration(milliseconds: 250),
      () => unawaited(_persist()),
    );
  }

  Future<void> _persist() => _settingsService.saveProfile(_currentProfile());

  PersistedMonitorProfile _currentProfile() {
    final rtsp = _rtspController.text.trim();
    final remoteUrl = _remoteUrlController.text.trim();
    final remoteKey = _remoteKeyController.text.trim();
    final outputs = _loadedSettings.alertOutputs.copyWith(voice: _voiceEnabled);
    return PersistedMonitorProfile(
      source: VideoSourceConfig(
        type: _sourceType,
        rtspUrl: rtsp.isEmpty ? null : rtsp,
        remoteBaseUrl: remoteUrl.isEmpty ? null : remoteUrl,
        remoteAccessKey: remoteKey.isEmpty ? null : remoteKey,
        analysisInterval: Duration(milliseconds: _analysisMs.round()),
      ),
      settings: _loadedSettings.copyWith(
        confidenceThreshold: _confidence,
        repeatInterval: Duration(seconds: _repeatSeconds.round()),
        absenceReset: Duration(milliseconds: (_absenceSeconds * 1000).round()),
        maxResults: _maxResults,
        motionOnly: _motionOnly,
        motionConfirmationHits: _motionConfirmationHits,
        alertLabels: Set<String>.unmodifiable(_alertLabels),
        smartAlertRules: _smartAlertRules,
        monitoringZones: List<MonitoringZoneProfile>.unmodifiable(_monitoringZones),
        clipRecordingEnabled: _clipRecordingEnabled,
        trackingEnabled: _trackingEnabled,
        announceEntryExit: _announceEntryExit,
        backgroundMonitoringEnabled: _backgroundMonitoringEnabled,
        voiceEnabled: _voiceEnabled,
        alertOutputs: outputs,
        schedule: _schedule,
      ),
    );
  }

  Future<void> _configureObjectFilter() async {
    final result = await showObjectFilterDialog(
      context: context,
      selectedLabels: _alertLabels,
    );
    if (result == null || !mounted) return;
    setState(() => _alertLabels = <String>{...result});
    _schedulePersist();
  }

  Future<void> _configureSmartAlertRules() async {
    final result = await showSmartAlertRulesDialog(
      context: context,
      initialRules: _smartAlertRules,
    );
    if (result == null || !mounted) return;
    setState(() => _smartAlertRules = result);
    _schedulePersist();
  }

  Future<void> _configureSchedule() async {
    var draft = _schedule;
    final result = await showDialog<MonitorSchedule>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> pickTime(bool start) async {
            final minute = start ? draft.startMinute : draft.endMinute;
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
            );
            if (picked == null) return;
            setDialogState(() {
              final nextMinute = picked.hour * 60 + picked.minute;
              draft = start
                  ? draft.copyWith(startMinute: nextMinute)
                  : draft.copyWith(endMinute: nextMinute);
            });
          }

          const dayNames = <int, String>{
            DateTime.monday: 'Seg',
            DateTime.tuesday: 'Ter',
            DateTime.wednesday: 'Qua',
            DateTime.thursday: 'Qui',
            DateTime.friday: 'Sex',
            DateTime.saturday: 'Sáb',
            DateTime.sunday: 'Dom',
          };
          return AlertDialog(
            title: const Text('Agendamento'),
            content: SizedBox(
              width: 430,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: draft.enabled,
                      onChanged: (value) =>
                          setDialogState(() => draft = draft.copyWith(enabled: value)),
                      title: const Text('Usar horário programado'),
                      subtitle: const Text(
                        'Com o monitor aberto, a câmera inicia e pausa automaticamente.',
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Dias da semana'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: dayNames.entries.map((entry) {
                        final selected = draft.weekdays.contains(entry.key);
                        return FilterChip(
                          label: Text(entry.value),
                          selected: selected,
                          onSelected: (value) {
                            final days = <int>{...draft.weekdays};
                            value ? days.add(entry.key) : days.remove(entry.key);
                            setDialogState(
                              () => draft = draft.copyWith(weekdays: days),
                            );
                          },
                        );
                      }).toList(growable: false),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => pickTime(true),
                            icon: const Icon(Icons.play_arrow),
                            label: Text(
                              'Início ${formatMinuteOfDay(draft.startMinute)}',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => pickTime(false),
                            icon: const Icon(Icons.stop),
                            label: Text(
                              'Fim ${formatMinuteOfDay(draft.endMinute)}',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Horários que atravessam a meia-noite são suportados.',
                    ),
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
                onPressed: () => Navigator.pop(context, draft),
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _schedule = result);
    _schedulePersist();
  }

  Future<void> _scanRemotePhoneQr() async {
    final cameraGranted = await _native.requestCameraPermission();
    if (!mounted) return;
    if (!cameraGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Permita a câmera para escanear o QR do outro celular.'),
          action: SnackBarAction(
            label: 'AJUSTES',
            onPressed: () => unawaited(_native.openAppSettings()),
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
      setState(() {
        _sourceType = VideoSourceType.remotePhone;
        _remoteUrlController.text = pairing.address;
        _remoteKeyController.text = pairing.accessKey;
      });
      _schedulePersist();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Celular remoto preenchido: ${pairing.name}.')),
      );
    } on FormatException catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message.toString())),
      );
    }
  }

  Future<void> _start() async {
    final profile = _currentProfile();
    if (_sourceType == VideoSourceType.localCamera) {
      final cameraGranted = await _native.requestCameraPermission();
      if (!mounted) return;
      if (!cameraGranted) {
        final permission = await _native.cameraPermissionStatus();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              permission.canRequest
                  ? 'A câmera precisa ser permitida para iniciar o monitoramento.'
                  : 'A permissão da câmera está bloqueada. Libere-a nos ajustes do aplicativo.',
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
      final notificationsAllowed = await _native.requestNotificationPermission();
      if (!mounted) return;
      if (!notificationsAllowed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'O monitor pode continuar em segundo plano, mas a notificação permanente pode ficar oculta sem permissão de notificações.',
            ),
          ),
        );
      }
    }
    final rtsp = profile.source.rtspUrl ?? '';
    if (_sourceType == VideoSourceType.rtsp) {
      final uri = Uri.tryParse(rtsp);
      if (uri == null || uri.scheme != 'rtsp' || uri.host.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informe uma URL RTSP válida.')),
        );
        return;
      }
    }
    if (_sourceType == VideoSourceType.remotePhone) {
      final uri = Uri.tryParse(profile.source.remoteBaseUrl ?? '');
      if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host.isEmpty || (profile.source.remoteAccessKey ?? '').isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informe o endereço local e a chave do celular remoto.')),
        );
        return;
      }
    }

    await _settingsService.saveProfile(profile);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MonitorScreen(
          initialSource: profile.source,
          settings: profile.settings,
        ),
      ),
    );
    if (mounted) await _loadSettings();
  }

  void _navigateMain(int index) {
    if (index == 0) return;
    if (index == 2) {
      unawaited(_start());
      return;
    }
    final Widget target = switch (index) {
      1 => const EventsScreen(),
      3 => const MultiCameraScreen(),
      _ => const HomeScreen(),
    };
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => target),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
    if (mounted) await _loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final activeZones = _monitoringZones.where((zone) => zone.enabled).length;

    final overview = <Widget>[
      _buildHero(context, activeZones),
      const SizedBox(height: 16),
      _buildSourcePanel(context),
      const SizedBox(height: 16),
      _PrivacyCard(sourceType: _sourceType),
    ];
    final controls = <Widget>[
      _SectionTitle(
        eyebrow: 'MONITORAMENTO',
        title: 'O que a IA deve observar',
        subtitle: 'Os ajustes mais usados ficam aqui; parâmetros técnicos ficam em Configurações → Avançado.',
      ),
      const SizedBox(height: 10),
      _ActionCard(
        icon: Icons.filter_alt_outlined,
        title: 'Objetos monitorados',
        subtitle: objectFilterSummary(_alertLabels),
        badge: '${objectFilterGroupCount(_alertLabels)}/3',
        onTap: _configureObjectFilter,
      ),
      _ActionCard(
        icon: Icons.rule_outlined,
        title: 'Regras inteligentes',
        subtitle: smartAlertRulesSummary(_smartAlertRules),
        onTap: _configureSmartAlertRules,
      ),
      _ActionCard(
        icon: Icons.grid_view_rounded,
        title: 'Áreas de vigilância',
        subtitle: activeZones == 0
            ? 'Tela inteira. Áreas limitam onde a IA observa; elas não fazem contagem.'
            : '$activeZones ativa(s) de ${_monitoringZones.length}. Áreas limitam a região observada e não contam passagens.',
        badge: activeZones == 0 ? 'Tela toda' : '$activeZones',
      ),
      _ActionCard(
        icon: Icons.schedule_rounded,
        title: 'Agenda automática',
        subtitle: monitorScheduleSummary(_schedule),
        badge: _schedule.enabled ? 'Ativa' : 'Manual',
        onTap: _configureSchedule,
      ),
      const SizedBox(height: 18),
      const _SectionTitle(
        eyebrow: 'AUTOMAÇÃO',
        title: 'Recursos do monitor',
        subtitle: 'Ligue só o que fizer sentido para o seu cenário.',
      ),
      const SizedBox(height: 10),
      _FeatureGrid(
        motionOnly: _motionOnly,
        clipRecordingEnabled: _clipRecordingEnabled,
        trackingEnabled: _trackingEnabled,
        announceEntryExit: _trackingEnabled && _announceEntryExit,
        backgroundMonitoringEnabled: _backgroundMonitoringEnabled,
        voiceEnabled: _voiceEnabled,
        onMotionChanged: (value) {
          setState(() => _motionOnly = value);
          _schedulePersist();
        },
        onClipChanged: (value) {
          setState(() => _clipRecordingEnabled = value);
          _schedulePersist();
        },
        onTrackingChanged: (value) {
          setState(() => _trackingEnabled = value);
          _schedulePersist();
        },
        onEntryExitChanged: _trackingEnabled
            ? (value) {
                setState(() => _announceEntryExit = value);
                _schedulePersist();
              }
            : null,
        onBackgroundChanged: (value) {
          setState(() => _backgroundMonitoringEnabled = value);
          _schedulePersist();
        },
        onVoiceChanged: (value) {
          setState(() => _voiceEnabled = value);
          _schedulePersist();
        },
      ),
    ];

    overview.addAll([
      const SizedBox(height: 14),
      FilledButton.icon(
        onPressed: _start,
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'INICIAR MONITORAMENTO',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ),
    ]);

    return AdaptiveMainScaffold(
      currentIndex: 0,
      onDestinationSelected: _navigateMain,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vigia IA', style: TextStyle(fontWeight: FontWeight.w800)),
            Text(
              'Vigilância local e privada',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Ajustes e informações',
            onPressed: () => unawaited(_openSettings()),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 700;
            final content = wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 9,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 12, 10, 28),
                          children: overview,
                        ),
                      ),
                      Expanded(
                        flex: 11,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(10, 12, 20, 28),
                          children: controls,
                        ),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                    children: [...overview, const SizedBox(height: 22), ...controls],
                  );
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: content,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context, int activeZones) {
    final scheme = Theme.of(context).colorScheme;
    final sourceText = switch (_sourceType) {
      VideoSourceType.localCamera => 'Dispositivo',
      VideoSourceType.rtsp => 'RTSP',
      VideoSourceType.remotePhone => 'Celular remoto',
    };
    final scheduleText = _schedule.enabled
        ? '${formatMinuteOfDay(_schedule.startMinute)}–${formatMinuteOfDay(_schedule.endMinute)}'
        : 'Manual';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.18),
            scheme.secondary.withValues(alpha: 0.07),
            scheme.surface,
          ],
        ),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.shield_outlined, color: scheme.primary, size: 21),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Pronto para monitorar',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              const _LiveDot(label: 'LOCAL'),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _MetricChip(icon: Icons.videocam_outlined, label: sourceText),
              _MetricChip(
                icon: Icons.grid_view_rounded,
                label: activeZones == 0 ? 'Tela inteira' : '$activeZones áreas',
              ),
              _MetricChip(icon: Icons.schedule_rounded, label: scheduleText),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSourcePanel(BuildContext context) {
    return _SurfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cameraswitch_outlined, size: 20),
              SizedBox(width: 8),
              Text(
                'Fonte de vídeo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<VideoSourceType>(
            segments: const [
              ButtonSegment(
                value: VideoSourceType.localCamera,
                icon: Icon(Icons.phone_android_rounded),
                label: FittedBox(fit: BoxFit.scaleDown, child: Text('Local')),
              ),
              ButtonSegment(
                value: VideoSourceType.rtsp,
                icon: Icon(Icons.router_outlined),
                label: FittedBox(fit: BoxFit.scaleDown, child: Text('RTSP')),
              ),
              ButtonSegment(
                value: VideoSourceType.remotePhone,
                icon: Icon(Icons.phone_android_rounded),
                label: FittedBox(fit: BoxFit.scaleDown, child: Text('Remoto')),
              ),
            ],
            selected: {_sourceType},
            onSelectionChanged: (values) {
              setState(() => _sourceType = values.first);
              _schedulePersist();
            },
          ),
          if (_sourceType == VideoSourceType.rtsp) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _rtspController,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Endereço RTSP',
                hintText: 'rtsp://usuario:senha@192.168.1.20:554/stream',
                helperText: 'Salvo somente no armazenamento privado do aparelho.',
                prefixIcon: Icon(Icons.link_rounded),
              ),
            ),
          ],
          if (_sourceType == VideoSourceType.remotePhone) ...[
            const SizedBox(height: 12),
            const Text(
              'Conecte outro aparelho pelo endereço manual ou lendo o QR exibido no Modo Câmera.',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _scanRemotePhoneQr,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Escanear QR do outro celular'),
                ),
                OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _remoteUrlController.clear();
                    _remoteKeyController.clear();
                  }),
                  icon: const Icon(Icons.clear_rounded),
                  label: const Text('Limpar campos'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _remoteUrlController,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Endereço do celular',
                hintText: 'http://192.168.1.10:8765',
                helperText: 'Use o endereço exibido no Modo Câmera do outro aparelho.',
                prefixIcon: Icon(Icons.wifi_rounded),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _remoteKeyController,
              autocorrect: false,
              enableSuggestions: false,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Chave de sessão',
                prefixIcon: Icon(Icons.key_rounded),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
