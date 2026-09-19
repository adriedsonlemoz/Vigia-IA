import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:vlc_player/vlc_player.dart';

import '../models/monitor_event.dart';
import '../models/object_filter_catalog.dart';
import '../services/event_history_service.dart';
import '../widgets/main_navigation_bar.dart';
import 'bike_mode_screen.dart';
import 'home_screen.dart';
import 'multi_camera_screen.dart';
import 'settings_screen.dart';

enum _HistoryGroupFilter { all, people, automobiles, animals }

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final EventHistoryService _history = EventHistoryService.instance;
  bool _loading = true;
  String? _loadError;
  _HistoryGroupFilter _groupFilter = _HistoryGroupFilter.all;
  static const _allCameras = '__all_cameras__';
  String _cameraFilter = _allCameras;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      await _history.initialize();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Não foi possível abrir o histórico.';
      });
    }
  }

  bool _isRelevant(MonitorEvent event) {
    if (event.type == MonitorEventType.cameraObstructed ||
        event.type == MonitorEventType.cameraMoved) {
      return false;
    }
    return ObjectFilterCatalog.groupKeyForLabel(event.label) != null;
  }

  List<MonitorEvent> get _relevantEvents =>
      _history.events.where(_isRelevant).toList(growable: false);

  List<MonitorEvent> get _filteredEvents {
    return _relevantEvents.where((event) {
      final group = ObjectFilterCatalog.groupKeyForLabel(event.label);
      final groupMatches = switch (_groupFilter) {
        _HistoryGroupFilter.all => true,
        _HistoryGroupFilter.people => group == 'person',
        _HistoryGroupFilter.automobiles => group == 'vehicle',
        _HistoryGroupFilter.animals => group == 'animal',
      };
      if (!groupMatches) return false;
      if (_cameraFilter != _allCameras && event.source != _cameraFilter) return false;
      return true;
    }).toList(growable: false);
  }

  void _navigateMain(int index) {
    if (index == 1) return;
    final Widget target = switch (index) {
      0 => const HomeScreen(),
      2 => const HomeScreen(startMonitorOnLoad: true),
      3 => const MultiCameraScreen(),
      4 => const BikeModeScreen(),
      _ => const EventsScreen(),
    };
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => target),
      (route) => false,
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
  }

  Future<void> _delete(MonitorEvent event) async {
    await _history.deleteEvent(event.id);
    if (mounted) setState(() {});
  }

  Future<void> _clear() async {
    if (_relevantEvents.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Limpar histórico?'),
        content: const Text(
          'As detecções e seus registros visuais serão removidos. Os registros técnicos do Diagnóstico são separados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _history.clear();
    if (!mounted) return;
    setState(() {
      _groupFilter = _HistoryGroupFilter.all;
      _cameraFilter = _allCameras;
    });
  }

  void _openEvent(MonitorEvent event) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (event.clipPath != null)
                  _Media(path: event.clipPath!, fit: BoxFit.contain)
                else if (event.snapshotPath != null)
                  _Media(path: event.snapshotPath!, fit: BoxFit.contain)
                else
                  const AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Center(
                      child: Icon(Icons.image_not_supported_outlined, size: 48),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _categoryName(event),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text('Horário: ${_formatDateTime(event.createdAt)}'),
                      Text('Câmera: ${event.source}'),
                      Text('Confiança: ${(event.confidence * 100).round()}%'),
                      if (event.zoneName != null) Text('Área: ${event.zoneName}'),
                      if (event.type != MonitorEventType.alert)
                        Text(
                          event.type == MonitorEventType.entered
                              ? 'Registro: entrada na área (não é contador)'
                              : 'Registro: saída da área (não é contador)',
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final relevant = _relevantEvents;
    final events = _filteredEvents;
    final cameras = relevant.map((event) => event.source).toSet().toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Histórico', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('Quem ou o que passou na câmera', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Configurações',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
          PopupMenuButton<String>(
            tooltip: 'Opções do histórico',
            onSelected: (value) {
              if (value == 'clear') unawaited(_clear());
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'clear',
                enabled: relevant.isNotEmpty && !_loading,
                child: const ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_sweep_outlined),
                  title: Text('Limpar histórico'),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: MainNavigationBar(
        currentIndex: 1,
        onDestinationSelected: _navigateMain,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _LoadError(message: _loadError!, onRetry: _load)
              : SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '${events.length} registro${events.length == 1 ? '' : 's'} visível${events.length == 1 ? '' : 'eis'}',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _filterChip('Tudo', _HistoryGroupFilter.all),
                                  _filterChip('Pessoas', _HistoryGroupFilter.people),
                                  _filterChip('Automóveis', _HistoryGroupFilter.automobiles),
                                  _filterChip('Animais', _HistoryGroupFilter.animals),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: _cameraFilter,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.videocam_outlined),
                                labelText: 'Câmera',
                              ),
                              items: <DropdownMenuItem<String>>[
                                const DropdownMenuItem<String>(
                                  value: _allCameras,
                                  child: Text('Todas as câmeras'),
                                ),
                                ...cameras.map(
                                  (camera) => DropdownMenuItem<String>(
                                    value: camera,
                                    child: Text(camera),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) setState(() => _cameraFilter = value);
                              },
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Aqui aparecem apenas Pessoas, Automóveis e Animais. Obstrução, deslocamento, conexão e erros ficam em Diagnóstico.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 16),
                      Expanded(
                        child: events.isEmpty
                            ? const _EmptyHistory()
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                                itemCount: events.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 9),
                                itemBuilder: (context, index) {
                                  final event = events[index];
                                  return _HistoryCard(
                                    event: event,
                                    onOpen: () => _openEvent(event),
                                    onDelete: () => unawaited(_delete(event)),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _filterChip(String label, _HistoryGroupFilter filter) {
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: ChoiceChip(
        label: Text(label),
        selected: _groupFilter == filter,
        onSelected: (_) => setState(() => _groupFilter = filter),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.event,
    required this.onOpen,
    required this.onDelete,
  });

  final MonitorEvent event;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              SizedBox(
                width: 92,
                height: 72,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _EventThumbnail(event: event),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(_categoryIcon(event), size: 18, color: scheme.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _categoryName(event),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        Text(
                          '${(event.confidence * 100).round()}%',
                          style: TextStyle(
                            color: scheme.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(event.source, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(
                      _formatDateTime(event.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (event.type != MonitorEventType.alert)
                      Text(
                        event.type == MonitorEventType.entered
                            ? 'Entrada registrada · não é contador'
                            : 'Saída registrada · não é contador',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Opções',
                onSelected: (value) {
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'delete', child: Text('Excluir')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventThumbnail extends StatelessWidget {
  const _EventThumbnail({required this.event});
  final MonitorEvent event;

  @override
  Widget build(BuildContext context) {
    final path = event.snapshotPath;
    if (path == null || path.isEmpty) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(child: Icon(_categoryIcon(event), size: 32)),
      );
    }
    return _Media(path: path, fit: BoxFit.cover);
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.history_toggle_off_rounded,
                size: 50,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 10),
              const Text(
                'Nenhuma detecção corresponde aos filtros.\nQuando uma pessoa, automóvel ou animal passar na câmera, o registro aparecerá aqui.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 44),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => unawaited(onRetry()),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
}

class _Media extends StatelessWidget {
  const _Media({required this.path, required this.fit});
  final String path;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (path.toLowerCase().endsWith('.mp4')) return _VideoMedia(path: path);
    return Image.file(
      File(path),
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const ColoredBox(
        color: Colors.black26,
        child: Center(child: Icon(Icons.broken_image_outlined)),
      ),
    );
  }
}

class _VideoMedia extends StatefulWidget {
  const _VideoMedia({required this.path});
  final String path;

  @override
  State<_VideoMedia> createState() => _VideoMediaState();
}

class _VideoMediaState extends State<_VideoMedia> {
  late final VlcPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VlcPlayerController(
      mediaSource: VlcMediaSource(uri: Uri.file(widget.path)),
      autoPlay: true,
      options: const <String>['--no-audio'],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 16 / 9,
        child: VlcPlayer(controller: _controller, fit: VlcVideoFit.contain),
      );
}

String _categoryName(MonitorEvent event) =>
    ObjectFilterCatalog.singularNameForLabel(event.label) ?? 'Detecção';

IconData _categoryIcon(MonitorEvent event) =>
    switch (ObjectFilterCatalog.groupKeyForLabel(event.label)) {
      'person' => Icons.person_outline_rounded,
      'vehicle' => Icons.directions_car_outlined,
      'animal' => Icons.pets_outlined,
      _ => Icons.radar_rounded,
    };

String _formatDateTime(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)}/${value.year} · '
      '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
}
