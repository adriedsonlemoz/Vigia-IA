import 'package:flutter/material.dart';

import '../models/device_telemetry.dart';
import '../models/session_status.dart';
import '../utils/storage_size_formatter.dart';

class SessionStatusPanel extends StatelessWidget {
  const SessionStatusPanel({super.key, required this.data});

  final SessionStatusData data;

  @override
  Widget build(BuildContext context) {
    final remote = data.remotePhone;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Row(
            children: [
              const Icon(Icons.monitor_heart_outlined),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Status da sessão',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
              _StateBadge(state: data.health.state),
            ],
          ),
          const SizedBox(height: 12),
          _SessionHealthCard(data: data),
          const SizedBox(height: 12),
          _VideoSummaryCard(data: data),
          const SizedBox(height: 12),
          _DeviceSection(
            title: 'Este celular',
            subtitle: data.aiDevice == 'Este celular'
                ? 'Executa a IA desta sessão.'
                : 'Acompanha a sessão.',
            icon: Icons.smartphone_rounded,
            telemetry: data.localDevice,
            connectionFallback: data.sourceConnection,
          ),
          const SizedBox(height: 12),
          _DeviceSection(
            title: remote?.name ?? 'Celular remoto',
            subtitle: remote == null
                ? 'Não há celular remoto ativo nesta fonte.'
                : 'Fornece a imagem para esta sessão.',
            icon: Icons.phone_android_rounded,
            telemetry: remote?.device,
            connectionFallback: remote == null
                ? 'Não utilizado'
                : data.sourceOnline
                    ? 'Rede local conectada'
                    : 'Rede local sem imagem',
            unavailable: remote == null,
          ),
        ],
      ),
    );
  }
}

class VideoSessionDetailsPanel extends StatelessWidget {
  const VideoSessionDetailsPanel({super.key, required this.data});

  final SessionStatusData data;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            const Row(
              children: [
                Icon(Icons.videocam_outlined),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Vídeo e processamento',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _MetricGroup(
              children: [
                _MetricRow(label: 'Fonte da imagem', value: data.imageSource),
                _MetricRow(label: 'IA executada em', value: data.aiDevice),
                _MetricRow(label: 'Conexão da fonte', value: data.sourceConnection),
                _MetricRow(
                  label: 'FPS recebido',
                  value: '${data.receivedFps.toStringAsFixed(1)} FPS',
                  detail: 'Meta aproximada: ${data.expectedReceivedFps.toStringAsFixed(1)} FPS',
                ),
                _MetricRow(
                  label: 'FPS analisado',
                  value: '${data.analyzedFps.toStringAsFixed(1)} FPS',
                ),
                _MetricRow(label: 'Resolução recebida', value: data.frameResolution),
                _MetricRow(label: 'Resolução analisada', value: data.analysisResolution),
                _MetricRow(
                  label: 'Inferência',
                  value: data.inferenceMs == null
                      ? '—'
                      : '${data.inferenceMs!.toStringAsFixed(0)} ms',
                ),
                _MetricRow(
                  label: 'Atraso do frame',
                  value: data.frameDelayMs == null ? '—' : '${data.frameDelayMs} ms',
                  detail: 'Da captura até a chegada neste celular',
                ),
                _MetricRow(
                  label: 'Idade atual da imagem',
                  value: _durationText(data.frameAgeMs),
                  detail: 'Tempo desde o último frame recebido',
                ),
                _MetricRow(
                  label: 'Latência de rede',
                  value: data.networkLatencyMs == null
                      ? 'Não se aplica / indisponível'
                      : '${data.networkLatencyMs} ms',
                ),
                _MetricRow(label: 'Frames recebidos', value: '${data.framesReceived}'),
                _MetricRow(label: 'Frames analisados', value: '${data.framesAnalyzed}'),
                _MetricRow(
                  label: 'Frames descartados',
                  value: '${data.framesDropped}',
                  detail: 'Total não enviado à IA nesta sessão.',
                ),
                _MetricRow(
                  label: 'Descartados por IA ocupada',
                  value: '${data.framesDroppedProcessing}',
                  detail: '${data.processingDropPercent.toStringAsFixed(1)}% dos frames recebidos',
                ),
                _MetricRow(
                  label: 'Ignorados por otimização',
                  value: '${data.framesSkippedOptimization}',
                  detail: 'Pulos intencionais do filtro de movimento; não contam como falha de desempenho.',
                ),
              ],
            ),
          ],
        ),
      );
}

class _VideoSummaryCard extends StatelessWidget {
  const _VideoSummaryCard({required this.data});

