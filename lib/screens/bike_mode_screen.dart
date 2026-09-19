import 'dart:async';

import 'package:flutter/material.dart';

import '../models/bike_mode_config.dart';
import '../services/bike_mode_service.dart';

class BikeModeScreen extends StatefulWidget {
  const BikeModeScreen({super.key});

  @override
  State<BikeModeScreen> createState() => _BikeModeScreenState();
}

class _BikeModeScreenState extends State<BikeModeScreen> {
  final BikeModeService _service = BikeModeService.instance;
  BikeModeConfig _config = const BikeModeConfig();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final config = await _service.initialize();
    if (!mounted) return;
    setState(() {
      _config = config;
      _loading = false;
    });
  }

  Future<void> _update(BikeModeConfig next) async {
    setState(() {
      _config = next;
      _saving = true;
    });
    await _service.save(next);
    if (!mounted) return;
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Modo Bike', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('Câmera traseira com foco em autonomia', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 18),
              child: Center(child: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))),
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
                        onChanged: (value) => _update(_config.copyWith(enabled: value)),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'Perfil de energia',
                        subtitle: 'O perfil escolhido será a base das otimizações da câmera traseira.',
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
                                        selected ? Icons.radio_button_checked : Icons.radio_button_off,
                                        color: selected ? Theme.of(context).colorScheme.primary : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(profile.label, style: const TextStyle(fontWeight: FontWeight.w900)),
                                            const SizedBox(height: 3),
                                            Text(profile.description),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Meta: IA ~${profile.targetAnalysisIntervalMs} ms · transmissão até ${profile.targetStreamFps} FPS',
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
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'Celular traseiro',
                        subtitle: 'Preferências que serão usadas pelo modo de economia.',
                        child: Column(
                          children: [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _config.dimRearScreen,
                              onChanged: (value) => _update(_config.copyWith(dimRearScreen: value)),
                              secondary: const Icon(Icons.brightness_low_outlined),
                              title: const Text('Reduzir atividade da tela'),
                              subtitle: const Text('Prepara o aparelho traseiro para trabalhar com a tela no mínimo necessário.'),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _config.keepRemoteTelemetry,
                              onChanged: (value) => _update(_config.copyWith(keepRemoteTelemetry: value)),
                              secondary: const Icon(Icons.monitor_heart_outlined),
                              title: const Text('Enviar condições do aparelho'),
                              subtitle: const Text('Reserva telemetria para bateria, temperatura, memória, IA e conexão no painel remoto.'),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _config.alertLowBattery,
                              onChanged: (value) => _update(_config.copyWith(alertLowBattery: value)),
                              secondary: const Icon(Icons.battery_alert_outlined),
                              title: const Text('Avisar bateria baixa'),
                              subtitle: Text('Alerta planejado quando chegar a ${_config.lowBatteryPercent}%.'),
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
                                        () => _config = _config.copyWith(lowBatteryPercent: value.round()),
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
                      ),
                      const SizedBox(height: 12),
                      const _NextStageCard(),
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
            decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(15)),
            child: Icon(Icons.directions_bike_rounded, color: scheme.primary),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Usar este aparelho na bike', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text('Ative no celular que ficará na traseira. O Vigia IA usará este perfil como referência para economizar energia.'),
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.subtitle, required this.child});

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
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(subtitle),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      );
}

class _NextStageCard extends StatelessWidget {
  const _NextStageCard();

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
                    const Text('Próxima etapa', style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(
                      'Aplicar estes perfis ao pipeline real de câmera/IA e coletar a telemetria do aparelho traseiro.',
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
