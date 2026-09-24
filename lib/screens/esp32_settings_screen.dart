import 'dart:async';

import 'package:flutter/material.dart';

import '../models/audio_slot.dart';
import '../models/camera_endpoint.dart';
import '../models/bike_mode_config.dart';
import '../services/app_settings_service.dart';
import '../services/camera_registry_service.dart';
import '../services/bike_mode_service.dart';
import '../services/native_platform_service.dart';

class Esp32SettingsScreen extends StatefulWidget {
  const Esp32SettingsScreen({super.key});

  @override
  State<Esp32SettingsScreen> createState() => _Esp32SettingsScreenState();
}

class _Esp32SettingsScreenState extends State<Esp32SettingsScreen> {
  final CameraRegistryService _registry = CameraRegistryService.instance;
  final Map<String, CameraProbeResult> _statuses = <String, CameraProbeResult>{};
  bool _loading = true;
  String? _busyId;

  List<CameraEndpoint> get _devices => _registry.items
      .where((item) => item.type == CameraEndpointType.esp32)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    await _registry.initialize();
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
    final results = await _registry.probeAll(devices);
    if (mounted) setState(() => _statuses.addAll(results));
  }

  Future<void> _edit([CameraEndpoint? existing]) async {
    final endpoint = await _showEditor(existing);
    if (endpoint == null) return;
    await _registry.save(endpoint);
    if (!mounted) return;
    setState(() => _busyId = endpoint.id);
    final probe = await _registry.probe(endpoint);
    if (!mounted) return;
    setState(() {
      _statuses[endpoint.id] = probe;
      _busyId = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          probe.online
              ? '${endpoint.name} salvo e conectado.'
              : '${endpoint.name} foi salvo. ${probe.message ?? 'O módulo ainda não respondeu.'}',
        ),
      ),
    );
  }

  Future<CameraEndpoint?> _showEditor(CameraEndpoint? existing) async {
    final name = TextEditingController(text: existing?.name ?? 'ESP32 Bike');
    final address = TextEditingController(
      text: existing?.address ?? 'http://192.168.4.1',
    );
    final key = TextEditingController(text: existing?.accessKey ?? '');
    final circumference = TextEditingController(
      text: (existing?.wheelCircumferenceMm ?? 2100).toStringAsFixed(0),
    );
    final magnets = TextEditingController(
      text: (existing?.hallMagnets ?? 1).toString(),
    );
    final pressure = TextEditingController(
      text: (existing?.minimumTirePressurePsi ?? 30).toStringAsFixed(1),
    );
    final temperature = TextEditingController(
      text: (existing?.maximumTemperatureC ?? 65).toStringAsFixed(1),
    );
    var enabled = existing?.enabled ?? true;
    var camera = existing?.esp32CameraEnabled ?? false;
    var temperatureSensor = existing?.temperatureSensorEnabled ?? true;
    var hall = existing?.hallSensorEnabled ?? true;
    var tires = existing?.tirePressureEnabled ?? true;
    var interval = existing?.telemetryIntervalMs ?? 1000;
    String? error;

    final result = await showDialog<CameraEndpoint>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Conectar ESP32' : 'Configurar ESP32'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Informe o endereço HTTP do módulo na rede local. A chave é opcional, mas recomendada.',
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Nome do módulo',
                      prefixIcon: Icon(Icons.memory_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: address,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Endereço local',
                      hintText: 'http://192.168.4.1',
                      prefixIcon: Icon(Icons.wifi_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: key,
                    autocorrect: false,
                    enableSuggestions: false,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Chave do módulo (opcional)',
                      prefixIcon: Icon(Icons.key_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: enabled,
                    onChanged: (value) => setDialogState(() => enabled = value),
                    title: const Text('Módulo ativo'),
                    subtitle: const Text('Recebe telemetria de sensores deste ESP32.'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: camera,
                    onChanged: (value) => setDialogState(() => camera = value),
                    title: const Text('Câmera ESP32 instalada'),
                    subtitle: const Text(
                      'Exibe o módulo como fonte de vídeo no Monitor e na página Câmeras.',
                    ),
                  ),
                  const Divider(height: 24),
                  const Text(
                    'Sensores',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: temperatureSensor,
                    onChanged: (value) =>
                        setDialogState(() => temperatureSensor = value),
                    title: const Text('Temperatura'),
                  ),
                  if (temperatureSensor)
                    TextField(
                      controller: temperature,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Alerta máximo (°C)',
                      ),
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: hall,
                    onChanged: (value) => setDialogState(() => hall = value),
                    title: const Text('Velocidade por sensor Hall'),
                  ),
                  if (hall)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: circumference,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Roda (mm)',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: magnets,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Ímãs',
                            ),
                          ),
                        ),
                      ],
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: tires,
                    onChanged: (value) => setDialogState(() => tires = value),
                    title: const Text('Pressão dos pneus'),
                  ),
                  if (tires)
                    TextField(
                      controller: pressure,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Alerta mínimo (PSI)',
                      ),
                    ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: interval,
                    decoration: const InputDecoration(
                      labelText: 'Intervalo da telemetria',
                    ),
                    items: const [
                      DropdownMenuItem(value: 500, child: Text('0,5 segundo')),
                      DropdownMenuItem(value: 1000, child: Text('1 segundo')),
                      DropdownMenuItem(value: 2000, child: Text('2 segundos')),
                      DropdownMenuItem(value: 5000, child: Text('5 segundos')),
                    ],
                    onChanged: (value) {
                      if (value != null) setDialogState(() => interval = value);
                    },
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () {
                final uri = Uri.tryParse(address.text.trim());
                final wheel = double.tryParse(circumference.text.replaceAll(',', '.'));
                final magnetCount = int.tryParse(magnets.text);
                final minimumPressure =
                    double.tryParse(pressure.text.replaceAll(',', '.'));
                final maximumTemperature =
                    double.tryParse(temperature.text.replaceAll(',', '.'));
                if (uri == null ||
                    !(uri.scheme == 'http' || uri.scheme == 'https') ||
                    uri.host.isEmpty ||
                    wheel == null || wheel < 500 || wheel > 4000 ||
                    magnetCount == null || magnetCount < 1 || magnetCount > 32 ||
                    minimumPressure == null || minimumPressure < 1 ||
                    maximumTemperature == null || maximumTemperature < 1) {
                  setDialogState(() {
                    error = 'Revise endereço, roda (500–4000 mm), ímãs (1–32) e limites.';
                  });
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  CameraEndpoint(
                    id: existing?.id ??
                        'esp32_${DateTime.now().microsecondsSinceEpoch}',
                    name: name.text.trim().isEmpty ? 'ESP32' : name.text.trim(),
                    type: CameraEndpointType.esp32,
                    address: address.text.trim(),
                    accessKey: key.text.trim().isEmpty ? null : key.text.trim(),
                    enabled: enabled,
                    esp32CameraEnabled: camera,
                    temperatureSensorEnabled: temperatureSensor,
                    hallSensorEnabled: hall,
                    tirePressureEnabled: tires,
                    wheelCircumferenceMm: wheel,
                    hallMagnets: magnetCount,
                    minimumTirePressurePsi: minimumPressure,
                    maximumTemperatureC: maximumTemperature,
                    telemetryIntervalMs: interval,
                  ),
                );
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Salvar e testar'),
            ),
          ],
        ),
      ),
    );

    for (final controller in <TextEditingController>[
      name,
      address,
      key,
      circumference,
      magnets,
      pressure,
      temperature,
    ]) {
      controller.dispose();
    }
    return result;
  }

  Future<void> _apply(CameraEndpoint endpoint) async {
    setState(() => _busyId = endpoint.id);
    final result = await _registry.applyEsp32Configuration(endpoint);
    if (!mounted) return;
    setState(() {
      _statuses[endpoint.id] = result;
      _busyId = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message ?? 'Configuração concluída.')),
    );
  }

  Future<void> _delete(CameraEndpoint endpoint) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remover ${endpoint.name}?'),
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
    await _registry.delete(endpoint.id);
    if (mounted) setState(() => _statuses.remove(endpoint.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ESP32'),
            Text('Módulo, sensores e câmera', style: TextStyle(fontSize: 12)),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : () => unawaited(_edit()),
        icon: const Icon(Icons.add_link_rounded),
        label: const Text('Conectar ESP32'),
      ),
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
              Icon(Icons.memory_rounded, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'O ESP32 envia velocidade Hall, temperatura, pressão dos pneus e bateria. Se uma câmera estiver instalada, ele também aparece como fonte; a IA continua sendo processada neste celular.',
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
    required this.busy,
    required this.onEdit,
    required this.onApply,
    required this.onDelete,
  });

  final CameraEndpoint device;
  final CameraProbeResult? status;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onApply;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final online = status?.online == true;
    final latency = status?.latency;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(child: Icon(device.esp32CameraEnabled
                    ? Icons.camera_alt_outlined
                    : Icons.memory_rounded)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(device.name,
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                      Text(
                        online
                            ? 'Online${latency == null ? '' : ' · ${latency.inMilliseconds} ms'}'
                            : status?.message ?? 'Ainda não testado',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(
                  online ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                  color: online ? const Color(0xFF4ADE80) : Theme.of(context).colorScheme.outline,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(device.address ?? '', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                if (device.hallSensorEnabled) const Chip(label: Text('Hall')),
                if (device.temperatureSensorEnabled) const Chip(label: Text('Temperatura')),
                if (device.tirePressureEnabled) const Chip(label: Text('Pneus')),
                Chip(label: Text(device.esp32CameraEnabled ? 'Câmera ativa' : 'Sem câmera')),
              ],
            ),
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
              Icon(Icons.memory_rounded,
                  size: 54, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              const Text(
                'Nenhum ESP32 conectado',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'Cadastre o endereço do módulo para receber sensores e preparar a futura câmera.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_link_rounded),
                label: const Text('Conectar ESP32'),
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