  final SessionStatusData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (_) => FractionallySizedBox(
            heightFactor: 0.78,
            child: VideoSessionDetailsPanel(data: data),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.videocam_outlined, size: 20),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.imageSource,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      data.compactVideoSummary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceSection extends StatelessWidget {
  const _DeviceSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.telemetry,
    required this.connectionFallback,
    this.unavailable = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final DeviceTelemetrySnapshot? telemetry;
  final String connectionFallback;
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    final device = telemetry;
    final connection = device?.connectionType?.trim().isNotEmpty == true
        ? device!.connectionType!
        : connectionFallback;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 19),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (unavailable)
          const _MetricGroup(
            children: [
              _MetricRow(label: 'Estado', value: 'Não utilizado nesta sessão'),
            ],
          )
        else
          _MetricGroup(
            children: [
              _MetricRow(
                label: 'Bateria',
                value: device?.batteryPercent == null ? '—' : '${device!.batteryPercent}%',
              ),
              _MetricRow(
                label: 'Carga',
                value: _chargingText(device),
                detail: device?.batteryCurrentMa == null
                    ? null
                    : '${device!.batteryCurrentMa!.toStringAsFixed(0)} mA',
              ),
              _MetricRow(
                label: 'Temperatura',
                value: device?.batteryTemperatureC == null
                    ? '—'
                    : '${device!.batteryTemperatureC!.toStringAsFixed(1)} °C',
              ),
              _MetricRow(
                label: 'Brilho',
                value: device?.screenBrightnessPercent == null
                    ? '—'
                    : '${device!.screenBrightnessPercent}%',
                detail: device?.automaticBrightness == true ? 'Automático' : null,
              ),
              _MetricRow(
                label: 'CPU do Vigia IA',
                value: device?.appCpuPercent == null
                    ? 'Calculando…'
                    : '${device!.appCpuPercent!.toStringAsFixed(1)}%',
                detail: device?.processorCount == null
                    ? null
                    : '${device!.processorCount} núcleos disponíveis',
              ),
              _MetricRow(
                label: 'RAM do app',
                value: device?.appMemoryUsedBytes == null
                    ? '—'
                    : StorageSizeFormatter.formatBytes(device!.appMemoryUsedBytes!),
                detail: _ramDetail(device),
              ),
              _MetricRow(
                label: 'Armazenamento livre',
                value: device?.freeStorageBytes == null
                    ? '—'
                    : StorageSizeFormatter.formatBytes(device!.freeStorageBytes!),
                detail: device?.totalStorageBytes == null
                    ? null
                    : 'de ${StorageSizeFormatter.formatBytes(device!.totalStorageBytes!)}',
              ),
              _MetricRow(label: 'Conexão', value: connection),
            ],
          ),
      ],
    );
  }

  static String _chargingText(DeviceTelemetrySnapshot? device) {
    final current = device;
    if (current?.batteryCharging == null) return '—';
    if (current!.batteryCharging != true) return 'Na bateria';
    return current.batteryPowerSource ?? 'Carregando';
  }

  static String? _ramDetail(DeviceTelemetrySnapshot? device) {
    final current = device;
    if (current?.memoryAvailableBytes == null || current?.memoryTotalBytes == null) {
      return null;
    }
    return '${StorageSizeFormatter.formatBytes(current!.memoryAvailableBytes!)} livres de ${StorageSizeFormatter.formatBytes(current.memoryTotalBytes!)}';
  }
}

class _MetricGroup extends StatelessWidget {
  const _MetricGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.18),
          ),
        ),
        child: Column(
          children: [
            for (var index = 0; index < children.length; index++) ...[
              children[index],
              if (index != children.length - 1)
                Divider(
                  height: 1,
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
                ),
            ],
          ],
        ),
      );
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value, this.detail});

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      detail!,
                      textAlign: TextAlign.end,
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

class _SessionHealthCard extends StatelessWidget {
  const _SessionHealthCard({required this.data});

  final SessionStatusData data;

  @override
  Widget build(BuildContext context) {
    final health = data.health;
    final color = _healthColor(context, health.state);
    final primaryIssue = health.primaryIssue;
    final displayedIssues = <SessionHealthIssue>[
      if (primaryIssue != null) primaryIssue,
      ...health.issues
          .where((issue) => !identical(issue, primaryIssue))
          .take(2),
    ];
    final incidents = data.healthIncidents.take(4).toList(growable: false);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_healthIcon(health.state), size: 20, color: color),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Saúde da sessão',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                health.state.label,
                style: TextStyle(fontWeight: FontWeight.w900, color: color),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(health.summary, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Gargalo provável', style: Theme.of(context).textTheme.bodySmall),
              const Spacer(),
              Flexible(
                child: Text(
                  health.bottleneck.label,
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          if (displayedIssues.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final issue in displayedIssues)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: _healthColor(context, issue.state)),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        '${issue.title}: ${issue.detail}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (incidents.isNotEmpty) ...[
            Divider(
              height: 18,
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.16),
            ),
            Text(
              'Ocorrências recentes',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            for (final incident in incidents)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${_clockText(incident.occurredAt)} • ${incident.title}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.state});

  final SessionHealthState state;

  @override
  Widget build(BuildContext context) {
    final color = _healthColor(context, state);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        state.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

Color _healthColor(BuildContext context, SessionHealthState state) => switch (state) {
      SessionHealthState.healthy => Colors.green,
      SessionHealthState.attention => Colors.amber.shade800,
      SessionHealthState.unstable => Colors.deepOrange,
      SessionHealthState.disconnected => Theme.of(context).colorScheme.error,
    };

IconData _healthIcon(SessionHealthState state) => switch (state) {
      SessionHealthState.healthy => Icons.check_circle_outline_rounded,
      SessionHealthState.attention => Icons.warning_amber_rounded,
      SessionHealthState.unstable => Icons.sync_problem,
      SessionHealthState.disconnected => Icons.link_off,
    };

String _durationText(int? milliseconds) {
  if (milliseconds == null) return '—';
  if (milliseconds < 1000) return '$milliseconds ms';
  final seconds = milliseconds / 1000;
  return '${seconds.toStringAsFixed(seconds >= 10 ? 0 : 1)} s';
}

String _clockText(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';
