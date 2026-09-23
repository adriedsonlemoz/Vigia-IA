part of 'monitor_screen.dart';

class _CameraPaneLabel extends StatelessWidget {
  const _CameraPaneLabel({
    required this.title,
    required this.detail,
    required this.active,
  });

  final String title;
  final String detail;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 230),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.76),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF69D59C) : const Color(0xFFFFB4AB),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _CompactMonitorTopHud extends StatelessWidget {
  const _CompactMonitorTopHud({
    required this.sourceStatus,
    required this.detectionCount,
    required this.bikeSnapshot,
    required this.approach,
    required this.deviceStrip,
    required this.fillPreview,
    required this.fullscreen,
    required this.fullscreenChanging,
    required this.voiceEnabled,
    required this.detectionDelayed,
    required this.processing,
    required this.onClose,
    required this.onFullscreen,
    required this.onToggleFill,
    required this.onToggleVoice,
    required this.menu,
  });

  final VideoSourceStatus sourceStatus;
  final int detectionCount;
  final BikeSensorSnapshot? bikeSnapshot;
  final BikeApproachStatus approach;
  final Widget deviceStrip;
  final bool fillPreview;
  final bool fullscreen;
  final bool fullscreenChanging;
  final bool voiceEnabled;
  final bool detectionDelayed;
  final bool processing;
  final VoidCallback onClose;
  final VoidCallback? onFullscreen;
  final VoidCallback onToggleFill;
  final VoidCallback onToggleVoice;
  final Widget menu;

  @override
  Widget build(BuildContext context) {
    final streaming = sourceStatus.state == VideoSourceState.streaming;
    final title = sourceStatus.message ?? (streaming ? 'Ao vivo' : 'Monitor');
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        return Material(
          color: Colors.black.withValues(alpha: 0.50),
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Sair do monitoramento',
                      onPressed: onClose,
                      icon: const Icon(Icons.arrow_back_rounded),
                      visualDensity: VisualDensity.compact,
                    ),
                    _StatusDot(active: streaming),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    if (compact)
                      IconButton(
                        tooltip: 'Encerrar monitoramento',
                        onPressed: onClose,
                        icon: const Icon(Icons.stop_circle_outlined),
                        visualDensity: VisualDensity.compact,
                      )
                    else
                      TextButton.icon(
                        onPressed: onClose,
                        icon: const Icon(Icons.stop_circle_outlined, size: 18),
                        label: const Text('Encerrar'),
                      ),
                    if (!fullscreen)
                      IconButton(
                        tooltip: 'Tela inteira',
                        onPressed: fullscreenChanging ? null : onFullscreen,
                        icon: const Icon(Icons.fullscreen_rounded),
                        visualDensity: VisualDensity.compact,
                      )
                    else
                      IconButton(
                        tooltip: 'Sair da tela inteira',
                        onPressed: fullscreenChanging ? null : onFullscreen,
                        icon: const Icon(Icons.fullscreen_exit_rounded),
                        visualDensity: VisualDensity.compact,
                      ),
                    IconButton(
                      tooltip: voiceEnabled ? 'Desativar voz' : 'Ativar voz',
                      onPressed: onToggleVoice,
                      icon: Icon(
                        voiceEnabled
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    menu,
                  ],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _HudPill(
                        icon: streaming
                            ? Icons.fiber_manual_record_rounded
                            : Icons.videocam_off_outlined,
                        label: title,
                        active: streaming,
                      ),
                      _HudPill(
                        icon: Icons.psychology_alt_outlined,
                        label: detectionDelayed
                            ? 'IA atrasada'
                            : processing
                            ? 'IA analisando'
                            : 'IA ativa',
                        active: true,
                      ),
                      _HudPill(
                        icon: Icons.radar_rounded,
                        label: 'Detectados $detectionCount',
                        active: detectionCount > 0,
                      ),
                      _HudPill(
                        icon: fillPreview
                            ? Icons.fullscreen_rounded
                            : Icons.fit_screen_rounded,
                        label: fillPreview ? 'Preencher' : 'Ajustar',
                        active: fillPreview,
                        onTap: onToggleFill,
                      ),
                    ],
                  ),
                ),
                if (bikeSnapshot != null) ...[
                  const SizedBox(height: 6),
                  BikeRideHud(snapshot: bikeSnapshot!),
                ],
                if (approach.visible) ...[
                  const SizedBox(height: 6),
                  BikeApproachBanner(status: approach),
                ],
                const SizedBox(height: 6),
                deviceStrip,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DeviceStatusStrip extends StatelessWidget {
  const _DeviceStatusStrip({
    required this.localDevice,
    required this.remoteStatus,
    required this.sourceType,
    required this.sourceStatus,
    required this.receiverActive,
    required this.networkLatencyMs,
    required this.onTap,
    this.secondarySourceType,
    this.secondarySourceStatus,
    this.secondaryRemoteStatus,
    this.secondaryLabel,
    this.embedded = false,
  });

  final DeviceTelemetrySnapshot? localDevice;
  final RemotePhoneStatus? remoteStatus;
  final VideoSourceType sourceType;
  final VideoSourceStatus sourceStatus;
  final bool receiverActive;
  final int? networkLatencyMs;
  final VoidCallback onTap;
  final VideoSourceType? secondarySourceType;
  final VideoSourceStatus? secondarySourceStatus;
  final RemotePhoneStatus? secondaryRemoteStatus;
  final String? secondaryLabel;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final remoteSource =
        sourceType == VideoSourceType.remotePhone ||
        sourceType == VideoSourceType.esp32;
    final transmitterTelemetry = remoteSource
        ? remoteStatus?.device
        : localDevice;
    final transmitterOnline = remoteSource
        ? sourceStatus.state == VideoSourceState.streaming &&
              remoteStatus?.online != false &&
              remoteStatus?.isStale() != true
        : sourceStatus.state == VideoSourceState.streaming;
    final transmitterLabel = switch (sourceType) {
      VideoSourceType.remotePhone => 'Transmissor',
      VideoSourceType.localCamera => 'Câmera local',
      VideoSourceType.rtsp => 'Câmera RTSP',
      VideoSourceType.esp32 => 'ESP32',
    };
    final latency = remoteSource && networkLatencyMs != null
        ? '$networkLatencyMs ms'
        : null;
    final secondaryType = secondarySourceType;
    final secondaryOnline =
        secondaryType != null &&
        secondarySourceStatus?.state == VideoSourceState.streaming &&
        ((secondaryType != VideoSourceType.remotePhone &&
                secondaryType != VideoSourceType.esp32) ||
            (secondaryRemoteStatus?.online != false &&
                secondaryRemoteStatus?.isStale() != true));
    final secondaryTelemetry = switch (secondaryType) {
      VideoSourceType.localCamera => localDevice,
      VideoSourceType.remotePhone => secondaryRemoteStatus?.device,
      VideoSourceType.rtsp => null,
      VideoSourceType.esp32 => secondaryRemoteStatus?.device,
      null => null,
    };
    final secondaryDetail =
        (secondaryType == VideoSourceType.remotePhone ||
                secondaryType == VideoSourceType.esp32) &&
            secondaryRemoteStatus?.networkLatencyMs != null
        ? '${secondaryRemoteStatus!.networkLatencyMs} ms'
        : secondaryOnline
        ? 'Imagem ativa'
        : 'Sem imagem';

    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: embedded
          ? scheme.surfaceContainerLow
          : Colors.black.withValues(alpha: 0.76),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(embedded ? 16 : 8),
        side: embedded
            ? BorderSide(color: scheme.primary.withValues(alpha: 0.28))
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: embedded ? 52 : 40,
          child: Row(
            children: [
              Expanded(
                child: _DeviceStatusItem(
                  label: embedded ? 'Receptor (IA)' : 'Receptor',
                  telemetry: localDevice,
                  online: receiverActive,
                  detail: receiverActive ? 'IA ativa' : 'Verificando',
                  showBattery: true,
                ),
              ),
              Container(
                width: 1,
                height: 24,
                color: Colors.white.withValues(alpha: 0.18),
              ),
              Expanded(
                child: _DeviceStatusItem(
                  label: transmitterLabel,
                  telemetry: sourceType == VideoSourceType.rtsp
                      ? null
                      : transmitterTelemetry,
                  online: transmitterOnline,
                  detail:
                      latency ??
                      (transmitterOnline ? 'Imagem ativa' : 'Sem imagem'),
                  showBattery: remoteSource,
                ),
              ),
              if (secondaryType != null) ...[
                Container(
                  width: 1,
                  height: 24,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
                Expanded(
                  child: _DeviceStatusItem(
                    label: secondaryLabel ?? 'Câmera 2',
                    telemetry: secondaryTelemetry,
                    online: secondaryOnline,
                    detail: secondaryDetail,
                    showBattery:
                        secondaryType == VideoSourceType.remotePhone ||
                        secondaryType == VideoSourceType.esp32,
                  ),
                ),
              ],
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.chevron_right_rounded, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceStatusItem extends StatelessWidget {
  const _DeviceStatusItem({
    required this.label,
    required this.telemetry,
    required this.online,
    required this.detail,
    required this.showBattery,
  });

  final String label;
  final DeviceTelemetrySnapshot? telemetry;
  final bool online;
  final String detail;
  final bool showBattery;

  @override
  Widget build(BuildContext context) {
    final battery = telemetry?.batteryPercent;
    final charging = telemetry?.batteryCharging == true;
    final statusColor = online
        ? const Color(0xFF69D59C)
        : const Color(0xFFFFB4AB);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          if (showBattery) ...[
            Icon(
              charging
                  ? Icons.battery_charging_full_rounded
                  : Icons.battery_5_bar_rounded,
              size: 15,
              color: battery == null ? Colors.white54 : Colors.white,
            ),
            const SizedBox(width: 2),
            Text(
              battery == null ? '—' : '$battery%',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            ),
          ] else
            const Icon(
              Icons.videocam_outlined,
              size: 16,
              color: Colors.white70,
            ),
        ],
      ),
    );
  }
}

class _MonitorActionButton extends StatelessWidget {
  const _MonitorActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 64,
            height: 50,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: scheme.primary, size: 19),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SourceOptionTile extends StatelessWidget {
  const _SourceOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary.withValues(alpha: 0.10) : scheme.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.52)
                  : scheme.outline.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(subtitle),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HudPill extends StatelessWidget {
  const _HudPill({
    required this.icon,
    required this.label,
    required this.active,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = active
        ? Theme.of(context).colorScheme.primary
        : Colors.white70;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.68),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: 0.32)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: accent, size: 14),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuntimeSummary extends StatelessWidget {
  const _RuntimeSummary({required this.controller});

  final MonitorController controller;

  @override
  Widget build(BuildContext context) {
    final percent = (controller.motionScore * 100)
        .clamp(0, 100)
        .toStringAsFixed(0);
    final motion = !controller.motionOnly
        ? 'Movimento livre'
        : controller.cameraMotion
        ? 'Movimento da câmera ignorado'
        : controller.motionActive
        ? 'Movimento $percent%'
        : 'Aguardando movimento';
    final schedule = controller.schedule.enabled
        ? (controller.scheduleActive ? 'Agenda ativa agora' : 'Fora da agenda')
        : 'Modo manual';
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        _MiniStatus(icon: Icons.directions_run_rounded, text: motion),
        _MiniStatus(icon: Icons.schedule_rounded, text: schedule),
        _MiniStatus(
          icon: Icons.grid_view_rounded,
          text: controller.activeMonitoringZones.isEmpty
              ? 'Tela inteira'
              : '${controller.activeMonitoringZones.length} áreas',
        ),
        _MiniStatus(
          icon: Icons.filter_alt_outlined,
          text: '${controller.alertLabels.length} objetos',
        ),
      ],
    );
  }
}

