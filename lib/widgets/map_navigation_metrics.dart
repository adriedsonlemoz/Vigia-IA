import 'package:flutter/material.dart';

/// Elementos visuais de navegacao: recebem leituras e cores da tela.
/// Nao criam sensores, timers ou estado persistido.

class MapNavigationMetricCell extends StatelessWidget {
  const MapNavigationMetricCell({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
    required this.foreground,
    required this.compact,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color accent;
  final Color foreground;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 16 : 18, color: accent),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: foreground,
              fontSize: compact ? 12 : 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: foreground.withValues(alpha: 0.62),
              fontSize: compact ? 8 : 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class MapNavigationPoiChip extends StatelessWidget {
  const MapNavigationPoiChip({
    required this.icon,
    required this.label,
    required this.distance,
    required this.foreground,
    required this.accent,
    required this.compact,
  });

  final IconData icon;
  final String label;
  final String distance;
  final Color foreground;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 7,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: foreground.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 17 : 20, color: accent),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground,
              fontSize: compact ? 9 : 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            distance,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground.withValues(alpha: 0.68),
              fontSize: compact ? 8 : 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
