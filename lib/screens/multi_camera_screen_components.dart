part of 'multi_camera_screen.dart';

class _CentralHeader extends StatelessWidget {
  const _CentralHeader({
    required this.total,
    required this.online,
    required this.disabled,
    required this.lastRefresh,
    required this.onScanPhone,
    required this.onAddPhone,
    required this.onAddRtsp,
  });

  final int total;
  final int online;
  final int disabled;
  final DateTime? lastRefresh;
  final VoidCallback onScanPhone;
  final VoidCallback onAddPhone;
  final VoidCallback onAddRtsp;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricChip(icon: Icons.videocam_outlined, label: '$total câmeras'),
                _MetricChip(icon: Icons.wifi_rounded, label: '$online online'),
                if (disabled > 0)
                  _MetricChip(
                    icon: Icons.pause_circle_outline_rounded,
                    label: '$disabled desativadas',
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              lastRefresh == null
                  ? 'Verificando disponibilidade…'
                  : 'Status automático a cada 15 s · atualizado ${_formatTime(lastRefresh!)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 19),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cada câmera é independente. Adicionar outra câmera não ativa contador. Uma futura contagem poderá ser habilitada por câmera, separadamente.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final wideActions = constraints.maxWidth >= 720;
                final scan = FilledButton.icon(
                  onPressed: onScanPhone,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Escanear QR'),
                  ),
                );
                final manual = OutlinedButton.icon(
                  onPressed: onAddPhone,
                  icon: const Icon(Icons.edit_rounded),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Adicionar manual'),
                  ),
                );
                final rtsp = OutlinedButton.icon(
                  onPressed: onAddRtsp,
                  icon: const Icon(Icons.router_outlined),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Adicionar RTSP'),
                  ),
                );
                if (wideActions) {
                  return Row(
                    children: [
                      Expanded(child: scan),
                      const SizedBox(width: 8),
                      Expanded(child: manual),
                      const SizedBox(width: 8),
                      Expanded(child: rtsp),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    scan,
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: manual),
                        const SizedBox(width: 8),
                        Expanded(child: rtsp),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraCard extends StatelessWidget {
  const _CameraCard({
    required this.camera,
    required this.status,
    required this.lastEvent,
    required this.onOpen,
    required this.onOpenWithSecond,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final CameraEndpoint camera;
  final CameraProbeResult? status;
  final MonitorEvent? lastEvent;
  final VoidCallback onOpen;
  final VoidCallback? onOpenWithSecond;
  final VoidCallback? onEdit;
  final VoidCallback? onToggle;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final online = camera.enabled && (status?.online ?? false);
    final statusColor = !camera.enabled
        ? scheme.outline
        : online
            ? const Color(0xFF4ADE80)
            : status == null
                ? scheme.primary
                : scheme.error;
    final statusText = !camera.enabled
        ? 'Desativada'
        : status == null
            ? 'Verificando…'
            : online
                ? 'Online'
                : 'Offline';
    final latency = status?.latency;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Icon(
                    switch (camera.type) {
                      CameraEndpointType.local => Icons.camera_alt_outlined,
                      CameraEndpointType.rtsp => Icons.router_outlined,
                      CameraEndpointType.remotePhone => Icons.phone_android_rounded,
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        camera.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            statusText,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (online && latency != null) ...[
                            const Text(' · '),
                            Text(
                              '${latency.inMilliseconds} ms',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (onEdit != null || onToggle != null || onDelete != null)
                  PopupMenuButton<String>(
                    tooltip: 'Opções da câmera',
                    onSelected: (value) {
                      if (value == 'edit') onEdit?.call();
                      if (value == 'toggle') onToggle?.call();
                      if (value == 'delete') onDelete?.call();
                    },
                    itemBuilder: (_) => [
                      if (onEdit != null)
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Editar / renomear'),
                        ),
                      if (onToggle != null)
                        PopupMenuItem(
                          value: 'toggle',
                          child: Text(camera.enabled ? 'Desativar' : 'Ativar'),
                        ),
                      if (onDelete != null)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Remover'),
                        ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              status?.message ?? 'Aguardando a primeira verificação.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: lastEvent == null
                  ? const Text('Último evento: nenhum registrado')
                  : Text(
                      'Último: ${ObjectFilterCatalog.singularNameForLabel(lastEvent!.label) ?? 'Detecção'} · ${_eventKind(lastEvent!.type)} · ${_formatDateTime(lastEvent!.createdAt)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
            const Spacer(),
            Row(
              children: [
                if (onOpenWithSecond != null) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: camera.enabled ? onOpenWithSecond : null,
                      icon: const Icon(Icons.video_collection_outlined),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Duas câmeras'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: FilledButton.icon(
                    onPressed: camera.enabled ? onOpen : null,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Monitorar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

String _eventKind(MonitorEventType type) => switch (type) {
      MonitorEventType.alert => 'alerta',
      MonitorEventType.entered => 'entrada',
      MonitorEventType.exited => 'saída',
      MonitorEventType.cameraObstructed => 'câmera obstruída',
      MonitorEventType.cameraMoved => 'câmera deslocada',
    };

String _formatTime(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';

String _formatDateTime(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
