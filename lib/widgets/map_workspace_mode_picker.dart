import 'package:flutter/material.dart';

import '../models/map_workspace_mode.dart';

IconData mapWorkspaceIcon(MapWorkspaceMode mode) => switch (mode) {
  MapWorkspaceMode.explore => Icons.map_outlined,
  MapWorkspaceMode.ride => Icons.directions_bike_rounded,
  MapWorkspaceMode.navigate => Icons.navigation_rounded,
  MapWorkspaceMode.monitor => Icons.videocam_outlined,
};

/// Escolhe apenas a apresentacao; nenhum hardware e ativado por este painel.
Future<MapWorkspaceMode?> showMapWorkspaceModePicker(
  BuildContext context, {
  required MapWorkspaceMode selected,
}) =>
    showModalBottomSheet<MapWorkspaceMode>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => MapWorkspaceModePicker(selected: selected),
    );

class MapWorkspaceModePicker extends StatelessWidget {
  const MapWorkspaceModePicker({super.key, required this.selected});

  final MapWorkspaceMode selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 540,
        maxHeight: MediaQuery.sizeOf(context).height * 0.86,
      ),
      child: SingleChildScrollView(
        child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Modo do mapa', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text('Escolha o painel. Sua gravacao e navegacao continuam independentes do modo selecionado.'),
            const SizedBox(height: 10),
            for (final mode in MapWorkspaceMode.values)
              ListTile(
                key: ValueKey<String>('workspace-${mode.name}'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: Icon(mapWorkspaceIcon(mode)),
                title: Text(mode.label),
                subtitle: Text(mode.description),
                trailing: mode == selected
                    ? Icon(Icons.check_circle_rounded, color: scheme.primary)
                    : null,
                selected: mode == selected,
                onTap: () => Navigator.of(context).pop(mode),
              ),
          ],
        ),
        ),
      ),
    );
  }
}
