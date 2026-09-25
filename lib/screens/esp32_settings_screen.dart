import 'dart:async';

import 'package:flutter/material.dart';

import '../models/audio_slot.dart';
import '../models/bike_mode_config.dart';
import '../models/esp32_capability_status.dart';
import '../models/esp32_module.dart';
import '../models/esp32_telemetry.dart';
import '../services/app_settings_service.dart';
import '../services/bike_mode_service.dart';
import '../services/esp32_module_service.dart';
import '../services/esp32_telemetry_service.dart';
import '../services/native_platform_service.dart';
import 'esp32_setup_wizard.dart';

class Esp32SettingsScreen extends StatefulWidget {
  const Esp32SettingsScreen({super.key});

  @override
  State<Esp32SettingsScreen> createState() => _Esp32SettingsScreenState();
}

class _Esp32SettingsScreenState extends State<Esp32SettingsScreen> {
  final Esp32ModuleService _registry = Esp32ModuleService.instance;
  final Esp32TelemetryService _telemetry = Esp32TelemetryService.instance;
  final Map<String, Esp32ProbeResult> _statuses = <String, Esp32ProbeResult>{};
  bool _loading = true;
  String? _busyId;

  List<Esp32Module> get _devices => _registry.modules;

  @override
  void initState() {
    super.initState();
    _telemetry.addListener(_onTelemetryChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    _telemetry.removeListener(_onTelemetryChanged);
    super.dispose();
  }

  void _onTelemetryChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    await _registry.initialize();
    await _telemetry.initialize();
    if (!mounted) return;
    setState(() => _loading = false);
    await _refreshAll();
  }

