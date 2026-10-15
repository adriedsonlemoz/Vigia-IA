import 'package:flutter/material.dart';

import '../models/map_cycling_route.dart';

/// Mostra alternativas de navegacao recebidas da tela, sem recalcular rotas.
/// A tela original e responsavel pela selecao e pela atualizacao do estado.

class MapRouteAlternativesButton extends StatelessWidget {
  const MapRouteAlternativesButton({
    required this.routes,
    required this.selectedIndex,
    required this.accent,
    required this.foreground,
    required this.compact,
    required this.distanceLabel,
    required this.durationLabel,
    required this.deltaLabel,
    required this.onSelected,
  });

  final List<MapCyclingRoute> routes;
  final int selectedIndex;
  final Color accent;
  final Color foreground;
  final bool compact;
  final String Function(double) distanceLabel;
  final String Function(MapCyclingRoute) durationLabel;
  final String Function(MapCyclingRoute) deltaLabel;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final enabled = routes.length > 1;
    return PopupMenuButton<int>(
      enabled: enabled,
      tooltip: enabled ? 'Comparar rotas alternativas' : 'Sem rotas alternativas',
      initialValue: selectedIndex,
      onSelected: onSelected,
      position: PopupMenuPosition.over,
      constraints: const BoxConstraints(minWidth: 245, maxWidth: 310),
      itemBuilder: (context) => <PopupMenuEntry<int>>[
        for (var index = 0; index < routes.length; index++)
          PopupMenuItem<int>(
            value: index,
            child: Row(
              children: [
                Icon(
                  index == selectedIndex ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  size: 18,
                  color: index == selectedIndex ? accent : foreground.withValues(alpha: 0.55),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Rota ${index + 1} · ${distanceLabel(routes[index].distanceMeters)} · ${durationLabel(routes[index])}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      _deltaText(routes[index], deltaLabel, foreground),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 28 : 32,
              height: compact ? 24 : 28,
              decoration: BoxDecoration(
                color: enabled ? accent.withValues(alpha: 0.16) : foreground.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: enabled ? accent.withValues(alpha: 0.36) : foreground.withValues(alpha: 0.08)),
              ),
              child: Icon(Icons.alt_route_rounded, size: compact ? 16 : 18, color: enabled ? accent : foreground.withValues(alpha: 0.42)),
            ),
            const SizedBox(height: 3),
            Text(
              enabled ? '${routes.length} opções' : '1 opção',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: foreground, fontSize: compact ? 10 : 11.5, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 1),
            Text(
              'rotas',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: foreground.withValues(alpha: 0.62), fontSize: compact ? 7.5 : 8.5, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deltaText(
    MapCyclingRoute route,
    String Function(MapCyclingRoute) formatter,
    Color textColor,
  ) {
    final value = formatter(route);
    return Text(
      value.isEmpty ? 'Sem comparação disponível' : value,
      style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.62)),
    );
  }
}
