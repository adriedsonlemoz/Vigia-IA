import 'dart:async';

import 'package:flutter/material.dart';

import '../models/bike_mode_config.dart';
import '../models/device_telemetry.dart';
import '../services/bike_mode_service.dart';
import '../services/native_platform_service.dart';
import '../utils/storage_size_formatter.dart';

class BikeModeScreen extends StatefulWidget {
  const BikeModeScreen({super.key});

  @override
  State<BikeModeScreen> createState() => _BikeModeScreenState();
}

class _BikeModeScreenState extends State<BikeModeScreen> {
  final BikeModeService _service = BikeModeService.instance;
  final NativePlatformService _native = NativePlatformService.instance;
  BikeModeConfig _config = const BikeModeConfig();
  DeviceTelemetrySnapshot? _telemetry;
  Timer? _telemetryTimer;
  bool _loading = true;
  bool _saving = false;
  bool _readingTelemetry = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _telemetryTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => unawaited(_refreshTelemetry()),
    );
  }

  @override
  void dispose() {
    _telemetryTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final config = await _service.initialize();
    if (!mounted) return;
    setState(() {
      _config = config;
      _loading = false;
    });
    unawaited(_refreshTelemetry());
  }

  Future<void> _refreshTelemetry() async {
    if (_readingTelemetry) return;
    _readingTelemetry = true;
    try {
      final telemetry = await _native.readDeviceTelemetry();
      if (mounted) setState(() => _telemetry = telemetry);
    } finally {
      _readingTelemetry = false;
    }
  }

  Future<void> _update(BikeModeConfig next) async {
    setState(() {
      _config = next;
      _saving = true;
    });
    await _service.save(next);
    if (!mounted) return;
    setState(() => _saving = false);
    unawaited(_refreshTelemetry());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Modo Bike', style: TextStyle(fontWeight: FontWeight.w800)),
            Text(
              'Câmera traseira com foco em autonomia',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Atualizar condições',
            onPressed: _readingTelemetry ? null : _refreshTelemetry,
            icon: const Icon(Icons.refresh_rounded),
          ),
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
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    children: [
                      _BikeHero(
                        enabled: _config.enabled,
                        onChanged: (value) =>
                            _update(_config.copyWith(enabled: value)),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'Perfil de energia',
                        subtitle:
                            'Agora o perfil limita de verdade a captura/análise e a transmissão durante o uso na bike.',
                        child: Column(
                          children: BikePowerProfile.values.map((profile) {
                            final selected = _config.powerProfile == profile;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _update(
                                  _config.copyWith(powerProfile: profile),
                                ),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: selected
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context)
                                              .colorScheme
                                              .outlineVariant,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        selected
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_off,
                                        color: selected
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              profile.label,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(profile.description),
                                            const SizedBox(height: 6),
                                            Text(
                                              'IA: mínimo ${profile.targetAnalysisIntervalMs} ms entre análises · LAN: limite de ${profile.targetStreamFps} FPS',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(growable: false),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'Celular traseiro',
                        subtitle:
                            'As otimizações abaixo são aplicadas enquanto o aparelho estiver monitorando ou transmitindo.',
                        child: Column(
                          children: [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _config.dimRearScreen,
                              onChanged: (value) => _update(
                                _config.copyWith(dimRearScreen: value),
                              ),
                              secondary:
                                  const Icon(Icons.brightness_low_outlined),
                              title: const Text('Reduzir brilho da tela'),
                              subtitle: const Text(
                                'Diminui o brilho somente dentro do Vigia IA durante a operação; ao sair, o brilho do sistema é restaurado.',
                              ),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _config.keepRemoteTelemetry,
                              onChanged: (value) => _update(
                                _config.copyWith(keepRemoteTelemetry: value),
                              ),
                              secondary:
                                  const Icon(Icons.monitor_heart_outlined),
                              title: const Text('Enviar condições do aparelho'),
                              subtitle: const Text(
                                'Disponibiliza bateria, carga, temperatura, brilho, CPU e memória junto ao estado da transmissão local.',
                              ),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _config.alertLowBattery,
                              onChanged: (value) => _update(
                                _config.copyWith(alertLowBattery: value),
                              ),
                              secondary:
                                  const Icon(Icons.battery_alert_outlined),
                              title: const Text('Avisar bateria baixa'),
                              subtitle: Text(
                                'Gera aviso quando o celular traseiro chegar a ${_config.lowBatteryPercent}%.',
                              ),
                            ),
                            if (_config.alertLowBattery)
                              Row(
                                children: [
                                  const SizedBox(width: 8),
                                  const Text('5%'),
                                  Expanded(
                                    child: Slider(
                                      value: _config.lowBatteryPercent
                                          .toDouble(),
                                      min: 5,
                                      max: 50,
                                      divisions: 9,
                                      label:
                                          '${_config.lowBatteryPercent}%',
                                      onChanged: (value) => setState(
                                        () => _config = _config.copyWith(
                                          lowBatteryPercent: value.round(),
                                        ),
                                      ),
                                      onChangeEnd: (value) => _update(
                                        _config.copyWith(
                                          lowBatteryPercent: value.round(),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Text('50%'),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _TelemetryCard(
                        telemetry: _telemetry,
                        profile: _config.powerProfile,
                        enabled: _config.enabled,
                      ),
                      const SizedBox(height: 12),
                      const _RemotePanelReadyCard(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _BikeHero extends StatelessWidget {
  const _BikeHero({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: scheme.primaryContainer.withValues(alpha: 0.45),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(Icons.directions_bike_rounded, color: scheme.primary),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Usar este aparelho na bike',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 4),
                Text(
                  'Ative no celular que ficará na traseira. O perfil passa a controlar consumo, tela e telemetria durante a operação.',
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(value: enabled, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _TelemetryCard extends StatelessWidget {
  const _TelemetryCard({
    required this.telemetry,
    required this.profile,
    required this.enabled,
  });

  final DeviceTelemetrySnapshot? telemetry;
  final BikePowerProfile profile;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final data = telemetry;
    String unavailable(Object? value, String Function() formatter) =>
        value == null ? 'Indisponível' : formatter();
    final battery = unavailable(
      data?.batteryPercent,
      () => '${data!.batteryPercent}%',
    );
    final charging = data?.batteryCharging == null
        ? null
        : data!.batteryCharging!
            ? '${data.batteryPowerSource ?? 'Carregando'}${data.batteryCurrentMa == null ? '' : ' · ${data.batteryCurrentMa!.toStringAsFixed(0)} mA'}'
            : 'Usando bateria';
    final memory = data?.appMemoryUsedBytes == null
        ? 'Indisponível'
        : StorageSizeFormatter.formatBytes(data!.appMemoryUsedBytes!);
    final deviceMemory = data?.memoryAvailableBytes == null ||
            data?.memoryTotalBytes == null
        ? null
        : '${StorageSizeFormatter.formatBytes(data!.memoryAvailableBytes!)} livres de ${StorageSizeFormatter.formatBytes(data.memoryTotalBytes!)}';

    return _SectionCard(
      title: 'Condições deste celular',
      subtitle: enabled
          ? 'Perfil ${profile.label} ativo. Estes dados já estão prontos para o painel do celular da frente.'
          : 'Telemetria local disponível para conferência; ative o Modo Bike para enviá-la durante a transmissão.',
      child: data == null
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              children: [
                _TelemetryTile(
                  icon: data.batteryCharging == true
                      ? Icons.battery_charging_full_rounded
                      : Icons.battery_5_bar_outlined,
                  title: 'Bateria',
                  value: battery,
                  subtitle: charging,
                ),
                _TelemetryTile(
                  icon: Icons.device_thermostat_outlined,
                  title: 'Temperatura da bateria',
                  value: data.batteryTemperatureC == null
                      ? 'Indisponível'
                      : '${data.batteryTemperatureC!.toStringAsFixed(1)} °C',
                ),
                _TelemetryTile(
                  icon: Icons.brightness_6_outlined,
                  title: 'Tela / brilho',
                  value: data.screenBrightnessPercent == null
                      ? 'Indisponível'
                      : '${data.screenBrightnessPercent}%',
                  subtitle: data.screenDimmedByBike
                      ? 'Brilho reduzido pelo Modo Bike'
                      : data.automaticBrightness == true
                          ? 'Brilho automático do Android'
                          : data.screenInteractive == false
                              ? 'Tela não interativa'
                              : 'Brilho atual do aparelho',
                ),
                _TelemetryTile(
                  icon: Icons.speed_rounded,
                  title: 'CPU do Vigia IA',
                  value: data.appCpuPercent == null
                      ? 'Calculando…'
                      : '${data.appCpuPercent!.toStringAsFixed(1)}%',
                  subtitle: data.processorCount == null
                      ? 'Uso do processo do aplicativo'
                      : 'Uso do processo · ${data.processorCount} núcleos disponíveis',
                ),
                _TelemetryTile(
                  icon: Icons.memory_rounded,
                  title: 'Memória',
                  value: memory,
                  subtitle: deviceMemory == null
                      ? 'Uso aproximado do processo'
                      : 'App · $deviceMemory no aparelho',
                ),
              ],
            ),
    );
  }
}

class _TelemetryTile extends StatelessWidget {
  const _TelemetryTile({
    required this.icon,
    required this.title,
    required this.value,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(subtitle),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      );
}

class _RemotePanelReadyCard extends StatelessWidget {
  const _RemotePanelReadyCard();

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.route_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Painel remoto disponível',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ao usar Outro celular como fonte, toque no ícone de bicicleta no monitor para acompanhar estas condições e os avisos do aparelho traseiro.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
