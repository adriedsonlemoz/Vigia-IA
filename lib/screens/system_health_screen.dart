import 'dart:async';

import 'package:flutter/material.dart';

import '../models/system_health.dart';
import '../models/video_source_config.dart';
import '../services/app_settings_service.dart';
import '../services/system_health_service.dart';
import '../utils/storage_size_formatter.dart';
import '../widgets/help_button.dart';

class SystemHealthScreen extends StatefulWidget {
  const SystemHealthScreen({super.key});

  @override
  State<SystemHealthScreen> createState() => _SystemHealthScreenState();
}

class _SystemHealthScreenState extends State<SystemHealthScreen> {
  final _health = SystemHealthService();
  final _settings = AppSettingsService.instance;
  SystemHealthSnapshot? _snapshot;
  PersistedMonitorProfile? _profile;
  Timer? _timer;
  bool _loading = true;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_refresh()),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    _profile = await _settings.initialize();
    await _refresh();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggleIntegrity(bool value) async {
    final profile = _profile;
    if (profile == null) return;
    final next = PersistedMonitorProfile(
      source: profile.source,
      settings: profile.settings.copyWith(cameraIntegrityEnabled: value),
    );
    await _settings.saveProfile(next);
    if (mounted) setState(() => _profile = next);
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final snapshot = await _health.collect();
      if (mounted) setState(() => _snapshot = snapshot);
    } finally {
      _refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    if (_loading || snapshot == null || _profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final summary = _summary(snapshot);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saúde do sistema'),
        actions: [
          const HelpButton(
            title: 'Saúde do sistema',
            message:
                'Mostra o estado real do monitoramento. Serviço ativo sozinho não significa que a câmera e a IA estejam recebendo imagens.',
          ),
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _refreshing ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          _SummaryCard(
            icon: summary.icon,
            title: summary.title,
            subtitle: summary.subtitle,
            color: summary.color,
          ),
          const SizedBox(height: 16),
          const _SectionTitle('Monitoramento'),
          _HealthTile(
            icon: Icons.layers_outlined,
            title: 'Serviço Android ativo',
            value: snapshot.androidServiceActive ? 'Ativo' : 'Parado',
            state: snapshot.androidServiceActive
                ? _TileState.good
                : _TileState.neutral,
          ),
          _HealthTile(
            icon: Icons.videocam_outlined,
            title: 'Câmera ativa',
            value: snapshot.cameraActive ? 'Ativa' : 'Inativa',
            subtitle: '${snapshot.source} • ${_cameraHealthLabel(snapshot.cameraHealth)}',
            state: snapshot.monitoringActive &&
                    (!snapshot.cameraActive ||
                        snapshot.cameraHealth == CameraHealthState.obstructed ||
                        snapshot.cameraHealth == CameraHealthState.moved ||
                        snapshot.cameraHealth == CameraHealthState.offline)
                ? _TileState.warning
                : snapshot.cameraActive
                    ? _TileState.good
                    : _TileState.neutral,
          ),
          _HealthTile(
            icon: Icons.dynamic_feed_outlined,
            title: 'Frames chegando',
            value: snapshot.framesActive ? 'Sim' : 'Não',
            subtitle: _lastFrameText(snapshot.lastFrameAt),
            state: snapshot.monitoringActive && !snapshot.framesActive
                ? _TileState.warning
                : snapshot.framesActive
                    ? _TileState.good
                    : _TileState.neutral,
          ),
          _HealthTile(
            icon: Icons.psychology_outlined,
            title: 'Monitoramento IA ativo',
            value: snapshot.aiActive ? 'Ativo' : 'Parado',
            subtitle: snapshot.aiReady
                ? 'Modelo carregado'
                : 'Modelo de IA não está pronto',
            state: snapshot.monitoringActive && !snapshot.aiActive
                ? _TileState.warning
                : snapshot.aiActive
                    ? _TileState.good
                    : _TileState.neutral,
          ),
          _HealthTile(
            icon: Icons.lan_outlined,
            title: 'Servidor LAN',
            value: snapshot.lanServerActive ? 'Ativo' : 'Inativo',
            subtitle: snapshot.lanError,
            state: snapshot.lanError != null
                ? _TileState.warning
                : snapshot.lanServerActive
                    ? _TileState.good
                    : _TileState.neutral,
          ),
          _HealthTile(
            icon: Icons.wifi_tethering_rounded,
            title: 'Transmissão LAN',
            value: snapshot.lanActive
                ? 'Operacional'
                : snapshot.lanServerActive && !snapshot.lanFramesActive
                    ? 'Sem frames'
                    : 'Inativa',
            subtitle: _lastLanFrameText(snapshot.lanLastFrameAt),
            state: snapshot.lanServerActive && !snapshot.lanActive
                ? _TileState.warning
                : snapshot.lanActive
                    ? _TileState.good
                    : _TileState.neutral,
          ),
          _HealthTile(
            icon: Icons.devices_rounded,
            title: 'Clientes conectados',
            value: '${snapshot.connectedClients}',
            subtitle: snapshot.connectedClients == 1
                ? '1 aparelho assistindo'
                : '${snapshot.connectedClients} aparelhos assistindo',
          ),
          _HealthTile(
            icon: Icons.phone_android_rounded,
            title: 'Funcionamento em segundo plano',
            value: _backgroundLabel(snapshot),
            subtitle: snapshot.backgroundRequested
                ? snapshot.flutterHeartbeatFresh
                    ? 'Serviço, processo Flutter e frames são verificados separadamente.'
                    : 'Serviço Android sem heartbeat recente do Vigia IA.'
                : 'Opção de segundo plano desativada.',
            state: snapshot.backgroundOperational
                ? _TileState.good
                : snapshot.backgroundRequested &&
                        (snapshot.monitoringActive || !snapshot.androidServiceActive)
                    ? _TileState.warning
                    : _TileState.neutral,
          ),
          _HealthTile(
            icon: Icons.admin_panel_settings_outlined,
            title: 'Estado de permissões',
            value: snapshot.permissionsReady ? 'OK' : 'Revisar',
            subtitle: _permissionText(snapshot),
            state: snapshot.permissionsReady
                ? _TileState.good
                : _TileState.warning,
          ),
          const SizedBox(height: 16),
          const _SectionTitle('Métricas do aparelho'),
          _HealthTile(
            icon: Icons.speed_rounded,
            title: 'FPS de análise',
            value: snapshot.framesActive
                ? snapshot.fps.toStringAsFixed(1)
                : 'Sem amostra',
          ),
          _HealthTile(
            icon: snapshot.batteryCharging == true
                ? Icons.battery_charging_full_rounded
                : Icons.battery_5_bar_outlined,
            title: 'Bateria',
            value: snapshot.batteryPercent == null
                ? 'Indisponível'
                : '${snapshot.batteryPercent}%',
            subtitle: snapshot.batteryCharging == null
                ? null
                : snapshot.batteryCharging!
                    ? '${snapshot.batteryPowerSource ?? 'Carregando'}${snapshot.batteryCurrentMa == null ? '' : ' • ${snapshot.batteryCurrentMa!.toStringAsFixed(0)} mA'}'
                    : 'Usando bateria',
          ),
          _HealthTile(
            icon: Icons.device_thermostat_outlined,
            title: 'Temperatura da bateria',
            value: snapshot.batteryTemperatureC == null
                ? 'Indisponível'
                : '${snapshot.batteryTemperatureC!.toStringAsFixed(1)} °C',
          ),
          _HealthTile(
            icon: Icons.brightness_6_outlined,
            title: 'Tela / brilho',
            value: snapshot.screenBrightnessPercent == null
                ? 'Indisponível'
                : '${snapshot.screenBrightnessPercent}%',
            subtitle: snapshot.screenDimmedByBike
                ? 'Brilho reduzido pelo Modo Bike'
                : snapshot.automaticBrightness == true
                    ? 'Brilho automático'
                    : null,
          ),
          _HealthTile(
            icon: Icons.speed_rounded,
            title: 'CPU do Vigia IA',
            value: snapshot.appCpuPercent == null
                ? 'Calculando…'
                : '${snapshot.appCpuPercent!.toStringAsFixed(1)}%',
            subtitle: snapshot.processorCount == null
                ? 'Uso do processo do app'
                : '${snapshot.processorCount} núcleos disponíveis',
          ),
          _HealthTile(
            icon: Icons.memory_rounded,
            title: 'Memória do processo',
            value: snapshot.memoryUsedBytes == null
                ? 'Indisponível'
                : StorageSizeFormatter.formatBytes(snapshot.memoryUsedBytes!),
            subtitle: snapshot.memoryAvailableBytes == null || snapshot.memoryTotalBytes == null
                ? null
                : '${StorageSizeFormatter.formatBytes(snapshot.memoryAvailableBytes!)} livres de ${StorageSizeFormatter.formatBytes(snapshot.memoryTotalBytes!)} no aparelho',
          ),
          _HealthTile(
            icon: Icons.storage_outlined,
            title: 'Armazenamento',
            value: snapshot.freeStorageBytes == null ||
                    snapshot.totalStorageBytes == null
                ? 'Indisponível'
                : '${StorageSizeFormatter.formatBytes(snapshot.freeStorageBytes!)} livres',
            subtitle: snapshot.totalStorageBytes == null
                ? null
                : 'Total: ${StorageSizeFormatter.formatBytes(snapshot.totalStorageBytes!)}',
          ),
          _HealthTile(
            icon: Icons.error_outline_rounded,
            title: 'Erros/avisos recentes',
            value: '${snapshot.recentErrors}',
            state: snapshot.recentErrors == 0
                ? _TileState.good
                : _TileState.warning,
          ),
          const SizedBox(height: 10),
          Card(
            child: SwitchListTile(
              value: _profile!.settings.cameraIntegrityEnabled,
              onChanged: _toggleIntegrity,
              secondary: const Icon(Icons.visibility_outlined),
              title: const Text(
                'Detectar câmera obstruída ou deslocada',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text(
                'Compara brilho e enquadramento localmente e sinaliza mudanças bruscas.',
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Os dados são coletados localmente. Métricas não fornecidas com segurança pelo Android aparecem como “Indisponível”.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  _SummaryData _summary(SystemHealthSnapshot snapshot) {
    return switch (snapshot.operationalState) {
      SystemOperationalState.healthy => const _SummaryData(
          Icons.verified_outlined,
          'Monitoramento funcionando',
          'Câmera, frames e IA estão ativos.',
          Color(0xFF4ADE80),
        ),
      SystemOperationalState.attention => _SummaryData(
          Icons.warning_amber_rounded,
          'Monitoramento precisa de atenção',
          snapshot.framesActive
              ? 'Há uma etapa do fluxo que não está operacional.'
              : 'O monitor está ativo, mas não há frames recentes.',
          const Color(0xFFFFB74D),
        ),
      SystemOperationalState.idle => _SummaryData(
          Icons.pause_circle_outline_rounded,
          snapshot.androidServiceActive
              ? 'Serviço ativo, captura inativa'
              : 'Monitoramento inativo',
          snapshot.androidServiceActive
              ? 'O serviço Android está ativo, mas isso não confirma câmera ou IA funcionando.'
              : 'Inicie o monitoramento para acompanhar câmera, frames e IA.',
          Theme.of(context).colorScheme.onSurfaceVariant,
        ),
    };
  }

  String _lastFrameText(DateTime? value) {
    if (value == null) return 'Nenhum frame recente';
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'Último frame: ${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  String _lastLanFrameText(DateTime? value) {
    if (value == null) return 'Nenhum JPEG recente enviado pela LAN';
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'Último JPEG LAN: ${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  String _backgroundLabel(SystemHealthSnapshot snapshot) {
    if (!snapshot.backgroundRequested) return 'Desativado';
    if (snapshot.backgroundOperational) return 'Operacional';
    if (snapshot.androidServiceActive && !snapshot.flutterHeartbeatFresh) {
      return 'App sem resposta';
    }
    if (snapshot.androidServiceActive && !snapshot.monitoringActive) {
      return 'Aguardando captura';
    }
    if (snapshot.androidServiceActive && !snapshot.framesActive) {
      return 'Serviço sem frames';
    }
    return 'Indisponível';
  }


  String _cameraHealthLabel(CameraHealthState state) => switch (state) {
        CameraHealthState.ok => 'integridade OK',
        CameraHealthState.obstructed => 'obstruída',
        CameraHealthState.moved => 'deslocada',
        CameraHealthState.offline => 'offline',
        CameraHealthState.unknown => 'sem dados de integridade',
      };

  String _permissionText(SystemHealthSnapshot snapshot) {
    final camera = !snapshot.cameraPermissionRequired
        ? 'câmera não exigida'
        : snapshot.cameraPermissionGranted
            ? 'câmera OK'
            : 'câmera negada';
    final lan = !snapshot.localNetworkPermissionRequired
        ? 'LAN não exigida'
        : snapshot.localNetworkPermissionGranted
            ? 'LAN OK'
            : 'LAN negada';
    final notifications = snapshot.notificationsAllowed
        ? 'notificações OK'
        : 'notificações desativadas';
    return '$camera • $lan • $notifications';
  }
}

class _SummaryData {
  const _SummaryData(this.icon, this.title, this.subtitle, this.color);
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 112),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
        child: Text(
          text,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
      );
}

enum _TileState { neutral, good, warning }

class _HealthTile extends StatelessWidget {
  const _HealthTile({
    required this.icon,
    required this.title,
    required this.value,
    this.subtitle,
    this.state = _TileState.neutral,
  });

  final IconData icon;
  final String title;
  final String value;
  final String? subtitle;
  final _TileState state;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _TileState.good => const Color(0xFF4ADE80),
      _TileState.warning => const Color(0xFFFFB74D),
      _TileState.neutral => Theme.of(context).colorScheme.onSurfaceVariant,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 78),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: SizedBox(width: 28, child: Icon(icon)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: subtitle == null
              ? null
              : Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
          trailing: SizedBox(
            width: 118,
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w900, color: color),
            ),
          ),
        ),
      ),
    );
  }
}