  Future<void> _openTools() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.science_outlined),
                title: const Text(
                  'Emulador de sensores',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text(
                  'Teste Hall, pneus, bateria e alertas sem um ESP32 físico.',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(sheetContext, 'emulator'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || selected == null) return;
    if (selected == 'emulator') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const _Esp32SensorEmulatorScreen(),
        ),
      );
    }
  }

  Future<void> _refreshAll() async {
    final devices = _devices;
    if (devices.isEmpty) return;
    final resultsFuture = _registry.probeAll(devices);
    final telemetryFuture = _telemetry.refreshNow();
    final results = await resultsFuture;
    await telemetryFuture;
    if (mounted) setState(() => _statuses.addAll(results));
  }

  Future<void> _edit([Esp32Module? existing]) async {
    final module = await Navigator.of(context).push<Esp32Module>(
      MaterialPageRoute<Esp32Module>(
        fullscreenDialog: true,
        builder: (_) => Esp32SetupWizard(existing: existing),
      ),
    );
    if (module == null || !mounted) return;

    setState(() => _busyId = module.id);
    await _registry.save(module);
    final probe = await _registry.probe(module);
    Esp32ProbeResult? applied;
    if (probe.online && module.enabled) {
      applied = await _registry.applyConfiguration(module);
    }
    if (!mounted) return;
    setState(() {
      _statuses[module.id] = probe;
      _busyId = null;
    });

    final message = !probe.online
        ? '${module.name} foi salvo. ${probe.message ?? 'O módulo ainda não respondeu.'}'
        : applied?.online == true
            ? '${module.name} conectado e configurado.'
            : '${module.name} conectado. ${applied?.message ?? 'Configuração salva no Vigia IA.'}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _apply(Esp32Module module) async {
    setState(() => _busyId = module.id);
    final result = await _registry.applyConfiguration(module);
    if (!mounted) return;
    setState(() {
      _statuses[module.id] = result;
      _busyId = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message ?? 'Configuração concluída.')),
    );
  }

  Future<void> _delete(Esp32Module module) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remover ${module.name}?'),
        content: const Text(
          'O cadastro e a chave local serão removidos. O firmware do ESP32 não será apagado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _registry.delete(module.id);
    if (mounted) setState(() => _statuses.remove(module.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ESP32'),
            Text('Módulos e capacidades', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _openTools,
            tooltip: 'Ferramentas do ESP32',
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            onPressed: _loading ? null : () => unawaited(_refreshAll()),
            tooltip: 'Testar conexões',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: !_loading && _devices.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => unawaited(_edit()),
              icon: const Icon(Icons.add_link_rounded),
              label: const Text('Adicionar ESP32'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _devices.isEmpty
              ? _EmptyEsp32(onAdd: () => unawaited(_edit()))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 96),
                  children: [
                    const _Esp32Intro(),
                    const SizedBox(height: 12),
                    ..._devices.map(
                      (device) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _Esp32Card(
                          device: device,
                          status: _statuses[device.id],
                          runtime: _telemetry.stateFor(device.id),
                          busy: _busyId == device.id,
                          onEdit: () => unawaited(_edit(device)),
                          onApply: () => unawaited(_apply(device)),
                          onDelete: () => unawaited(_delete(device)),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _Esp32Intro extends StatelessWidget {
  const _Esp32Intro();

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.hub_outlined, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'A tela separa o que foi configurado, o que o firmware detectou e o que está enviando leitura agora. Sensores novos reportados pelo ESP32 aparecem para revisão no assistente.',
                ),
              ),
            ],
          ),
        ),
      );
}

class _Esp32Card extends StatelessWidget {
  const _Esp32Card({
    required this.device,
    required this.status,
    required this.runtime,
    required this.busy,
    required this.onEdit,
    required this.onApply,
    required this.onDelete,
  });

  final Esp32Module device;
  final Esp32ProbeResult? status;
  final Esp32RuntimeState? runtime;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onApply;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final runtimeState = runtime;
    final packet = runtimeState?.packet;
    final telemetryOnline =
        runtimeState?.connectionState == Esp32ConnectionState.online;
    final online = telemetryOnline || status?.online == true;
    final latency = runtimeState?.latency ?? status?.latency;
    final runtimeError = runtimeState?.error;
    final lastSuccessAt = runtimeState?.lastSuccessAt;
    final firmware = packet?.firmwareVersion ?? status?.firmwareVersion;
    final protocol = packet?.protocolVersion ?? status?.protocolVersion;
    final energy = packet?.energy;
    final observations = buildEsp32CapabilityObservations(device, runtimeState);
    final energyPercent = energy?.batteryPercent;
    final energyAlert = energyPercent == null
        ? null
        : energyPercent <= device.criticalBatteryPercent
            ? 'Bateria principal crítica'
            : energyPercent <= device.lowBatteryPercent
                ? 'Bateria principal baixa'
                : null;
    final stateColor = switch (runtimeState?.connectionState) {
      Esp32ConnectionState.online => const Color(0xFF4ADE80),
      Esp32ConnectionState.connecting || Esp32ConnectionState.degraded =>
        const Color(0xFFFBBF24),
      _ => Theme.of(context).colorScheme.outline,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Icon(
                    device.cameraEnabled
                        ? Icons.camera_alt_outlined
                        : Icons.memory_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        runtimeState != null
                            ? '${runtimeState.connectionState.label}${latency == null ? '' : ' · ${latency.inMilliseconds} ms'}'
                            : online
                                ? 'Online${latency == null ? '' : ' · ${latency.inMilliseconds} ms'}'
                                : status?.message ?? 'Ainda não testado',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (runtimeError != null && !telemetryOnline)
                        Text(
                          runtimeError,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (firmware != null || protocol != null)
                        Text(
                          '${firmware == null ? '' : 'Firmware $firmware'}${firmware != null && protocol != null ? ' · ' : ''}${protocol == null ? '' : 'Protocolo v$protocol'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                Icon(
                  telemetryOnline
                      ? Icons.sensors_rounded
                      : online
                          ? Icons.check_circle_rounded
                          : Icons.error_outline_rounded,
                  color: telemetryOnline ? stateColor : online ? const Color(0xFF4ADE80) : stateColor,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${device.positionLabel} · ${device.address ?? ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            _Esp32CapabilityPanel(
              observations: observations,
              onConfigure: onEdit,
            ),
            const SizedBox(height: 8),
            Text(
              'Telemetria: ${device.telemetryIntervalMs} ms · offline após ${(device.staleAfter.inMilliseconds / 1000).toStringAsFixed(0)} s sem dados',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (device.energyMonitoringEnabled)
              Text(
                'Energia configurada: ${device.energyProfileLabel} · ${device.powerMonitorType.label}${device.monitorSolarInput ? ' · solar' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (energyAlert != null)
              Text(
                energyAlert,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            if (runtimeState != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Conexão',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '${runtimeState.connectionState.label}${runtimeState.endpointPath == null ? '' : ' · ${runtimeState.endpointPath}'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (lastSuccessAt != null)
                      Text(
                        'Última leitura: ${lastSuccessAt.hour.toString().padLeft(2, '0')}:${lastSuccessAt.minute.toString().padLeft(2, '0')}:${lastSuccessAt.second.toString().padLeft(2, '0')}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (runtimeState.consecutiveFailures > 0)
                      Text(
                        'Reconexão automática · tentativa ${runtimeState.consecutiveFailures}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (packet != null) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          if (packet.rssiDbm != null)
                            Chip(
                              avatar: const Icon(Icons.wifi_rounded, size: 16),
                              label: Text(
                                '${packet.wifiQualityLabel} · ${packet.rssiDbm} dBm',
                              ),
                            ),
                          if (packet.sequence != null)
                            Chip(label: Text('Seq. ${packet.sequence}')),
                          if (packet.uptime != null)
                            Chip(
                              label: Text(
                                'Ligado há ${_compactDuration(packet.uptime!)}',
                              ),
                            ),
                        ],
                      ),
                      if (energy != null &&
                          (energy.sourceType != null ||
                              energy.monitorType != null ||
                              energy.batteryChemistry != null)) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Energia reportada: ${[
                            energy.sourceType,
                            energy.batteryChemistry,
                            energy.monitorType,
                          ].whereType<String>().map(_energyValueLabel).join(' · ')}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: busy ? null : onApply,
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_rounded),
                  label: const Text('Aplicar no módulo'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : onEdit,
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Configurar'),
                ),
                TextButton.icon(
                  onPressed: busy ? null : onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Remover'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _energyValueLabel(String raw) => switch (raw) {
        'usbPowerBank' => 'Power bank USB',
        'usbAdapter' => 'Tomada / fonte USB',
        'systemBattery' => 'Bateria do sistema',
        'leadAcid' => 'Chumbo-ácido',
        'lifepo4' => 'LiFePO₄',
        'ina219' => 'INA219',
        'INA219' => 'INA219',
        'ina226' => 'INA226',
        'INA226' => 'INA226',
        'voltageDivider' => 'Divisor de tensão',
        'smartBms' => 'BMS',
        _ => raw,
      };
}


class _Esp32CapabilityPanel extends StatelessWidget {
  const _Esp32CapabilityPanel({
    required this.observations,
    required this.onConfigure,
  });

  final List<Esp32CapabilityObservation> observations;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final live = observations
        .where((item) => item.activity == Esp32CapabilityActivity.live)
        .length;
    final detected = observations
        .where((item) => item.activity == Esp32CapabilityActivity.detected)
        .length;
    final waiting = observations
        .where((item) => item.activity == Esp32CapabilityActivity.waiting)
        .length;
    final discovered = observations
        .where((item) => item.activity == Esp32CapabilityActivity.discovered)
        .length;
    final offline = observations
        .where((item) => item.activity == Esp32CapabilityActivity.offline)
        .length;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.sensors_rounded, size: 19, color: scheme.primary),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'Sensores e recursos',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            _capabilitySummary(
              live: live,
              detected: detected,
              waiting: waiting,
              discovered: discovered,
              offline: offline,
              total: observations.length,
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (observations.isEmpty) ...[
            const SizedBox(height: 10),
            const Text('Nenhum sensor ou recurso configurado.'),
          ] else ...[
            const SizedBox(height: 8),
            for (var i = 0; i < observations.length; i++) ...[
              if (i > 0) Divider(height: 13, color: scheme.outlineVariant),
              _Esp32CapabilityRow(observation: observations[i]),
            ],
          ],
          if (discovered > 0) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onConfigure,
              icon: const Icon(Icons.add_task_rounded),
              label: Text(
                discovered == 1
                    ? 'Revisar sensor detectado'
                    : 'Revisar sensores detectados ($discovered)',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Esp32CapabilityRow extends StatelessWidget {
  const _Esp32CapabilityRow({required this.observation});

  final Esp32CapabilityObservation observation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = _capabilityStatusColor(scheme, observation.activity);
    final value = observation.valueLabel;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(
            _capabilityIcon(observation.capability),
            size: 19,
            color: statusColor,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    observation.capability.label,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  _Esp32StatusBadge(
                    label: observation.activity.label,
                    color: statusColor,
                  ),
                ],
              ),
              if (value != null) ...[
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ] else if (observation.activity ==
                  Esp32CapabilityActivity.detected) ...[
                const SizedBox(height: 2),
                Text(
                  'O firmware anunciou este recurso; aguardando valor de telemetria.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ] else if (observation.activity ==
                  Esp32CapabilityActivity.discovered) ...[
                const SizedBox(height: 2),
                Text(
                  'O módulo informou este recurso, mas ele ainda não está ativado no cadastro.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Esp32StatusBadge extends StatelessWidget {
  const _Esp32StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.36)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}

String _capabilitySummary({
  required int live,
  required int detected,
  required int waiting,
  required int discovered,
  required int offline,
  required int total,
}) {
  if (total == 0) return 'Nada configurado neste módulo.';
  final parts = <String>[];
  if (live > 0) parts.add('$live lendo agora');
  if (detected > 0) parts.add('$detected detectado${detected == 1 ? '' : 's'}');
  if (waiting > 0) parts.add('$waiting aguardando');
  if (offline > 0) parts.add('$offline offline');
  if (discovered > 0) parts.add('$discovered novo${discovered == 1 ? '' : 's'}');
  return parts.isEmpty ? '$total configurado${total == 1 ? '' : 's'}' : parts.join(' · ');
}

Color _capabilityStatusColor(
  ColorScheme scheme,
  Esp32CapabilityActivity activity,
) =>
    switch (activity) {
      Esp32CapabilityActivity.live => const Color(0xFF22C55E),
      Esp32CapabilityActivity.detected => scheme.primary,
      Esp32CapabilityActivity.waiting => const Color(0xFFF59E0B),
      Esp32CapabilityActivity.offline => scheme.outline,
      Esp32CapabilityActivity.discovered => scheme.secondary,
    };

IconData _capabilityIcon(Esp32Capability capability) => switch (capability) {
      Esp32Capability.camera => Icons.videocam_outlined,
      Esp32Capability.temperature => Icons.thermostat_rounded,
      Esp32Capability.hallSpeed => Icons.speed_rounded,
      Esp32Capability.tirePressure => Icons.circle_outlined,
      Esp32Capability.battery => Icons.battery_std_rounded,
      Esp32Capability.energy => Icons.electrical_services_rounded,
      Esp32Capability.mmWave => Icons.radar_rounded,
      Esp32Capability.thermal => Icons.device_thermostat_rounded,
      Esp32Capability.tof => Icons.straighten_rounded,
      Esp32Capability.ultrasonic => Icons.sensors_rounded,
      Esp32Capability.ambient => Icons.air_rounded,
      Esp32Capability.gps => Icons.gps_fixed_rounded,
      Esp32Capability.light => Icons.light_mode_outlined,
      Esp32Capability.actuator => Icons.settings_remote_rounded,
    };

String _compactDuration(Duration duration) {
  if (duration.inDays > 0) return '${duration.inDays}d ${duration.inHours.remainder(24)}h';
  if (duration.inHours > 0) {
    return '${duration.inHours}h ${duration.inMinutes.remainder(60)}min';
  }
  if (duration.inMinutes > 0) {
    return '${duration.inMinutes}min ${duration.inSeconds.remainder(60)}s';
  }
  return '${duration.inSeconds}s';
}

class _EmptyEsp32 extends StatelessWidget {
  const _EmptyEsp32({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.hub_outlined,
                size: 54,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              const Text(
                'Nenhum ESP32 conectado',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'O assistente procura o módulo, identifica onde ele ficará e mostra apenas as configurações dos sensores selecionados.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_link_rounded),
                label: const Text('Configurar primeiro ESP32'),
              ),
            ],
          ),
        ),
      );
}

class _Esp32SensorEmulatorScreen extends StatefulWidget {
  const _Esp32SensorEmulatorScreen();

  @override
  State<_Esp32SensorEmulatorScreen> createState() =>
      _Esp32SensorEmulatorScreenState();
}

class _Esp32SensorEmulatorScreenState
    extends State<_Esp32SensorEmulatorScreen> {
  final BikeModeService _bikeMode = BikeModeService.instance;
  BikeModeConfig _config = const BikeModeConfig();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final config = await _bikeMode.initialize();
    if (!mounted) return;
    setState(() {
      _config = config;
      _loading = false;
    });
  }

  Future<void> _update(BikeModeConfig config) async {
    final previous = _config;
    setState(() {
      _config = config;
      _saving = true;
    });
    await _bikeMode.save(config);
    final shouldAnnounce = config.sensorSimulationEnabled &&
        (!previous.sensorSimulationEnabled ||
            previous.simulationScenario != config.simulationScenario);
    if (shouldAnnounce) {
      unawaited(_announceScenario(config.simulationScenario));
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _announceScenario(BikeSimulationScenario scenario) async {
    final profile = await AppSettingsService.instance.initialize();
    if (!profile.settings.alertOutputs.voice) return;
    final slot = switch (scenario) {
      BikeSimulationScenario.normal => 'bike_all_sensors_ok',
      BikeSimulationScenario.frontTireLow => 'bike_front_pressure_critical',
      BikeSimulationScenario.rearTireLow => 'bike_rear_pressure_critical',
      BikeSimulationScenario.sensorBatteryLow => 'bike_module_battery_low',
      BikeSimulationScenario.vehicleApproaching => AudioSlotIds.vehicleDetected,
      BikeSimulationScenario.disconnected => 'bike_sensor_disconnected',
    };
    if (!profile.settings.voiceAlertPreferences.allowsSlot(slot)) return;
    await NativePlatformService.instance.playCustomAlertAudio(slot, priority: 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Emulador ESP32', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('Teste sem hardware físico', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 18),
              child: Center(
                child: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _config.sensorSimulationEnabled,
                          onChanged: (value) => _update(
                            _config.copyWith(sensorSimulationEnabled: value),
                          ),
                          secondary: const Icon(Icons.science_outlined),
                          title: const Text(
                            'Simular sensores ESP32',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: const Text(
                            'Gera telemetria falsa identificada como SIMULAÇÃO. Não exige conexão com módulo real.',
                          ),
                        ),
                        if (_config.sensorSimulationEnabled) ...[
                          const SizedBox(height: 8),
                          DropdownButtonFormField<BikeSimulationScenario>(
                            initialValue: _config.simulationScenario,
                            decoration: const InputDecoration(
                              labelText: 'Cenário de teste',
                            ),
                            items: BikeSimulationScenario.values
                                .map(
                                  (scenario) => DropdownMenuItem(
                                    value: scenario,
                                    child: Text(scenario.label),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (scenario) {
                              if (scenario == null) return;
                              unawaited(
                                _update(
                                  _config.copyWith(
                                    simulationScenario: scenario,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _config.simulationScenario.description,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Depois de ativar o emulador, abra Ao vivo. O HUD usa o mesmo contrato de telemetria preparado para o ESP32 real.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
