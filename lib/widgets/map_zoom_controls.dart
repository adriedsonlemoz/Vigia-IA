import 'package:flutter/material.dart';

import '../services/map_ux_policy.dart';

/// Controles de zoom passivos. A tela hospedeira decide como aplicar o zoom.
class MapControlGap extends StatelessWidget {
  const MapControlGap({super.key, required this.horizontal});

  final bool horizontal;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: horizontal ? MapUxPolicy.controlGap : 0,
        height: horizontal ? 0 : MapUxPolicy.controlGap,
      );
}

class MapZoomCluster extends StatelessWidget {
  const MapZoomCluster({
    super.key,
    required this.horizontal,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final bool horizontal;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final children = <Widget>[
      _MapZoomAction(
        tooltip: 'Aumentar zoom',
        icon: Icons.add_rounded,
        onPressed: onZoomIn,
      ),
      SizedBox(
        width: horizontal ? 1 : 24,
        height: horizontal ? 24 : 1,
        child: ColoredBox(
          color: scheme.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      _MapZoomAction(
        tooltip: 'Diminuir zoom',
        icon: Icons.remove_rounded,
        onPressed: onZoomOut,
      ),
    ];
    return Material(
      elevation: 2,
      color: scheme.surface.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Flex(
        direction: horizontal ? Axis.horizontal : Axis.vertical,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

class _MapZoomAction extends StatelessWidget {
  const _MapZoomAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: MapUxPolicy.controlSize,
            height: MapUxPolicy.controlSize,
            child: Icon(icon, size: 21),
          ),
        ),
      );
}

