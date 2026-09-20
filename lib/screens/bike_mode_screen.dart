import 'dart:async';

import 'package:flutter/material.dart';

import '../models/bike_mode_config.dart';
import '../models/device_telemetry.dart';
import '../services/bike_mode_service.dart';
import '../services/native_platform_service.dart';
import '../utils/storage_size_formatter.dart';
import '../widgets/main_navigation_bar.dart';
import 'events_screen.dart';
import 'home_screen.dart';
import 'multi_camera_screen.dart';

part 'bike_mode_screen_components.dart';

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

  void _navigateMain(int index) {
    if (index == 4) return;
    final Widget target = switch (index) {
      0 => const HomeScreen(),
      1 => const EventsScreen(),
      2 => const HomeScreen(startMonitorOnLoad: true),
      3 => const MultiCameraScreen(),
      _ => const BikeModeScreen(),
    };
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => target),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hero = _BikeHero(
      enabled: _config.enabled,
      onChanged: (value) => _update(_config.copyWith(enabled: value)),
    );

    final powerCard = _SectionCard(
      title: 'Perfil de energia',
      subtitle:
          'O perfil limita de verdade a captura/análise e a transmissão durante o uso na bike.',
      child: Column(
        children: BikePowerProfile.values.map((profile) {
          final selected = _config.powerProfile == profile;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _update(_config.copyWith(powerProfile: profile)),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.label,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 3),
                          Text(profile.description),
                          const SizedBox(height: 6),
                          Text(
                            'IA: mínimo ${profile.targetAnalysisIntervalMs} ms entre análises · LAN: limite de ${profile.targetStreamFps} FPS',
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
        }).toList(growable: false),
      ),
    );

    final approachCard = _SectionCard(
      title: 'Alerta rápido de aproximação',
      subtitle:
          'Usa a câmera e a inferência principal para avisar antes das análises extras, histórico e gravação. Não depende do ESP32.',
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _config.approachAlertsEnabled,
            onChanged: (value) =>
                _update(_config.copyWith(approachAlertsEnabled: value)),
            secondary: const Icon(Icons.radar_rounded),
            title: const Text('Avisar veículo se aproximando'),
            subtitle: const Text(
              'Estima o tempo de aproximação pelo crescimento do veículo na imagem traseira.',
            ),
          ),
          if (_config.approachAlertsEnabled) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('2,5 s'),
                Expanded(
                  child: Slider(
                    value: _config.approachWarningTtcSeconds,
                    min: 2.5,
                    max: 7.0,
                    divisions: 9,
                    label:
                        '${_config.approachWarningTtcSeconds.toStringAsFixed(1)} s',
                    onChanged: (value) => setState(
                      () => _config = _config.copyWith(
                        approachWarningTtcSeconds: value,
                      ),
                    ),
                    onChangeEnd: (value) => _update(
                      _config.copyWith(approachWarningTtcSeconds: value),
                    ),
                  ),
                ),
                const Text('7 s'),
              ],
            ),
            Text(
              'Aviso forte quando o TTC visual cair para cerca de ${_config.approachWarningTtcSeconds.toStringAsFixed(1)} s. É uma estimativa por câmera; radar FMCW continua sendo um upgrade futuro.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );

    final rearPhoneCard = _SectionCard(
      title: 'Celular traseiro',
      subtitle:
          'Otimizações aplicadas enquanto o aparelho estiver monitorando ou transmitindo.',
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _config.dimRearScreen,
            onChanged: (value) =>
                _update(_config.copyWith(dimRearScreen: value)),
            secondary: const Icon(Icons.brightness_low_outlined),
            title: const Text('Reduzir brilho da tela'),
            subtitle: const Text(
              'Diminui o brilho somente dentro do Vigia IA; ao sair, o brilho do sistema é restaurado.',
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _config.keepRemoteTelemetry,
            onChanged: (value) =>
                _update(_config.copyWith(keepRemoteTelemetry: value)),
            secondary: const Icon(Icons.monitor_heart_outlined),
            title: const Text('Enviar condições do aparelho'),
            subtitle: const Text(
              'Disponibiliza bateria, carga, temperatura, brilho, CPU e memória junto à transmissão local.',
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _config.alertLowBattery,
            onChanged: (value) =>
                _update(_config.copyWith(alertLowBattery: value)),
            secondary: const Icon(Icons.battery_alert_outlined),
            title: const Text('Avisar bateria baixa'),
            subtitle: Text(
              'Avisa quando o celular traseiro chegar a ${_config.lowBatteryPercent}%.',
            ),
          ),
          if (_config.alertLowBattery)
            Row(
              children: [
                const SizedBox(width: 8),
                const Text('5%'),
                Expanded(
                  child: Slider(
                    value: _config.lowBatteryPercent.toDouble(),
                    min: 5,
                    max: 50,
                    divisions: 9,
                    label: '${_config.lowBatteryPercent}%',
                    onChanged: (value) => setState(
                      () => _config = _config.copyWith(
                        lowBatteryPercent: value.round(),
                      ),
                    ),
                    onChangeEnd: (value) => _update(
                      _config.copyWith(lowBatteryPercent: value.round()),
                    ),
                  ),
                ),
                const Text('50%'),
              ],
            ),
        ],
      ),
    );

    final simulationCard = _SectionCard(
      title: 'Teste do HUD sem ESP32',
      subtitle:
          'Gera dados falsos apenas para testar o painel transparente sobre o vídeo.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _config.sensorSimulationEnabled,
            onChanged: (value) =>
                _update(_config.copyWith(sensorSimulationEnabled: value)),
            secondary: const Icon(Icons.science_outlined),
            title: const Text('Simular sensores da bike'),
            subtitle: const Text(
              'Mostra velocidade, pneus, bateria e alertas no Monitor com a marca SIMULAÇÃO.',
            ),
          ),
          if (_config.sensorSimulationEnabled) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<BikeSimulationScenario>(
              initialValue: _config.simulationScenario,
              decoration: const InputDecoration(labelText: 'Cenário de teste'),
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
                _update(_config.copyWith(simulationScenario: scenario));
              },
            ),
            const SizedBox(height: 8),
            Text(
              _config.simulationScenario.description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => _navigateMain(2),
              icon: const Icon(Icons.play_circle_outline_rounded),
              label: const Text('Abrir Monitor e testar HUD'),
            ),
          ],
        ],
      ),
    );

    final telemetryCard = _TelemetryCard(
      telemetry: _telemetry,
      profile: _config.powerProfile,
      enabled: _config.enabled,
    );

    return AdaptiveMainScaffold(
      currentIndex: 4,
      onDestinationSelected: _navigateMain,
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
            : LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 760;
                  final left = <Widget>[
                    hero,
                    const SizedBox(height: 12),
                    powerCard,
                    const SizedBox(height: 12),
                    approachCard,
                    const SizedBox(height: 12),
                    telemetryCard,
                  ];
                  final right = <Widget>[
                    rearPhoneCard,
                    const SizedBox(height: 12),
                    simulationCard,
                    const SizedBox(height: 12),
                    const _RemotePanelReadyCard(),
                  ];
                  if (!wide) {
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                          children: [
                            ...left,
                            const SizedBox(height: 12),
                            ...right,
                          ],
                        ),
                      ),
                    );
                  }
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(18, 12, 9, 28),
                              children: left,
                            ),
                          ),
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(9, 12, 18, 28),
                              children: right,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

}
