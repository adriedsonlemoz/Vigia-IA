part of 'home_screen.dart';

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: TextStyle(
            color: scheme.primary,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _SurfacePanel extends StatelessWidget {
  const _SurfacePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.16),
        ),
      ),
      child: child,
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: scheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge!,
                      style: TextStyle(
                        color: scheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, size: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({
    required this.motionOnly,
    required this.clipRecordingEnabled,
    required this.trackingEnabled,
    required this.announceEntryExit,
    required this.backgroundMonitoringEnabled,
    required this.voiceEnabled,
    required this.onMotionChanged,
    required this.onClipChanged,
    required this.onTrackingChanged,
    required this.onEntryExitChanged,
    required this.onBackgroundChanged,
    required this.onVoiceChanged,
  });

  final bool motionOnly;
  final bool clipRecordingEnabled;
  final bool trackingEnabled;
  final bool announceEntryExit;
  final bool backgroundMonitoringEnabled;
  final bool voiceEnabled;
  final ValueChanged<bool> onMotionChanged;
  final ValueChanged<bool> onClipChanged;
  final ValueChanged<bool> onTrackingChanged;
  final ValueChanged<bool>? onEntryExitChanged;
  final ValueChanged<bool> onBackgroundChanged;
  final ValueChanged<bool> onVoiceChanged;

  @override
  Widget build(BuildContext context) {
    return _SurfacePanel(
      child: Column(
        children: [
          _FeatureTile(
            icon: Icons.directions_run_rounded,
            label: 'Movimento',
            description: 'Analisa a IA quando há mudança relevante na imagem.',
            value: motionOnly,
            onChanged: onMotionChanged,
          ),
          _FeatureTile(
            icon: Icons.movie_outlined,
            label: 'Clipes automáticos',
            description: 'Salva um pequeno registro visual quando há um evento.',
            value: clipRecordingEnabled,
            onChanged: onClipChanged,
          ),
          _FeatureTile(
            icon: Icons.track_changes_rounded,
            label: 'Rastreamento',
            description: 'Mantém um ID temporário para acompanhar o mesmo objeto entre quadros.',
            value: trackingEnabled,
            onChanged: onTrackingChanged,
          ),
          _FeatureTile(
            icon: Icons.compare_arrows_rounded,
            label: 'Entrada e saída',
            description: 'Registra quando um objeto entra ou sai de uma área. Não é contador.',
            value: announceEntryExit,
            onChanged: onEntryExitChanged,
          ),
          _FeatureTile(
            icon: Icons.phone_android_rounded,
            label: 'Segundo plano',
            description: 'Mantém o monitor ativo quando o Android permite.',
            value: backgroundMonitoringEnabled,
            onChanged: onBackgroundChanged,
          ),
          _FeatureTile(
            icon: Icons.volume_up_outlined,
            label: 'Alertas de voz',
            description: 'Fala localmente o grupo detectado, sem depender de internet.',
            value: voiceEnabled,
            onChanged: onVoiceChanged,
            last: true,
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onChanged != null;
    return Column(
      children: [
        InkWell(
          onTap: enabled ? () => onChanged!(!value) : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: value
                        ? scheme.primary.withValues(alpha: 0.10)
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    icon,
                    size: 19,
                    color: value ? scheme.primary : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: enabled ? null : Theme.of(context).disabledColor,
                        ),
                      ),
                      Text(
                        enabled ? description : '$description Requer rastreamento.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: value,
                  onChanged: onChanged,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
        ),
        if (!last) const Divider(height: 7),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard({required this.sourceType});

  final VideoSourceType sourceType;

  @override
  Widget build(BuildContext context) {
    return _SurfacePanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              switch (sourceType) {
                VideoSourceType.rtsp => 'IA, histórico, clipes e configurações ficam no aparelho. A rede é usada apenas para acessar a câmera RTSP.',
                VideoSourceType.remotePhone => 'IA, histórico e clipes ficam nesta Central. A imagem do outro celular trafega somente pela rede local ou hotspot.',
                VideoSourceType.localCamera => 'IA, histórico, clipes e configurações ficam no aparelho. O monitoramento não depende de nuvem.',
              },
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
