import 'package:flutter/material.dart';

import '../models/bike_sensor_snapshot.dart';

class BikeRideHud extends StatelessWidget {
  const BikeRideHud({
    super.key,
    required this.snapshot,
  });

  final BikeSensorSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final warning = snapshot.primaryWarning;
    final compact = MediaQuery.sizeOf(context).height < 500;
    final health = snapshot.health;
    final footerText = _footerText(snapshot);
    final warningColor = switch (health) {
      BikeSensorHealth.critical => Theme.of(context).colorScheme.error,
      BikeSensorHealth.disconnected => Theme.of(context).colorScheme.error,
      BikeSensorHealth.warning => Theme.of(context).colorScheme.tertiary,
      BikeSensorHealth.normal => Theme.of(context).colorScheme.primary,
    };

    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: compact ? 64 : 86,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _BikeHudMetric(
                      compact: compact,
                      icon: Icons.tire_repair_rounded,
                      label: 'Dianteiro',
                      value: snapshot.connected
                          ? '${snapshot.frontTirePsi.toStringAsFixed(0)} PSI'
                          : '-- PSI',
                      alert: snapshot.connected && snapshot.frontTirePsi < 34,
                    ),
                  ),
                  Align(
                    alignment: Alignment.topCenter,
                    child: _SpeedBadge(
                      compact: compact,
                      speedKmh: snapshot.connected ? snapshot.speedKmh : 0,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _BikeHudMetric(
                      compact: compact,
                      icon: Icons.tire_repair_rounded,
                      label: 'Traseiro',
                      value: snapshot.connected
                          ? '${snapshot.rearTirePsi.toStringAsFixed(0)} PSI'
                          : '-- PSI',
                      alert: snapshot.connected && snapshot.rearTirePsi < 34,
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.44),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      child: Text(
                        footerText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (warning != null) ...[
              const SizedBox(height: 5),
              Container(
                constraints: const BoxConstraints(maxWidth: 560),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 5 : 8),
                decoration: BoxDecoration(
                  color: warningColor.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(blurRadius: 10, color: Colors.black38),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 19),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        warning,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 10 : 12,
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
      ),
    );
  }
  static String _footerText(BikeSensorSnapshot snapshot) {
    final parts = <String>[];
    if (snapshot.simulated) parts.add('SIMULAÇÃO');
    if (!snapshot.connected) {
      parts.add('SEM CONEXÃO');
      return parts.join(' • ');
    }
    parts
      ..add('${snapshot.sensorBatteryPercent}%')
      ..add('${snapshot.tripDistanceKm.toStringAsFixed(1)} km');
    final temperature = snapshot.ambientTemperatureC;
    if (temperature != null) parts.add('${temperature.toStringAsFixed(0)} °C');
    return parts.join(' • ');
  }

}

class _SpeedBadge extends StatelessWidget {
  const _SpeedBadge({required this.speedKmh, required this.compact});

  final double speedKmh;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
        width: compact ? 78 : 92,
        padding: EdgeInsets.fromLTRB(8, compact ? 3 : 5, 8, compact ? 4 : 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.54),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              speedKmh.toStringAsFixed(0),
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 22 : 28,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'km/h',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
}

class _BikeHudMetric extends StatelessWidget {
  const _BikeHudMetric({
    required this.compact,
    required this.icon,
    required this.label,
    required this.value,
    required this.alert,
  });

  final bool compact;
  final IconData icon;
  final String label;
  final String value;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final background = alert
        ? Theme.of(context).colorScheme.error.withValues(alpha: 0.78)
        : Colors.black.withValues(alpha: 0.48);
    return Container(
      constraints: BoxConstraints(minWidth: compact ? 82 : 90, maxWidth: compact ? 94 : 104),
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 9, vertical: compact ? 5 : 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 15 : 17, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 10 : 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
