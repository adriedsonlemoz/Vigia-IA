import 'package:flutter/material.dart';

import '../services/map_hud_presentation.dart';

/// Indicador compacto que preserva acesso aos instrumentos sem bloquear o mapa.
class MapHudContextPill extends StatelessWidget {
  const MapHudContextPill({
    super.key,
    required this.presentation,
    required this.onToggleTelemetry,
  });

  final MapHudPresentation presentation;
  final VoidCallback onToggleTelemetry;

  @override
  Widget build(BuildContext context) {
    final icon = switch (presentation.context) {
      MapHudContext.exploring => Icons.explore_rounded,
      MapHudContext.pedaling => Icons.pedal_bike_rounded,
      MapHudContext.navigating => Icons.navigation_rounded,
      MapHudContext.recording => Icons.fiber_manual_record_rounded,
    };
    final expanded = presentation.showTelemetry;
    return Tooltip(
      message: expanded ? 'Recolher instrumentos' : 'Mostrar instrumentos',
      child: Material(
        color: const Color(0xF0081D31),
        elevation: 2,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onToggleTelemetry,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 17, color: const Color(0xFF19D2BC)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  presentation.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (presentation.recording &&
                  presentation.context != MapHudContext.recording) ...[
                const SizedBox(width: 6),
                const Icon(Icons.fiber_manual_record, size: 10,
                    color: Color(0xFFFF7777)),
                const Text(' REC', style: TextStyle(
                  color: Color(0xFFFFA8A8), fontSize: 10,
                  fontWeight: FontWeight.w700,
                )),
              ],
              const SizedBox(width: 8),
              Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  size: 17, color: Colors.white70),
            ]),
          ),
        ),
      ),
    );
  }
}
