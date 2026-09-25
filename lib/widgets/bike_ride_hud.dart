import 'package:flutter/material.dart';

import '../models/bike_sensor_snapshot.dart';

/// Faixa responsiva para Hall, temperatura e pressão dos pneus.
class BikeRideHud extends StatelessWidget {
  const BikeRideHud({
    super.key,
    required this.snapshot,
  });

  final BikeSensorSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final warning = snapshot.primaryWarning;
    final color = switch (snapshot.health) {
      BikeSensorHealth.critical => Theme.of(context).colorScheme.error,
      BikeSensorHealth.disconnected => Theme.of(context).colorScheme.error,
      BikeSensorHealth.warning => Theme.of(context).colorScheme.tertiary,
      BikeSensorHealth.normal => Theme.of(context).colorScheme.primary,
    };
    final metrics = <_BikeMetricData>[
      _BikeMetricData(
        icon: Icons.speed_rounded,
        label: 'Velocidade',
        value: snapshot.connected ? snapshot.speedKmh.toStringAsFixed(0) : '--',
        unit: 'km/h',
        featured: true,
      ),
      _BikeMetricData(
        icon: Icons.device_thermostat_rounded,
        label: 'Temperatura',
        value: snapshot.connected && snapshot.ambientTemperatureC != null
            ? snapshot.ambientTemperatureC!.toStringAsFixed(0)
            : '--',
        unit: '°C',
      ),
      _BikeMetricData(
        icon: Icons.tire_repair_rounded,
        label: 'Pneu dianteiro',
        value: snapshot.connected ? snapshot.frontTirePsi.toStringAsFixed(0) : '--',
        unit: 'PSI',
        alert: snapshot.connected && snapshot.frontTirePsi < snapshot.minimumTirePressurePsi,
      ),
      _BikeMetricData(
        icon: Icons.tire_repair_rounded,
        label: 'Pneu traseiro',
        value: snapshot.connected ? snapshot.rearTirePsi.toStringAsFixed(0) : '--',
        unit: 'PSI',
        alert: snapshot.connected && snapshot.rearTirePsi < snapshot.minimumTirePressurePsi,
      ),
      _BikeMetricData(
        icon: Icons.sensors_rounded,
        label: snapshot.simulated ? 'SIMULAÇÃO' : 'Sensores',
        value: snapshot.connected ? '${snapshot.sensorBatteryPercent}' : '--',
        unit: '%',
        alert: snapshot.connected && snapshot.sensorBatteryPercent <= 15,
      ),
      _BikeMetricData(
        icon: Icons.route_outlined,
        label: 'Distância',
        value: snapshot.tripDistanceKm.toStringAsFixed(1),
        unit: 'km',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: _stripDecoration(),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  for (var index = 0; index < metrics.length; index++)
                    Padding(
                      padding: EdgeInsets.only(right: index == metrics.length - 1 ? 0 : 4),
                      child: _BikeMetricTile(data: metrics[index]),
                    ),
                ],
              ),
            ),
          ),
          if (warning != null) ...[
            const SizedBox(height: 4),
            Container(
              constraints: const BoxConstraints(maxWidth: 620),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 17, color: Colors.white),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      warning,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  BoxDecoration _stripDecoration() => BoxDecoration(
        color: Colors.black.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      );
}

class _BikeMetricData {
  const _BikeMetricData({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    this.featured = false,
    this.alert = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final bool featured;
  final bool alert;
}

class _BikeMetricTile extends StatelessWidget {
  const _BikeMetricTile({required this.data});

  final _BikeMetricData data;

  @override
  Widget build(BuildContext context) {
    final accent = data.alert
        ? Theme.of(context).colorScheme.error
        : data.featured
            ? Theme.of(context).colorScheme.primary
            : Colors.white70;
    return Container(
      constraints: BoxConstraints(minWidth: data.featured ? 136 : 124, minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: data.alert
            ? accent.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: data.alert
              ? accent.withValues(alpha: 0.28)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(data.icon, size: 17, color: accent),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    data.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: data.featured ? 18 : 14,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    data.unit,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
