import 'dart:async';

import 'package:flutter/material.dart';

import '../models/monitoring_preset.dart';
import '../models/video_source_config.dart';
import '../services/app_settings_service.dart';
import '../services/monitoring_preset_service.dart';

class PresetsScreen extends StatefulWidget {
  const PresetsScreen({super.key});

  @override
  State<PresetsScreen> createState() => _PresetsScreenState();
}

class _PresetsScreenState extends State<PresetsScreen> {
  final _settings = AppSettingsService.instance;
  final _presets = const MonitoringPresetService();
  PersistedMonitorProfile? _profile;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final profile = await _settings.initialize();
    if (mounted) setState(() => _profile = profile);
  }

  Future<void> _apply(MonitoringPreset preset) async {
    final current = _profile;
    if (current == null) return;
    if (preset != MonitoringPreset.custom) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Aplicar ${preset.label}?'),
          content: Text('O preset ajustará sensibilidade, repetição, alertas e alguns recursos automáticos. Áreas, objetos escolhidos e fonte de vídeo serão preservados.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Aplicar'))],
        ),
      );
      if (confirmed != true) return;
    }
    final nextSettings = _presets.apply(current.settings, preset);
    final next = PersistedMonitorProfile(source: current.source, settings: nextSettings);
    await _settings.saveProfile(next);
    if (!mounted) return;
    setState(() => _profile = next);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Preset ${preset.label} aplicado.')));
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    if (profile == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final active = profile.settings.preset;
    return Scaffold(
      appBar: AppBar(title: const Text('Presets de monitoramento')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          const Text('Troque rapidamente um conjunto de regras sem perder suas áreas, objetos e câmeras.', style: TextStyle(fontSize: 15)),
          const SizedBox(height: 12),
          ...MonitoringPreset.values.map((preset) {
            final selected = active == preset;
            return Card(
              margin: const EdgeInsets.only(bottom: 9),
              child: ListTile(
                selected: selected,
                onTap: () => unawaited(_apply(preset)),
                leading: Icon(switch (preset) {
                  MonitoringPreset.home => Icons.home_outlined,
                  MonitoringPreset.away => Icons.directions_walk_outlined,
                  MonitoringPreset.night => Icons.nightlight_outlined,
                  MonitoringPreset.custom => Icons.tune_rounded,
                }),
                title: Text(preset.label, style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text(preset.description),
                trailing: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off),
              ),
            );
          }),
          const SizedBox(height: 10),
          const Text('Qualquer ajuste manual posterior pode ser mantido escolhendo Personalizado. O aplicativo não troca presets sozinho.'),
        ],
      ),
    );
  }
}
