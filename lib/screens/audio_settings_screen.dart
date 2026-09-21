import 'dart:async';

import 'package:flutter/material.dart';

import '../models/audio_slot.dart';
import '../services/native_platform_service.dart';

class AudioSettingsScreen extends StatefulWidget {
  const AudioSettingsScreen({super.key});

  @override
  State<AudioSettingsScreen> createState() => _AudioSettingsScreenState();
}

class _AudioSettingsScreenState extends State<AudioSettingsScreen> {
  final _native = NativePlatformService.instance;
  Set<String> _overrides = <String>{};
  bool _loading = true;
  bool _previewing = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final overrides = await _native.audioOverrideSlots();
    if (!mounted) return;
    setState(() {
      _overrides = overrides;
      _loading = false;
    });
  }

  Future<void> _preview(AudioSlotDefinition slot) async {
    if (_previewing) return;
    setState(() => _previewing = true);
    final played = await _native.playCustomAlertAudio(slot.id, priority: 1);
    final diagnostics = await _native.audioDiagnostics();
    if (!mounted) return;
    setState(() => _previewing = false);
    if (diagnostics['mediaVolume'] == 0 || diagnostics['mediaMuted'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('O volume de mídia está zerado. Aumente o volume e teste novamente.')));
    }
    if (!played && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível reproduzir este áudio.')),
      );
    }
  }

  Future<void> _import(AudioSlotDefinition slot) async {
    final imported = await _native.importAudioOverride(slot.id);
    if (!mounted) return;
    if (imported) {
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Áudio de “${slot.title}” substituído.')),
      );
    }
  }

  Future<void> _record(AudioSlotDefinition slot) async {
    final started = await _native.startAudioRecording(slot.id);
    if (!mounted) return;
    if (!started) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível iniciar a gravação. Confira a permissão do microfone.')),
      );
      return;
    }

    final save = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => PopScope(
            canPop: false,
            child: AlertDialog(
              icon: const Icon(Icons.mic_rounded, size: 34),
              title: const Text('Gravando áudio'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(slot.phrase, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 10),
                  const Text('Fale a frase e toque em Salvar quando terminar.'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('Salvar'),
                ),
              ],
            ),
          ),
        ) ??
        false;

    final stopped = await _native.stopAudioRecording(save: save);
    if (!mounted) return;
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          save && stopped
              ? 'Gravação salva para “${slot.title}”.'
              : save
                  ? 'Não foi possível salvar a gravação.'
                  : 'Gravação descartada.',
        ),
      ),
    );
  }

  Future<void> _restore(AudioSlotDefinition slot) async {
    final removed = await _native.removeAudioOverride(slot.id);
    if (!mounted) return;
    if (removed) {
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('“${slot.title}” voltou ao áudio padrão do Vigia IA.')),
      );
    }
  }

  Future<void> _restoreAll() async {
    if (_overrides.isEmpty) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Restaurar todos os áudios?'),
            content: Text('Isso removerá ${_overrides.length} áudio(s) personalizado(s) e voltará aos padrões do Vigia IA.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Restaurar')),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    final ok = await _native.removeAllAudioOverrides();
    if (!mounted) return;
    if (ok) await _refresh();
  }

  List<AudioSlotDefinition> _filtered(String section) {
    final query = _query.trim().toLowerCase();
    return AudioSlotCatalog.all.where((slot) {
      if (slot.section != section) return false;
      if (query.isEmpty) return true;
      return slot.title.toLowerCase().contains(query) ||
          slot.phrase.toLowerCase().contains(query) ||
          slot.id.contains(query);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Áudios e voz', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('Ouça, troque, grave ou restaure', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _overrides.isEmpty ? null : _restoreAll,
            tooltip: 'Restaurar todos',
            icon: const Icon(Icons.restore_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.library_music_outlined),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${AudioSlotCatalog.all.length} áudios padrão disponíveis',
                                  style: const TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _overrides.isEmpty
                                ? 'Nenhum áudio personalizado. O aplicativo usa os arquivos padrão e mantém TTS como fallback de segurança.'
                                : '${_overrides.length} áudio(s) personalizado(s). Eles têm prioridade sobre o padrão e continuam após atualizações do app.',
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Os itens marcados como “Futuro” já estão preparados para o Modo Bike/ESP32, mas só tocarão quando essas funções forem conectadas aos sensores.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      labelText: 'Buscar áudio',
                      hintText: 'Ex.: pneu, câmera, freio…',
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final section in AudioSlotCatalog.sections)
                    if (_filtered(section).isNotEmpty) ...[
                      _SectionTitle(title: section, count: _filtered(section).length),
                      ..._filtered(section).map(
                        (slot) => _AudioSlotCard(
                          slot: slot,
                          customized: _overrides.contains(slot.id),
                          onPlay: () => _preview(slot),
                          onImport: () => _import(slot),
                          onRecord: () => _record(slot),
                          onRestore: _overrides.contains(slot.id) ? () => _restore(slot) : null,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                ],
              ),
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
        child: Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
            Text('$count', style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
      );
}

class _AudioSlotCard extends StatelessWidget {
  const _AudioSlotCard({
    required this.slot,
    required this.customized,
    required this.onPlay,
    required this.onImport,
    required this.onRecord,
    this.onRestore,
  });

  final AudioSlotDefinition slot;
  final bool customized;
  final VoidCallback onPlay;
  final VoidCallback onImport;
  final VoidCallback onRecord;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(slot.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        Text(slot.phrase, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (slot.future)
                    const Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text('Futuro'),
                      avatar: Icon(Icons.construction_rounded, size: 16),
                    )
                  else if (customized)
                    const Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text('Seu áudio'),
                      avatar: Icon(Icons.mic_rounded, size: 16),
                    ),
                  if (onRestore != null)
                    IconButton(
                      onPressed: onRestore,
                      tooltip: 'Restaurar áudio padrão',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.restore_rounded),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _AudioActionButton(
                      onPressed: onPlay,
                      icon: Icons.play_arrow_rounded,
                      label: 'Ouvir',
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _AudioActionButton(
                      onPressed: onImport,
                      icon: Icons.audio_file_outlined,
                      label: 'Trocar',
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _AudioActionButton(
                      onPressed: onRecord,
                      icon: Icons.mic_none_rounded,
                      label: 'Gravar',
                    ),
                  ),
                ],
              ),
              if (customized && slot.future)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('Personalizado · reservado para integração futura', style: TextStyle(fontSize: 12)),
                )
              else if (customized)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('Personalizado · usado no lugar do áudio padrão', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ),
      );
}

class _AudioActionButton extends StatelessWidget {
  const _AudioActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 19),
            const SizedBox(width: 5),
            Text(label, maxLines: 1, softWrap: false),
          ],
        ),
      ),
    );
  }
}

