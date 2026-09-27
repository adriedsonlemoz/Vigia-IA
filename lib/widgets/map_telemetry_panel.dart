import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/map_weather.dart';
import '../services/map_telemetry_policy.dart';
import '../services/map_weather_policy.dart';

class MapTelemetryPanelHeader extends StatelessWidget {
  const MapTelemetryPanelHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: scheme.onPrimaryContainer),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}

class MapTelemetryMetricTile extends StatelessWidget {
  const MapTelemetryMetricTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.detail,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final String? detail;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: emphasized
            ? scheme.primaryContainer.withValues(alpha: 0.58)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: emphasized
              ? scheme.primary.withValues(alpha: 0.22)
              : scheme.outlineVariant.withValues(alpha: 0.42),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17, color: scheme.primary),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          if (detail != null && detail!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              detail!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class MapTelemetryMetricGrid extends StatelessWidget {
  const MapTelemetryMetricGrid({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 3 : 2;
        final width =
            (constraints.maxWidth - ((columns - 1) * 8)) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class MapSpeedDial extends StatelessWidget {
  const MapSpeedDial({
    super.key,
    required this.speedKmh,
    this.averageKmh,
    this.maximumReferenceKmh,
  });

  final double? speedKmh;
  final double? averageKmh;
  final double? maximumReferenceKmh;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final speed = speedKmh?.clamp(0, 120).toDouble();
    final reference = math.max(
      40.0,
      math.max(maximumReferenceKmh ?? 0, speed ?? 0) * 1.15,
    );
    return SizedBox(
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _SpeedDialPainter(
                progress: speed == null ? 0 : (speed / reference).clamp(0, 1),
                averageProgress: averageKmh == null
                    ? null
                    : (averageKmh! / reference).clamp(0, 1),
                trackColor: scheme.surfaceContainerHighest,
                valueColor: scheme.primary,
                averageColor: scheme.secondary,
              ),
            ),
          ),
          Positioned(
            top: 54,
            child: Column(
              children: [
                Text(
                  speed == null ? '--' : speed.toStringAsFixed(1),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                ),
                Text(
                  'km/h',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
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

class _SpeedDialPainter extends CustomPainter {
  const _SpeedDialPainter({
    required this.progress,
    required this.averageProgress,
    required this.trackColor,
    required this.valueColor,
    required this.averageColor,
  });

  final double progress;
  final double? averageProgress;
  final Color trackColor;
  final Color valueColor;
  final Color averageColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.92);
    final radius = math.min(size.width * 0.34, size.height * 0.68);
    final rect = Rect.fromCircle(center: center, radius: radius);
    const start = math.pi;
    const sweep = math.pi;
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 14;
    final value = Paint()
      ..color = valueColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 14;
    canvas.drawArc(rect, start, sweep, false, track);
    canvas.drawArc(rect, start, sweep * progress, false, value);

    final average = averageProgress;
    if (average != null) {
      final angle = start + sweep * average;
      final outer = Offset(
        center.dx + math.cos(angle) * (radius + 7),
        center.dy + math.sin(angle) * (radius + 7),
      );
      final inner = Offset(
        center.dx + math.cos(angle) * (radius - 12),
        center.dy + math.sin(angle) * (radius - 12),
      );
      final marker = Paint()
        ..color = averageColor
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(inner, outer, marker);
    }
  }

  @override
  bool shouldRepaint(covariant _SpeedDialPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.averageProgress != averageProgress ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.valueColor != valueColor ||
      oldDelegate.averageColor != averageColor;
}

class MapGpsQualityIndicator extends StatelessWidget {
  const MapGpsQualityIndicator({
    super.key,
    required this.quality,
    required this.accuracyMeters,
  });

  final MapGpsQuality quality;
  final double? accuracyMeters;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.satellite_alt_rounded, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Qualidade da localização',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              Text(
                quality.label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: quality.progress,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            accuracyMeters == null
                ? 'Precisão horizontal não informada pelo GPS.'
                : 'Raio informado pelo GPS: ±${accuracyMeters!.toStringAsFixed(1)} m.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class MapElevationProfileChart extends StatelessWidget {
  const MapElevationProfileChart({
    super.key,
    required this.valuesMeters,
  });

  final List<double> valuesMeters;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (valuesMeters.length < 2) {
      return Container(
        height: 110,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.36),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          'O perfil aparece conforme o percurso acumula leituras válidas.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
      );
    }
    return Container(
      height: 125,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(18),
      ),
      child: CustomPaint(
        painter: _ElevationPainter(
          values: valuesMeters,
          lineColor: scheme.primary,
          fillColor: scheme.primary.withValues(alpha: 0.12),
          guideColor: scheme.outlineVariant,
        ),
      ),
    );
  }
}

class _ElevationPainter extends CustomPainter {
  const _ElevationPainter({
    required this.values,
    required this.lineColor,
    required this.fillColor,
    required this.guideColor,
  });

  final List<double> values;
  final Color lineColor;
  final Color fillColor;
  final Color guideColor;

  @override
  void paint(Canvas canvas, Size size) {
    var minimum = values.first;
    var maximum = values.first;
    for (final value in values.skip(1)) {
      if (value < minimum) minimum = value;
      if (value > maximum) maximum = value;
    }
    final range = math.max(1.0, maximum - minimum);
    final guide = Paint()
      ..color = guideColor.withValues(alpha: 0.42)
      ..strokeWidth = 1;
    for (var i = 1; i <= 2; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), guide);
    }

    final path = Path();
    for (var index = 0; index < values.length; index++) {
      final x = values.length == 1
          ? 0.0
          : size.width * index / (values.length - 1);
      final normalized = (values[index] - minimum) / range;
      final y = size.height - (normalized * size.height * 0.82) - 5;
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = fillColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ElevationPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.fillColor != fillColor;
}

class MapCompassDial extends StatelessWidget {
  const MapCompassDial({
    super.key,
    required this.headingDegrees,
    required this.directionLabel,
  });

  final double? headingDegrees;
  final String directionLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 210,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(200, 200),
            painter: _CompassPainter(
              headingDegrees: headingDegrees,
              ringColor: scheme.outlineVariant,
              primaryColor: scheme.primary,
              textColor: scheme.onSurface,
            ),
          ),
          Positioned(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  directionLabel,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                Text(
                  headingDegrees == null
                      ? '--'
                      : '${headingDegrees!.toStringAsFixed(0)}°',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
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

class _CompassPainter extends CustomPainter {
  const _CompassPainter({
    required this.headingDegrees,
    required this.ringColor,
    required this.primaryColor,
    required this.textColor,
  });

  final double? headingDegrees;
  final Color ringColor;
  final Color primaryColor;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 16;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = ringColor.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (var degree = 0; degree < 360; degree += 30) {
      final angle = (degree - 90) * math.pi / 180;
      final major = degree % 90 == 0;
      final outer = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      final innerRadius = radius - (major ? 12 : 7);
      final inner = Offset(
        center.dx + math.cos(angle) * innerRadius,
        center.dy + math.sin(angle) * innerRadius,
      );
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..color = major ? textColor : ringColor
          ..strokeWidth = major ? 2.2 : 1.2,
      );
    }

    const labels = <String>['N', 'L', 'S', 'O'];
    for (var index = 0; index < 4; index++) {
      final angle = (index * 90 - 90) * math.pi / 180;
      final position = Offset(
        center.dx + math.cos(angle) * (radius - 28),
        center.dy + math.sin(angle) * (radius - 28),
      );
      final painter = TextPainter(
        text: TextSpan(
          text: labels[index],
          style: TextStyle(
            color: index == 0 ? primaryColor : textColor,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        position - Offset(painter.width / 2, painter.height / 2),
      );
    }

    final heading = headingDegrees;
    if (heading == null || !heading.isFinite) return;
    final angle = (heading - 90) * math.pi / 180;
    final tip = Offset(
      center.dx + math.cos(angle) * (radius - 40),
      center.dy + math.sin(angle) * (radius - 40),
    );
    final opposite = Offset(
      center.dx - math.cos(angle) * 24,
      center.dy - math.sin(angle) * 24,
    );
    canvas.drawLine(
      opposite,
      tip,
      Paint()
        ..color = primaryColor
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(center, 6, Paint()..color = primaryColor);
  }

  @override
  bool shouldRepaint(covariant _CompassPainter oldDelegate) =>
      oldDelegate.headingDegrees != headingDegrees ||
      oldDelegate.ringColor != ringColor ||
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.textColor != textColor;
}

class MapWeatherAssessmentBanner extends StatelessWidget {
  const MapWeatherAssessmentBanner({
    super.key,
    required this.assessment,
  });

  final MapRideWeatherAssessment assessment;

  IconData get _icon => switch (assessment.level) {
        MapRideWeatherLevel.unavailable => Icons.cloud_off_rounded,
        MapRideWeatherLevel.favorable => Icons.directions_bike_rounded,
        MapRideWeatherLevel.attention => Icons.warning_amber_rounded,
        MapRideWeatherLevel.critical => Icons.thunderstorm_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final emphasized = assessment.level == MapRideWeatherLevel.attention ||
        assessment.level == MapRideWeatherLevel.critical;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: emphasized
            ? scheme.errorContainer.withValues(alpha: 0.55)
            : scheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _icon,
            color: emphasized ? scheme.onErrorContainer : scheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${assessment.level.label} · ${assessment.summary}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                if (assessment.detail != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    assessment.detail!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MapWeatherForecastStrip extends StatelessWidget {
  const MapWeatherForecastStrip({
    super.key,
    required this.hours,
  });

  final List<MapWeatherForecastHour> hours;

  static IconData iconForCode(int? code) => switch (code) {
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

  String _time(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:00';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (hours.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Text(
          'A previsão horária aparece após uma atualização online válida.',
        ),
      );
    }
    return SizedBox(
      height: 154,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: hours.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final hour = hours[index];
          final condition = MapWeatherPolicy.conditionLabel(hour.weatherCode);
          return Container(
            width: 108,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.48),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _time(hour.time),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 7),
                Icon(iconForCode(hour.weatherCode), size: 24),
                const Spacer(),
                Text(
                  hour.temperatureC == null
                      ? '--'
                      : '${hour.temperatureC!.round()}°',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                Text(
                  hour.precipitationProbabilityPercent == null
                      ? (condition ?? '--')
                      : 'Chuva ${hour.precipitationProbabilityPercent!.round()}%',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                if (hour.windSpeedKmh != null)
                  Text(
                    'Vento ${hour.windSpeedKmh!.round()} km/h',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
