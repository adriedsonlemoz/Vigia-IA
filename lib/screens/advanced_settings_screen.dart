import 'dart:async';

import 'package:flutter/material.dart';

import '../models/video_source_config.dart';
import '../services/app_settings_service.dart';

class AdvancedSettingsScreen extends StatefulWidget {
  const AdvancedSettingsScreen({super.key});

  @override
  State<AdvancedSettingsScreen> createState() => _AdvancedSettingsScreenState();
}

class _AdvancedSettingsScreenState extends State<AdvancedSettingsScreen> {
  final _service = AppSettingsService.instance;
  PersistedMonitorProfile? _profile;
  double _confidence = 0.55;
  double _analysisMs = 800;
  double _repeatSeconds = 60;
  double _absenceSeconds = 3;
  double _maxResults = 10;
  double _confirmationHits = 2;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final profile = await _service.initialize();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _confidence = profile.settings.confidenceThreshold;
      _analysisMs = profile.source.analysisInterval.inMilliseconds.toDouble();
      _repeatSeconds = profile.settings.repeatInterval.inMilliseconds / 1000;
      _absenceSeconds = profile.settings.absenceReset.inMilliseconds / 1000;
      _maxResults = profile.settings.maxResults.toDouble();
      _confirmationHits = profile.settings.motionConfirmationHits.toDouble();
    });
  }

  Future<void> _save() async {
    final current = _profile;
    if (current == null) return;
    final next = PersistedMonitorProfile(
      source: current.source.copyWith(
        analysisInterval: Duration(milliseconds: _analysisMs.round()),
      ),
      settings: current.settings.copyWith(
        confidenceThreshold: _confidence,
        repeatInterval: Duration(seconds: _repeatSeconds.round()),
        absenceReset: Duration(milliseconds: (_absenceSeconds * 1000).round()),
        maxResults: _maxResults.round(),
        motionConfirmationHits: _confirmationHits.round(),
      ),
    );
    await _service.saveProfile(next);
    _profile = next;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ajustes avançados salvos.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Avançado'),
        actions: [
          IconButton(onPressed: _save, tooltip: 'Salvar', icon: const Icon(Icons.save_outlined)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          const Text(
            'Parâmetros técnicos da IA',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'Esses controles ficam separados para não poluir as telas principais. Os valores padrão atendem a maioria dos casos.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          _SettingSlider(
            title: 'Confiança mínima',
            description: 'Define quão certa a IA precisa estar antes de aceitar uma detecção. Valor maior reduz falsos positivos, mas pode ignorar objetos difíceis.',
            valueText: '${(_confidence * 100).round()}%',
            value: _confidence,
            min: 0.30,
            max: 0.90,
            divisions: 12,
            onChanged: (value) => setState(() => _confidence = value),
          ),
          _SettingSlider(
            title: 'Intervalo da IA',
            description: 'Tempo entre análises de imagem. Menor intervalo reage mais rápido e usa mais processamento e bateria.',
            valueText: '${_analysisMs.round()} ms',
            value: _analysisMs,
            min: 300,
            max: 2000,
            divisions: 17,
            onChanged: (value) => setState(() => _analysisMs = value),
          ),
          _SettingSlider(
            title: 'Repetição de alertas',
            description: 'Tempo mínimo antes de avisar novamente sobre o mesmo objeto. Evita alertas repetitivos enquanto ele continua visível.',
            valueText: '${_repeatSeconds.round()} s',
            value: _repeatSeconds,
            min: 10,
            max: 300,
            divisions: 29,
            onChanged: (value) => setState(() => _repeatSeconds = value),
          ),
          _SettingSlider(
            title: 'Ausência para encerrar evento',
            description: 'Quanto tempo o objeto precisa ficar ausente para o rastreamento considerar que aquele evento terminou.',
            valueText: '${_absenceSeconds.toStringAsFixed(1)} s',
            value: _absenceSeconds,
            min: 1,
            max: 10,
            divisions: 18,
            onChanged: (value) => setState(() => _absenceSeconds = value),
          ),
          _SettingSlider(
            title: 'Máximo de resultados por análise',
            description: 'Limite técnico de detecções que a IA processa em cada quadro analisado.',
            valueText: '${_maxResults.round()}',
            value: _maxResults,
            min: 3,
            max: 20,
            divisions: 17,
            onChanged: (value) => setState(() => _maxResults = value),
          ),
          _SettingSlider(
            title: 'Confirmações de movimento',
            description: 'Quantidade de observações necessárias antes de confirmar um alerta quando o filtro de movimento está ativo.',
            valueText: '${_confirmationHits.round()}',
            value: _confirmationHits,
            min: 1,
            max: 5,
            divisions: 4,
            onChanged: (value) => setState(() => _confirmationHits = value),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('SALVAR AJUSTES'),
          ),
        ],
      ),
    );
  }
}

class _SettingSlider extends StatelessWidget {
  const _SettingSlider({
    required this.title,
    required this.description,
    required this.valueText,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String title;
  final String description;
  final String valueText;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                  Text(
                    valueText,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(description, style: Theme.of(context).textTheme.bodySmall),
              Slider(
                value: value,
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      );
}
