import 'package:flutter/material.dart';

import '../models/device_telemetry.dart';
import '../models/remote_phone_status.dart';
import '../utils/storage_size_formatter.dart';

String remoteBikeCompactSummary(RemotePhoneStatus? status) {
  if (status == null) return 'Traseiro: telemetria…';
  final device = status.device;
  if (device == null) return 'Traseiro: sem telemetria';
  final parts = <String>[];
  if (device.batteryPercent != null) {
    parts.add('${device.batteryPercent}%');
  }
  if (device.batteryTemperatureC != null) {
    parts.add('${device.batteryTemperatureC!.toStringAsFixed(0)}°C');
  }
  if (parts.isEmpty) return 'Traseiro conectado';
  return 'Traseiro: ${parts.join(' • ')}';
}

class RemoteBikeWarningBanner extends StatelessWidget {
  const RemoteBikeWarningBanner({
    super.key,
    required this.status,
    required this.onTap,
  });

  final RemotePhoneStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final warnings = status.warnings();
    if (warnings.isEmpty) return const SizedBox.shrink();
    final critical = warnings.any(
      (item) => item.level == RemotePhoneWarningLevel.critical,
    );
    final scheme = Theme.of(context).colorScheme;
    final color = critical ? scheme.error : scheme.tertiary;
    final first = warnings.first;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 430),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.72)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                critical ? Icons.warning_rounded : Icons.info_outline_rounded,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  warnings.length == 1
                      ? first.title
                      : '${first.title} +${warnings.length - 1}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class RemoteBikeStatusPanel extends StatelessWidget {
  const RemoteBikeStatusPanel({
    super.key,
    required this.status,
    required this.sourceOnline,
  });

  final RemotePhoneStatus? status;
  final bool sourceOnline;

  @override
  Widget build(BuildContext context) {
    final current = status;
    final scheme = Theme.of(context).colorScheme;
    if (current == null) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Celular traseiro',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              _StatusCard(
                icon: sourceOnline
                    ? Icons.sync_rounded
                    : Icons.portable_wifi_off_rounded,
                title: sourceOnline
                    ? 'Aguardando telemetria'
                    : 'Sem conexão com o celular traseiro',
                subtitle: sourceOnline
                    ? 'A imagem já pode estar chegando. O painel de condições é atualizado separadamente a cada poucos segundos.'
                    : 'Confirme o hotspot/Wi-Fi local, o Modo Câmera e a chave de sessão.',
              ),
            ],
          ),
        ),
      );
    }

    final device = current.device;
    final warnings = current.warnings();
    final age = DateTime.now().difference(current.receivedAt);
    final seconds = age.isNegative ? 0 : age.inSeconds;

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.directions_bike_rounded, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Celular traseiro',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '${current.name} • atualizado há ${seconds}s',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusChip(
                icon: sourceOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                label: sourceOnline ? 'Imagem conectada' : 'Imagem desconectada',
              ),
              _StatusChip(
                icon: Icons.directions_bike_rounded,
                label: current.bikeMode
                    ? 'Bike • ${current.profileLabel}'
                    : 'Modo Bike desativado',
              ),
              if (device?.screenDimmedByBike == true)
                const _StatusChip(
                  icon: Icons.brightness_low_rounded,
                  label: 'Tela traseira reduzida',
                ),
            ],
          ),
          if (warnings.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...warnings.map((warning) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _WarningCard(warning: warning),
                )),
          ],
          const SizedBox(height: 8),
          _MetricSection(
            title: 'Energia',
            children: [
              _MetricRow(
                icon: device?.batteryCharging == true
                    ? Icons.battery_charging_full_rounded
                    : Icons.battery_5_bar_rounded,
                title: 'Bateria',
                value: device?.batteryPercent == null
                    ? 'Indisponível'
                    : '${device!.batteryPercent}%',
                detail: _chargingDetail(device),
              ),
              _MetricRow(
                icon: Icons.device_thermostat_rounded,
                title: 'Temperatura',
                value: device?.batteryTemperatureC == null
                    ? 'Indisponível'
                    : '${device!.batteryTemperatureC!.toStringAsFixed(1)} °C',
              ),
              _MetricRow(
                icon: Icons.brightness_6_rounded,
                title: 'Tela / brilho',
                value: device?.screenBrightnessPercent == null
                    ? 'Indisponível'
                    : '${device!.screenBrightnessPercent}%',
                detail: device?.screenInteractive == false
                    ? 'Tela não interativa'
                    : device?.automaticBrightness == true
                        ? 'Brilho automático'
                        : null,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _MetricSection(
            title: 'Processamento',
            children: [
              _MetricRow(
                icon: Icons.speed_rounded,
                title: 'CPU do Vigia IA',
                value: device?.appCpuPercent == null
                    ? 'Calculando…'
                    : '${device!.appCpuPercent!.toStringAsFixed(1)}%',
                detail: device?.processorCount == null
                    ? null
                    : '${device!.processorCount} núcleos disponíveis',
              ),
              _MetricRow(
                icon: Icons.videocam_outlined,
                title: 'Captura traseira',
                value: current.cameraFps == null
                    ? 'Indisponível'
                    : '${current.cameraFps!.toStringAsFixed(1)} FPS',
                detail: current.networkLatencyMs == null
                    ? null
                    : 'Resposta da telemetria: ${current.networkLatencyMs} ms',
              ),
              _MetricRow(
                icon: Icons.memory_rounded,
                title: 'Memória do app',
                value: device?.appMemoryUsedBytes == null
                    ? 'Indisponível'
                    : StorageSizeFormatter.formatBytes(device!.appMemoryUsedBytes!),
                detail: _memoryDetail(device),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _StatusCard(
            icon: Icons.shield_outlined,
            title: 'Conexão local',
            subtitle:
                'A imagem e esta telemetria trafegam pela rede local/hotspot entre os aparelhos. O painel não depende de nuvem.',
          ),
        ],
      ),
    );
  }

  static String? _chargingDetail(DeviceTelemetrySnapshot? device) {
    if (device == null || device.batteryCharging == null) return null;
    if (device.batteryCharging != true) return 'Usando bateria';
    final source = device.batteryPowerSource ?? 'Carregando';
    final current = device.batteryCurrentMa;
    if (current == null) return source;
    return '$source • ${current.toStringAsFixed(0)} mA';
  }

  static String? _memoryDetail(DeviceTelemetrySnapshot? device) {
    if (device == null ||
        device.memoryAvailableBytes == null ||
        device.memoryTotalBytes == null) {
      return null;
    }
    return '${StorageSizeFormatter.formatBytes(device.memoryAvailableBytes!)} livres de ${StorageSizeFormatter.formatBytes(device.memoryTotalBytes!)}';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

class _MetricSection extends StatelessWidget {
  const _MetricSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              ...children,
            ],
          ),
        ),
      );
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.icon,
    required this.title,
    required this.value,
    this.detail,
  });

  final IconData icon;
  final String title;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 21),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  if (detail != null) ...[
                    const SizedBox(height: 2),
                    Text(detail!, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      );
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.warning});

  final RemotePhoneWarning warning;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final critical = warning.level == RemotePhoneWarningLevel.critical;
    final color = critical ? scheme.error : scheme.tertiary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(critical ? Icons.warning_rounded : Icons.info_outline_rounded, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(warning.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(warning.detail),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(subtitle),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
