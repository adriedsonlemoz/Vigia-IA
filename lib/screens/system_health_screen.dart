import 'dart:async';
import 'package:flutter/material.dart';
import '../models/system_health.dart';
import '../models/video_source_config.dart';
import '../services/app_settings_service.dart';
import '../services/background_monitor_service.dart';
import '../services/error_log_service.dart';
import '../services/native_platform_service.dart';
import '../services/runtime_health_service.dart';

class SystemHealthScreen extends StatefulWidget {
  const SystemHealthScreen({super.key});

  @override
  State<SystemHealthScreen> createState() => _SystemHealthScreenState();
}

class _SystemHealthScreenState extends State<SystemHealthScreen> {
  final _native = NativePlatformService.instance;
  final _runtime = RuntimeHealthService.instance;
  final _logs = ErrorLogService.instance;
  final _settings = AppSettingsService.instance;
  SystemHealthSnapshot? _snapshot;
  PersistedMonitorProfile? _profile;
  Timer? _timer;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => unawaited(_refresh()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    await _logs.initialize();
    _profile = await _settings.initialize();
    await _refresh();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refresh() async {
    final running = await BackgroundMonitorService.isRunning();
    final snap = await _native.readSystemHealth(
      source: _runtime.source,
      aiReady: _runtime.aiReady,
      fps: _runtime.fps,
      backgroundActive: running,
      recentErrors: _logs.problemCount,
    );
    if (mounted) setState(() => _snapshot = snap);
  }

  Future<void> _toggleIntegrity(bool value) async {
    final profile = _profile;
    if (profile == null) return;
    final next = PersistedMonitorProfile(source: profile.source, settings: profile.settings.copyWith(cameraIntegrityEnabled: value));
    await _settings.saveProfile(next);
    if (mounted) setState(() => _profile = next);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _snapshot == null || _profile == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final s = _snapshot!;
    final cameraState = switch (_runtime.cameraHealth) {
      CameraHealthState.ok => ('OK', const Color(0xFF4ADE80)),
      CameraHealthState.obstructed => ('OBSTRUÍDA', const Color(0xFFFFB74D)),
      CameraHealthState.moved => ('DESLOCADA', const Color(0xFFFFB74D)),
      CameraHealthState.offline => ('OFFLINE', Theme.of(context).colorScheme.error),
      CameraHealthState.unknown => (
        'SEM DADOS',
        Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Saúde do sistema'), actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded))]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          _HealthTile(icon: Icons.videocam_outlined, title: 'Câmera', value: '${s.source} · ${cameraState.$1}', valueColor: cameraState.$2),
          _HealthTile(icon: Icons.psychology_outlined, title: 'IA', value: s.aiReady ? 'Pronta' : 'Parada', valueColor: s.aiReady
              ? const Color(0xFF4ADE80)
              : Theme.of(context).colorScheme.onSurfaceVariant),
          _HealthTile(icon: Icons.speed_rounded, title: 'FPS de análise', value: s.fps <= 0 ? 'Sem amostra' : s.fps.toStringAsFixed(1)),
          _HealthTile(icon: Icons.battery_5_bar_outlined, title: 'Bateria', value: s.batteryPercent == null ? 'Indisponível' : '${s.batteryPercent}%'),
          _HealthTile(icon: Icons.device_thermostat_outlined, title: 'Temperatura da bateria', value: s.batteryTemperatureC == null ? 'Indisponível' : '${s.batteryTemperatureC!.toStringAsFixed(1)} °C'),
          _HealthTile(icon: Icons.memory_rounded, title: 'Memória do processo', value: s.memoryUsedMb == null ? 'Indisponível' : '${s.memoryUsedMb} MB'),
          _HealthTile(icon: Icons.storage_outlined, title: 'Armazenamento', value: s.freeStorageMb == null || s.totalStorageMb == null ? 'Indisponível' : '${s.freeStorageMb} MB livres de ${s.totalStorageMb} MB'),
          _HealthTile(icon: Icons.layers_outlined, title: 'Segundo plano', value: s.backgroundActive ? 'Serviço ativo' : 'Serviço parado', valueColor: s.backgroundActive
              ? const Color(0xFF4ADE80)
              : Theme.of(context).colorScheme.onSurfaceVariant),
          _HealthTile(icon: Icons.error_outline_rounded, title: 'Erros/avisos recentes', value: '${s.recentErrors} registro(s)', valueColor: s.recentErrors == 0 ? const Color(0xFF4ADE80) : const Color(0xFFFFB74D)),
          const SizedBox(height: 14),
          Card(
            child: SwitchListTile(
              value: _profile!.settings.cameraIntegrityEnabled,
              onChanged: _toggleIntegrity,
              secondary: const Icon(Icons.visibility_outlined),
              title: const Text('Detectar câmera obstruída ou deslocada', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('Compara brilho e enquadramento localmente e gera alerta específico quando houver mudança brusca.'),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Os dados deste painel são coletados localmente. Quando o Android não fornece uma métrica com segurança, o app mostra “Indisponível” em vez de estimar.'),
        ],
      ),
    );
  }
}

class _HealthTile extends StatelessWidget {
  const _HealthTile({required this.icon, required this.title, required this.value, this.valueColor});
  final IconData icon;
  final String title;
  final String value;
  final Color? valueColor;
  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Icon(icon),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          trailing: SizedBox(width: 170, child: Text(value, textAlign: TextAlign.end, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w900, color: valueColor))),
        ),
      );
}
