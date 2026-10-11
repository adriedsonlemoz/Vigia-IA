import 'dart:async';

import 'package:flutter/material.dart';

import '../models/map_workspace_mode.dart';
import '../services/map_route_service.dart';
import '../widgets/map_workspace_mode_picker.dart';
import 'bike_mode_screen.dart';
import 'events_screen.dart';
import 'home_screen.dart';
import 'launch_mode_screen.dart';
import 'map_monitoring_screen.dart';
import 'multi_camera_screen.dart';
import 'settings_screen.dart';

/// Entrada normal: mapa unico, controles de modos sobrepostos e ferramentas
/// navegadas sob demanda. O estado do MapMonitoringScreen permanece montado.
class MapWorkspaceShell extends StatefulWidget {
  const MapWorkspaceShell({super.key});

  @override
  State<MapWorkspaceShell> createState() => _MapWorkspaceShellState();
}

class _MapWorkspaceShellState extends State<MapWorkspaceShell> {
  final MapRouteService _route = MapRouteService.instance;
  final ValueNotifier<int> _destinationSearchRequests = ValueNotifier<int>(0);
  MapWorkspaceMode _mode = MapWorkspaceMode.explore;
  bool _toolVisible = false;

  Future<void> _chooseMode() async {
    final selected = await showMapWorkspaceModePicker(context, selected: _mode);
    if (!mounted || selected == null) return;
    setState(() => _mode = selected);
    if (selected == MapWorkspaceMode.navigate && !_route.navigating) {
      _destinationSearchRequests.value++;
    }
  }

  @override
  void dispose() {
    _destinationSearchRequests.dispose();
    super.dispose();
  }

  Future<void> _openTool(Widget destination) async {
    if (_toolVisible) return;
    setState(() => _toolVisible = true);
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => destination),
      );
    } finally {
      if (mounted) setState(() => _toolVisible = false);
    }
  }

  Future<void> _showTools() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Text('Ferramentas do Vigia IA', style: Theme.of(sheetContext).textTheme.titleLarge),
                ),
                _toolTile(sheetContext, 'Monitoramento e IA', Icons.shield_outlined, const HomeScreen()),
                _toolTile(sheetContext, 'Historico de eventos', Icons.history_rounded, const EventsScreen()),
                _toolTile(sheetContext, 'Cameras cadastradas', Icons.videocam_outlined, const MultiCameraScreen()),
                _toolTile(sheetContext, 'Vigia Bike', Icons.directions_bike_rounded, const BikeModeScreen()),
                _toolTile(sheetContext, 'Configuracoes', Icons.settings_outlined, const SettingsScreen()),
                ListTile(
                  leading: const Icon(Icons.devices_other_rounded),
                  title: const Text('Papel deste aparelho'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.of(context).pushAndRemoveUntil<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const LaunchModeScreen(manualReview: false),
                      ),
                      (_) => false,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolTile(BuildContext sheetContext, String label, IconData icon, Widget destination) =>
      ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () {
          Navigator.of(sheetContext).pop();
          unawaited(_openTool(destination));
        },
      );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Stack(
      children: [
        Positioned.fill(
          child: MapMonitoringScreen(
            key: const ValueKey<String>('workspace-map'),
            workspaceVisible: !_toolVisible,
            navigationSearchRequests: _destinationSearchRequests,
          ),
        ),
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _route,
            builder: (context, _) {
              final navigating = _route.navigating;
              final offset = navigating ? 164.0 : 12.0;
              return Stack(
                children: [
                  Positioned(
                    left: 10,
                    bottom: bottom + offset,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Material(
                          color: Theme.of(context).colorScheme.surface,
                          elevation: 5,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            key: const ValueKey<String>('workspace-mode-button'),
                            borderRadius: BorderRadius.circular(20),
                            onTap: _chooseMode,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(mapWorkspaceIcon(_mode), size: 19),
                                  const SizedBox(width: 6),
                                  Text(_mode.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  const SizedBox(width: 3),
                                  const Icon(Icons.keyboard_arrow_up_rounded, size: 17),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Material(
                          color: Theme.of(context).colorScheme.surface,
                          elevation: 5,
                          borderRadius: BorderRadius.circular(18),
                          child: IconButton(
                            key: const ValueKey<String>('workspace-tools-button'),
                            icon: const Icon(Icons.menu_rounded),
                            tooltip: 'Ferramentas e configuracoes',
                            onPressed: _showTools,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_mode != MapWorkspaceMode.explore &&
                      !(_mode == MapWorkspaceMode.navigate && navigating))
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: bottom + (navigating ? 220 : 68),
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 340),
                          child: Material(
                            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
                            elevation: 4,
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_mode.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 3),
                                  Text(_statusText(), style: Theme.of(context).textTheme.bodySmall),
                                  if (_mode == MapWorkspaceMode.monitor || _mode == MapWorkspaceMode.ride)
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: () => unawaited(_openTool(
                                          _mode == MapWorkspaceMode.monitor
                                              ? const HomeScreen()
                                              : const BikeModeScreen(),
                                        )),
                                        child: Text(_mode == MapWorkspaceMode.monitor
                                            ? 'Abrir monitoramento'
                                            : 'Painel Bike'),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  String _statusText() => switch (_mode) {
    MapWorkspaceMode.ride => _route.recording
        ? 'Percurso ${_route.paused ? 'pausado' : 'gravando'} · '
            '${(_route.distanceMeters / 1000).toStringAsFixed(2)} km'
        : 'Pronto para gravar. Use o botao Gravar do mapa.',
    MapWorkspaceMode.navigate => 'Escolha o destino pela lupa no mapa.',
    MapWorkspaceMode.monitor =>
      'Cameras e IA permanecem desligadas ate voce abrir o monitor.',
    MapWorkspaceMode.explore => '',
  };
}
