import 'package:flutter/material.dart';

import '../models/map_weather.dart';
import '../services/map_view_policy.dart';
import '../services/map_weather_policy.dart';

/// Faixa visual de telemetria do mapa: apenas renderiza leituras e repassa toques.
/// Não registra listeners nem inicializa sensores, GPS ou clima.
class MapTelemetryStrip extends StatelessWidget {
  const MapTelemetryStrip({
    required this.speedKmh,
    required this.speedSource,
    required this.altitudeMeters,
    required this.headingDegrees,
    required this.headingSource,
    required this.gpsAccuracyMeters,
    required this.gpsReadingAge,
    required this.gpsIsFresh,
    required this.gpsHasFix,
    required this.orientationMode,
    required this.weather,
    required this.onSpeedTap,
    required this.onAltitudeTap,
    required this.onCompassTap,
    required this.onGpsTap,
    required this.onWeatherTap,
    this.compact = false,
  });

  final double? speedKmh;
  final String? speedSource;
  final double? altitudeMeters;
  final double? headingDegrees;
  final MapHeadingSource headingSource;
  final double? gpsAccuracyMeters;
  final Duration? gpsReadingAge;
  final bool gpsIsFresh;
  final bool gpsHasFix;
  final MapOrientationMode orientationMode;
  final MapWeatherSnapshot weather;
  final VoidCallback onSpeedTap;
  final VoidCallback onAltitudeTap;
  final VoidCallback onCompassTap;
  final VoidCallback onGpsTap;
  final VoidCallback onWeatherTap;
  final bool compact;

  String _direction(double? degrees) {
    if (degrees == null || degrees.isNaN) return '--';
    const labels = ['N', 'NE', 'L', 'SE', 'S', 'SO', 'O', 'NO'];
    final normalized = ((degrees % 360) + 360) % 360;
    final index = ((normalized + 22.5) ~/ 45) % 8;
    return labels[index];
  }

  IconData _weatherIcon(int? code) => switch (code) {
        0 || 1 => Icons.wb_sunny_rounded,
        2 => Icons.wb_cloudy_rounded,
        3 || 45 || 48 => Icons.cloud_rounded,
        51 || 53 || 55 || 56 || 57 => Icons.grain_rounded,
        61 || 63 || 65 || 66 || 67 || 80 || 81 || 82 =>
          Icons.water_drop_rounded,
        71 || 73 || 75 || 77 || 85 || 86 => Icons.ac_unit_rounded,
        95 || 96 || 99 => Icons.thunderstorm_rounded,
        _ => Icons.device_thermostat_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final altitudeValue = altitudeMeters == null
        ? '--'
        : altitudeMeters!.toStringAsFixed(0);
    final gpsValue = gpsAccuracyMeters == null
        ? '--'
        : '±${gpsAccuracyMeters!.toStringAsFixed(0)}';
    final gpsStale = gpsHasFix && !gpsIsFresh;
    final gpsAgeText = gpsReadingAge == null
        ? null
        : gpsReadingAge!.inMinutes > 0
            ? '${gpsReadingAge!.inMinutes} min'
            : '${gpsReadingAge!.inSeconds} s';
    final temperature = MapWeatherPolicy.currentValue(
      weather, weather.temperatureC,
    );
    final weatherCode = MapWeatherPolicy.currentValue(
      weather, weather.weatherCode,
    );
    final weatherOutdated = weather.hasValues &&
        temperature == null && weatherCode == null;

    return Row(
      children: [
        Expanded(
          child: _MapTelemetryCard(
            icon: Icons.speed_rounded,
            value: speedKmh == null ? '--' : speedKmh!.toStringAsFixed(1),
            unit: speedKmh == null ? null : 'km/h',
            label: speedSource == 'Simulação' ? 'Vel. simulada' : 'Velocidade',
            source: speedSource,
            emphasized: true,
            onTap: onSpeedTap,
            tooltip: 'Velocidade: toque para ver detalhes da sessão.',
            compact: compact,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: _MapTelemetryCard(
            icon: Icons.height_rounded,
            value: altitudeValue,
            unit: altitudeMeters == null ? null : 'm',
            label: 'Altitude',
            onTap: onAltitudeTap,
            tooltip: 'Altitude: toque para ver fonte e precisão.',
            compact: compact,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: _MapTelemetryCard(
            icon: Icons.explore_rounded,
            value: _direction(headingDegrees),
            label: switch (headingSource) {
              MapHeadingSource.sensor => 'Sensor',
              MapHeadingSource.gps => 'Rumo GPS',
              MapHeadingSource.route => 'Rumo rota',
              MapHeadingSource.unavailable => 'Direção',
            },
            emphasized: orientationMode != MapOrientationMode.northUp,
            onTap: onCompassTap,
            tooltip:
                'Bússola: toque para ver direção, fonte e escolher Norte, Direção ou Rota.',
            compact: compact,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: _MapTelemetryCard(
            icon: Icons.gps_fixed_rounded,
            value: gpsValue,
            unit: gpsAccuracyMeters == null ? null : 'm',
            label: gpsStale ? 'GPS antigo' : 'GPS',
            source: gpsStale
                ? gpsAgeText == null ? 'horário inválido' : 'há $gpsAgeText'
                : null,
            onTap: onGpsTap,
            tooltip: gpsStale
                ? 'Amostra GPS inválida ou antiga. A precisão anterior não descreve a posição atual.'
                : 'GPS: toque para ver posição e qualidade da leitura.', 
            compact: compact,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: _MapTelemetryCard(
            icon: _weatherIcon(weatherCode?.value),
            value: temperature == null
                ? '--'
                : temperature.value.toStringAsFixed(0),
            unit: temperature == null ? null : '°C',
            label: weatherOutdated ? 'Clima antigo'
                : weather.origin == MapWeatherOrigin.unavailable
                    ? 'Clima'
                    : 'Clima · ${weather.origin.label}',
            emphasized: weatherOutdated,
            onTap: onWeatherTap,
            tooltip:
                'Clima: toque para ver sensores ESP32, dados online e fontes.',
            compact: compact,
          ),
        ),
      ],
    );
  }
}

class _MapTelemetryCard extends StatelessWidget {
  const _MapTelemetryCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.compact,
    this.unit,
    this.source,
    this.emphasized = false,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final String value;
  final String? unit;
  final String? source;
  final String label;
  final bool compact;
  final bool emphasized;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final background = emphasized
        ? const Color(0xF500625F)
        : const Color(0xF2081D31);
    const foreground = Colors.white;
    const iconColor = Color(0xFF16BDF8);

    Widget card = Material(
      elevation: 2,
      color: background,
      borderRadius: BorderRadius.circular(13),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 4 : 5,
            vertical: compact ? 3 : 4,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: compact ? 13 : 17, color: iconColor),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: TextStyle(
                        color: foreground.withValues(alpha: 0.72),
                        fontSize: compact ? 7.5 : 9,
                        height: 1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: value,
                        style: TextStyle(
                          color: foreground,
                          fontSize: compact ? 15 : 20,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (unit != null) ...[
                        const TextSpan(text: ' '),
                        TextSpan(
                          text: unit,
                          style: TextStyle(
                            color: foreground.withValues(alpha: 0.74),
                            fontSize: compact ? 7 : 9,
                            height: 1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                  maxLines: 1,
                  textAlign: TextAlign.center,
                ),
              ),
              if (source != null && !compact)
                Text(source!, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFFB4DAE4), fontSize: 8)),
            ],
          ),
        ),
      ),
    );
    if (tooltip != null) card = Tooltip(message: tooltip!, child: card);
    return card;
  }
}

