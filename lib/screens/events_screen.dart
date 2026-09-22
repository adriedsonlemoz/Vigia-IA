import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:vlc_player/vlc_player.dart';

import '../models/monitor_event.dart';
import '../models/object_filter_catalog.dart';
import '../services/event_history_service.dart';
import '../services/native_platform_service.dart';
import '../widgets/main_navigation_bar.dart';
import '../widgets/export_destination_dialog.dart';
import 'home_screen.dart';
import 'multi_camera_screen.dart';
import 'settings_screen.dart';

part 'events_screen_components.dart';
part 'events_screen_actions.dart';

enum _HistoryGroupFilter { all, people, automobiles, animals }

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final EventHistoryService _history = EventHistoryService.instance;
  final NativePlatformService _native = NativePlatformService.instance;
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

  @override
  Widget build(BuildContext context) {
    final relevant = _relevantEvents;
    final events = _filteredEvents;
    final cameras = relevant.map((event) => event.source).toSet().toList()..sort();

    Widget filters() => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${events.length} registro${events.length == 1 ? '' : 's'} visível${events.length == 1 ? '' : 'eis'}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) => GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: constraints.maxWidth >= 600 ? 4 : 2,
                crossAxisSpacing: 7,
                mainAxisSpacing: 7,
                childAspectRatio: constraints.maxWidth >= 600 ? 2.35 : 2.8,
                children: [
                  _filterChip(
                    'Tudo',
                    Icons.select_all_rounded,
                    _HistoryGroupFilter.all,
                  ),
                  _filterChip(
                    'Pessoas',
                    Icons.person_outline_rounded,
                    _HistoryGroupFilter.people,
                  ),
                  _filterChip(
                    'Automóveis',
                    Icons.directions_car_outlined,
                    _HistoryGroupFilter.automobiles,
                  ),
                  _filterChip(
                    'Animais',
                    Icons.pets_outlined,
                    _HistoryGroupFilter.animals,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
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
                    child: Text(camera, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _cameraFilter = value);
              },
            ),
            const SizedBox(height: 10),
            Text(
              'Pessoas, Automóveis e Animais ficam aqui. Obstrução, conexão e erros ficam em Diagnóstico.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );

    Widget eventList() => events.isEmpty
        ? const _EmptyHistory()
        : ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
            itemCount: events.length,
            separatorBuilder: (_, _) => const SizedBox(height: 9),
            itemBuilder: (context, index) {
              final event = events[index];
              return _HistoryCard(
                event: event,
                onOpen: () => _openEvent(event),
                onDelete: () => unawaited(_requestDelete(event)),
              );
            },
          );

    return AdaptiveMainScaffold(
      currentIndex: 1,
      onDestinationSelected: _navigateMain,
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _LoadError(message: _loadError!, onRetry: _load)
              : SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth >= 760) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: 300,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(16, 12, 12, 24),
                                child: filters(),
                              ),
                            ),
                            VerticalDivider(
                              width: 1,
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withValues(alpha: 0.12),
                            ),
                            Expanded(child: eventList()),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                            child: filters(),
                          ),
                          const Divider(height: 1),
                          Expanded(child: eventList()),
                        ],
                      );
                    },
                  ),
                ),
    );
  }

  Widget _filterChip(
    String label,
    IconData icon,
    _HistoryGroupFilter filter,
  ) {
    return SizedBox.expand(
      child: ChoiceChip(
        avatar: Icon(icon, size: 17),
        label: Center(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        selected: _groupFilter == filter,
        onSelected: (_) => setState(() => _groupFilter = filter),
      ),
    );
  }
}