class _MiniStatus extends StatelessWidget {
  const _MiniStatus({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 184),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 14),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetectionCard extends StatelessWidget {
  const _DetectionCard({
    required this.label,
    required this.confidence,
    this.trackId,
  });

  final String label;
  final double confidence;
  final int? trackId;

  @override
  Widget build(BuildContext context) {
    final percent = (confidence * 100).round();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: scheme.primary.withValues(alpha: 0.12),
            child: trackId == null
                ? Icon(
                    Icons.center_focus_strong,
                    color: scheme.primary,
                    size: 18,
                  )
                : Text(
                    '#$trackId',
                    style: TextStyle(
                      color: scheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$percent%',
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDetectionState extends StatelessWidget {
  const _EmptyDetectionState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Icon(
            Icons.radar_rounded,
            size: 42,
            color: Theme.of(context).colorScheme.primary
                .withValues(alpha: 0.65),
          ),
          const SizedBox(height: 9),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _LanValueRow extends StatelessWidget {
  const _LanValueRow({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final String label;
  final String value;
  final Future<void> Function() onCopy;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 2),
                SelectableText(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copiar $label',
            onPressed: () => unawaited(onCopy()),
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      ),
    ),
  );
}


class _DashboardMetricCard extends StatelessWidget {
  const _DashboardMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 154, maxWidth: 180),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.24),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.16)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: scheme.primary, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            unit,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardActionButton extends StatelessWidget {
  const _DashboardActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.accent = false,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = FilledButton.styleFrom(
      backgroundColor: accent
          ? scheme.primary.withValues(alpha: 0.22)
          : Colors.black.withValues(alpha: 0.24),
      foregroundColor: accent ? scheme.primary : null,
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 4, vertical: 3)
          : null,
      minimumSize: compact ? const Size(0, 42) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(compact ? 14 : 18),
        side: BorderSide(color: scheme.primary.withValues(alpha: 0.14)),
      ),
      visualDensity: compact ? VisualDensity.compact : null,
    );
    if (compact) {
      return SizedBox(
        height: 44,
        child: FilledButton(
          style: style,
          onPressed: onPressed,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17),
              const SizedBox(height: 1),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: 54,
      child: FilledButton.tonalIcon(
        style: style,
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _DashboardCameraBadge extends StatelessWidget {
  const _DashboardCameraBadge({
    required this.icon,
    required this.label,
    required this.active,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = active ? scheme.primary : Colors.white70;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: accent),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapLegendItem extends StatelessWidget {
  const _MapLegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}

class _MapUnavailableState extends StatelessWidget {
  const _MapUnavailableState({
    required this.availability,
    required this.onEnable,
    required this.onOpenFullMap,
  });

  final LocationTrackingAvailability? availability;
  final VoidCallback onEnable;
  final VoidCallback onOpenFullMap;

  @override
  Widget build(BuildContext context) {
    final text = switch (availability) {
      LocationTrackingAvailability.servicesDisabled =>
        'Ative o GPS do Android para mostrar o mapa ao vivo.',
      LocationTrackingAvailability.permissionDenied =>
        'Permita a localização para exibir sua posição e a rota.',
      LocationTrackingAvailability.permissionDeniedForever =>
        'A localização foi bloqueada neste app. Abra o mapa completo para acessar os ajustes.',
      LocationTrackingAvailability.ready =>
        'Carregando mapa ao vivo…',
      null => 'Ative o mapa ao vivo para mostrar posição e trajeto nesta tela.',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off_outlined, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Mapa indisponível agora',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: onEnable,
                  icon: const Icon(Icons.my_location_rounded),
                  label: const Text('Ativar mapa'),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenFullMap,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Abrir tela completa'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? Theme.of(context).colorScheme.primary
        : Colors.white38;
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: active
            ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 8)]
            : null,
      ),
    );
  }
}

class _CameraErrorCard extends StatelessWidget {
  const _CameraErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: error.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          TextButton(onPressed: onRetry, child: const Text('Repetir')),
        ],
      ),
    );
  }
}
