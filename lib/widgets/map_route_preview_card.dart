import 'package:flutter/material.dart';

import '../models/bike_trip_plan.dart';
import '../models/map_cycling_route.dart';
import '../models/map_navigation_target.dart';
import '../models/map_travel_mode.dart';
import '../services/map_route_preview_metrics.dart';

/// Apresentacao da pre-visualizacao de rota; nao inicia GPS, gravacao ou rede.
/// O controle dos dados, acoes e ciclo de vida pertence a tela de mapa.

class MapRoutePreviewCard extends StatelessWidget {
  const MapRoutePreviewCard({
    required this.target,
    required this.routes,
    required this.selectedIndex,
    required this.loading,
    required this.plan,
    required this.bikePreferences,
    required this.onEditPace,
    required this.collapsed,
    required this.onToggleCollapsed,
    required this.onShowRoute,
    required this.onClose,
    required this.onChoose,
    required this.onPlan,
    required this.onStart,
    required this.onSave,
  });

  final MapNavigationTarget target;
  final List<MapCyclingRoute> routes;
  final int selectedIndex;
  final bool loading;
  final BikeTripPlan? plan;
  final BikeTravelPreferences bikePreferences;
  final VoidCallback onEditPace;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;
  final VoidCallback onShowRoute;
  final VoidCallback onClose;
  final ValueChanged<int> onChoose;
  final VoidCallback? onPlan;
  final VoidCallback onStart;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chosen = routes.isEmpty ? null : routes[selectedIndex];
    final metrics = chosen == null ? null : MapRoutePreviewMetrics.forRoute(
      route: chosen, mode: target.travelMode, bikePreferences: bikePreferences);
    final firstMetrics = routes.isEmpty ? null : MapRoutePreviewMetrics.forRoute(
      route: routes.first, mode: target.travelMode, bikePreferences: bikePreferences);
    return Material(
      elevation: 10,
      color: scheme.surface.withValues(alpha: 0.98),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.alt_route_rounded, size: 19),
            const SizedBox(width: 8),
            Expanded(child: Text('Prévia · ${target.label}',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900))),
            IconButton(
              tooltip: collapsed ? 'Expandir prévia' : 'Recolher prévia',
              onPressed: onToggleCollapsed,
              visualDensity: VisualDensity.compact,
              icon: Icon(collapsed ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded),
            ),
            IconButton(tooltip: 'Fechar prévia', onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
              visualDensity: VisualDensity.compact),
          ]),
          if (collapsed && metrics != null)
            Text('${metrics.distanceLabel} · ${metrics.durationLabel} · '
                'Toque na seta para ver opções',
                style: Theme.of(context).textTheme.bodySmall),
          if (!collapsed && loading) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text('Calculando alternativas sem iniciar a navegação…'),
          ] else if (!collapsed && metrics != null) ...[
            Text(
              '${metrics.distanceLabel} · ${metrics.durationLabel} · '
              '${target.travelMode.routeLabel}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Text(metrics.durationSource,
              style: Theme.of(context).textTheme.bodySmall),
            if (target.travelMode == MapTravelMode.bicycle)
              Align(alignment: Alignment.centerLeft, child: TextButton.icon(
                onPressed: onEditPace,
                icon: const Icon(Icons.tune_rounded, size: 17),
                label: const Text('Editar ritmo do pedal'),
              )),
            if (routes.length > 1) ...[
              const SizedBox(height: 7),
              SizedBox(height: 37,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: routes.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final option = routes[index];
                    final optionMetrics = MapRoutePreviewMetrics.forRoute(
                      route: option, mode: target.travelMode,
                      bikePreferences: bikePreferences);
                    return ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    label: Text('Rota ${index + 1} · '
                      '${optionMetrics.distanceLabel} · '
                      '${optionMetrics.durationLabel}'),
                    selected: selectedIndex == index,
                    onSelected: (_) => onChoose(index),
                  );
                  },
                ),
              ),
            ],
            if (routes.length > 1 && firstMetrics != null && selectedIndex > 0)
              Text(metrics.distanceDifference(firstMetrics),
                style: Theme.of(context).textTheme.bodySmall),
            Text('Relevo, qualidade e tipo de via: sem dados comparáveis nesta prévia.',
              style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: onShowRoute,
                icon: const Icon(Icons.fit_screen_rounded, size: 18),
                label: const Text('Ver trajeto'),
              )),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.save_alt_rounded, size: 18),
                label: const Text('Salvar offline'),
              )),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              if (target.travelMode == MapTravelMode.bicycle)
                Expanded(child: OutlinedButton.icon(
                  onPressed: onPlan,
                  icon: const Icon(Icons.calendar_month_rounded, size: 18),
                  label: Text(plan == null ? 'Carregando plano' :
                    'Plano ${plan!.estimate.dayCount}d'),
                )),
              if (target.travelMode == MapTravelMode.bicycle)
                const SizedBox(width: 8),
              Expanded(child: FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.navigation_rounded, size: 18),
                label: const Text('Iniciar'),
              )),
            ]),
            const Text('Trajeto salvo pode ser consultado offline; novos cálculos exigem internet.',
              style: TextStyle(fontSize: 10.5)),
          ],
        ]),
      ),
    );
  }
}
