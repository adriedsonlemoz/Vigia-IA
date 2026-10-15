import 'package:flutter/material.dart';

import '../services/map_speed_policy.dart';

/// Indicadores passivos; nao iniciam GPS, sensores ou temporizadores.
class MapSystemHud extends StatelessWidget {
  const MapSystemHud({super.key, required this.batteryPercent,
    required this.gpsReady, required this.speedSource});
  final int? batteryPercent;
  final bool gpsReady;
  final String? speedSource;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final clock = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
    return Container(
      height: 25, padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(color: const Color(0xD6081D31),
        borderRadius: BorderRadius.circular(15)),
      child: Row(children: [
        Text(clock, style: const TextStyle(color: Colors.white,
          fontWeight: FontWeight.w900, fontSize: 12)),
        const Spacer(),
        Icon(gpsReady ? Icons.gps_fixed_rounded : Icons.gps_off_rounded,
          size: 14, color: gpsReady ? Colors.lightGreenAccent : Colors.orangeAccent),
        const SizedBox(width: 6),
        Text(speedSource ?? '--', style: const TextStyle(color: Colors.white70,
          fontSize: 10)),
        const SizedBox(width: 9),
        const Icon(Icons.battery_5_bar_rounded, size: 15, color: Colors.white),
        Text(batteryPercent == null ? '--%' : '$batteryPercent%',
          style: const TextStyle(color: Colors.white, fontSize: 11)),
      ]),
    );
  }
}

class MapFocusSpeedPill extends StatelessWidget {
  const MapFocusSpeedPill({super.key, required this.reading,
    required this.heading, required this.onTap});
  final MapSpeedReading? reading;
  final double? heading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xEB09273A),
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(16),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, children: [
            Text('${reading?.kmh.toStringAsFixed(1) ?? '--'} km/h',
              style: const TextStyle(color: Colors.white,
                fontSize: 20, fontWeight: FontWeight.w900)),
            Text('${reading?.source ?? 'Sem leitura'} · '
                '${heading == null ? 'rumo --' : '${heading!.round()}°'}',
              style: const TextStyle(color: Color(0xFFAAD1DE), fontSize: 10)),
          ]),
      ),
    ),
  );
}

