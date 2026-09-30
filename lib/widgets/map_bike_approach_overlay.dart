import 'package:flutter/material.dart';

import '../models/bike_approach_status.dart';

class MapBikeApproachOverlay extends StatelessWidget {
  const MapBikeApproachOverlay({
    super.key,
    required this.status,
  });

  final BikeApproachStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = _tone(theme.colorScheme);
    final approaching = status.level != BikeApproachLevel.clear;
    final vehicleDetected = status.vehicleDetected || approaching;
    final parts = <String>[
      if (vehicleDetected) 'Veículo',
      if (approaching) 'aproximando' else if (vehicleDetected) 'sem aproximação',
      _riskLabel,
      if (approaching) status.ttcLabel,
    ];

    return IgnorePointer(
      child: Semantics(
        label: parts.join(', '),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.70),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: tone.withValues(alpha: 0.88)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_icon, size: 12, color: tone),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    parts.join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _riskLabel => switch (status.level) {
        BikeApproachLevel.clear => 'sem risco',
        BikeApproachLevel.watch => 'atenção',
        BikeApproachLevel.warning => 'risco alto',
        BikeApproachLevel.critical => 'risco crítico',
      };

  IconData get _icon => switch (status.level) {
        BikeApproachLevel.clear => Icons.shield_outlined,
        BikeApproachLevel.watch => Icons.directions_car_rounded,
        BikeApproachLevel.warning => Icons.warning_amber_rounded,
        BikeApproachLevel.critical => Icons.warning_rounded,
      };

  Color _tone(ColorScheme scheme) => switch (status.level) {
        BikeApproachLevel.clear => scheme.primary,
        BikeApproachLevel.watch => Colors.lightBlueAccent,
        BikeApproachLevel.warning => Colors.orangeAccent,
        BikeApproachLevel.critical => scheme.error,
      };
}
