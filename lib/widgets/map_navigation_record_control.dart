import 'package:flutter/material.dart';

/// Componente visual da gravação no banner de navegação.
/// Estado, regras de GPS, ações e exportação pertencem à tela principal.
/// Gravacao integrada ao aviso de navegacao, sem segunda barra flutuante.
class MapNavigationRecordControl extends StatelessWidget {
  const MapNavigationRecordControl({
    required this.recording,
    required this.paused,
    required this.canRecord,
    required this.hasRoute,
    required this.onToggleRecording,
    required this.onTogglePause,
    required this.onExport,
  });

  final bool recording;
  final bool paused;
  final bool canRecord;
  final bool hasRoute;
  final VoidCallback onToggleRecording;
  final VoidCallback onTogglePause;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    if (!recording) {
      return Tooltip(
        message: canRecord ? 'Gravar percurso' : 'GPS indisponível',
        child: TextButton(
          onPressed: canRecord ? onToggleRecording : null,
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 3),
            minimumSize: const Size(45, 32),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.fiber_manual_record_rounded, size: 16, color: color),
            const Text('Gravar', style: TextStyle(fontSize: 9)),
          ]),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: paused ? 'Retomar gravação' : 'Pausar gravação',
          onPressed: onTogglePause,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 32, height: 30),
          icon: Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            color: color, size: 20),
        ),
        PopupMenuButton<String>(
          tooltip: 'Gravação: encerrar ou exportar GPX',
          padding: EdgeInsets.zero,
          iconSize: 20,
          constraints: const BoxConstraints(minWidth: 180),
          onSelected: (action) {
            if (action == 'stop') onToggleRecording();
            if (action == 'gpx') onExport();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'stop', child: Text('Encerrar gravação')),
            if (hasRoute)
              const PopupMenuItem(value: 'gpx', child: Text('Exportar GPX')),
          ],
          icon: Icon(Icons.stop_circle_outlined, color: color),
        ),
      ],
    );
  }
}
