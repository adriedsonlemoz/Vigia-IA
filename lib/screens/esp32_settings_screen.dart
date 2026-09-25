import 'dart:async';

import 'package:flutter/material.dart';

import '../models/audio_slot.dart';
import '../models/bike_mode_config.dart';
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
                  'Cada ESP32 agora é um módulo independente. Ele pode ter sensores, câmera ou futuras capacidades como mmWave, térmico e ToF; só módulos com câmera aparecem como fonte de vídeo.',
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
    final bike = packet?.bikePayload;
    final speed = bike?['speedKmh'] as num?;
    final frontPsi = bike?['frontTirePsi'] as num?;
    final rearPsi = bike?['rearTirePsi'] as num?;
    final temperature = bike?['temperatureC'] as num?;
    final energy = packet?.energy;
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
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                ...device.capabilities.map(
                  (capability) => Chip(label: Text(capability.label)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Telemetria: ${device.telemetryIntervalMs} ms · offline após ${(device.staleAfter.inMilliseconds / 1000).toStringAsFixed(0)} s sem dados',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (device.energyMonitoringEnabled)
              Text(
                'Energia: ${device.energyProfileLabel} · ${device.powerMonitorType.label}${device.monitorSolarInput ? ' · solar' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
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
                    Text(
                      '${runtimeState.connectionState.label}${runtimeState.endpointPath == null ? '' : ' · ${runtimeState.endpointPath}'}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
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
                              label: Text('${packet.wifiQualityLabel} · ${packet.rssiDbm} dBm'),
                            ),
                          if (packet.batteryPercent != null)
                            Chip(
                              avatar: const Icon(
                                Icons.battery_std_rounded,
                                size: 16,
                              ),
                              label: Text('Módulo ${packet.batteryPercent}%'),
                            ),
                          if (packet.batteryVoltage != null)
                            Chip(
                              label: Text(
                                'Módulo ${packet.batteryVoltage!.toStringAsFixed(2)} V',
                              ),
                            ),
                          if (packet.charging == true)
                            const Chip(label: Text('Alimentação externa')),
                          if (energy?.batteryPercent != null)
                            Chip(
                              avatar: const Icon(Icons.battery_charging_full_rounded, size: 16),
                              label: Text('Bateria ${energy!.batteryPercent}%'),
                            ),
                          if (energyAlert != null)
                            Chip(
                              avatar: const Icon(Icons.warning_amber_rounded, size: 16),
                              label: Text(energyAlert),
                            ),
                          if (energy?.voltageV != null)
                            Chip(
                              label: Text(
                                '${energy!.voltageV!.toStringAsFixed(2)} V',
                              ),
                            ),
                          if (energy?.charging == true)
                            const Chip(label: Text('Bateria carregando')),
                          if (energy?.currentA != null)
                            Chip(
                              label: Text(
                                '${energy!.currentA!.toStringAsFixed(2)} A',
                              ),
                            ),
                          if (energy?.powerW != null)
                            Chip(
                              label: Text(
                                '${energy!.powerW!.toStringAsFixed(1)} W',
                              ),
                            ),
                          if (energy?.solarPowerW != null)
                            Chip(
                              avatar: const Icon(Icons.light_mode_outlined, size: 16),
                              label: Text(
                                'Solar ${energy!.solarPowerW!.toStringAsFixed(1)} W',
                              ),
                            ),
                          if (energy?.energyInWh != null)
                            Chip(
                              label: Text(
                                'Entrada ${energy!.energyInWh!.toStringAsFixed(1)} Wh',
                              ),
                            ),
                          if (energy?.energyOutWh != null)
                            Chip(
                              label: Text(
                                'Saída ${energy!.energyOutWh!.toStringAsFixed(1)} Wh',
                              ),
                            ),
                          if (energy?.batteryTemperatureC != null)
                            Chip(
                              label: Text(
                                'Bat. ${energy!.batteryTemperatureC!.toStringAsFixed(1)} °C',
                              ),
                            ),
                          if (speed != null)
                            Chip(label: Text('${speed.toStringAsFixed(1)} km/h')),
                          if (frontPsi != null)
                            Chip(label: Text('D ${frontPsi.toStringAsFixed(0)} PSI')),
                          if (rearPsi != null)
                            Chip(label: Text('T ${rearPsi.toStringAsFixed(0)} PSI')),
                          if (temperature != null)
                            Chip(
                              label: Text(
                                '${temperature.toStringAsFixed(1)} °C',
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
                      if (packet.reportedCapabilities.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Reportado pelo módulo: ${packet.reportedCapabilities.map((item) => item.label).join(', ')}',
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
