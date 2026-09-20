part of 'error_center_screen.dart';

class _DiagnosticSummary extends StatelessWidget {
  const _DiagnosticSummary({required this.health, required this.problems});

  final SystemHealthSnapshot health;
  final int problems;

  @override
  Widget build(BuildContext context) {
    final (icon, title, subtitle, color) = switch (health.operationalState) {
      SystemOperationalState.healthy => (
          Icons.verified_outlined,
          problems == 0 ? 'Monitoramento funcionando' : 'Monitoramento ativo com registros',
          problems == 0
              ? 'Câmera, frames e IA estão ativos.'
              : '$problems aviso(s)/erro(s) técnico(s) armazenado(s).',
          const Color(0xFF4ADE80),
        ),
      SystemOperationalState.attention => (
          Icons.warning_amber_rounded,
          'Monitoramento precisa de atenção',
          health.framesActive
              ? 'Uma etapa do fluxo não está operacional.'
              : 'Serviço ou monitor ativo sem frames recentes.',
          const Color(0xFFFFB74D),
        ),
      SystemOperationalState.idle => (
          Icons.pause_circle_outline_rounded,
          health.androidServiceActive
              ? 'Serviço ativo, captura inativa'
              : 'Monitoramento inativo',
          'O diagnóstico não considera o serviço Android sozinho como monitoramento funcionando.',
          Theme.of(context).colorScheme.onSurfaceVariant,
        ),
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 2),
      padding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(minHeight: 104),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentStateGrid extends StatelessWidget {
  const _CurrentStateGrid({required this.health});
  final SystemHealthSnapshot health;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _StateChip(label: 'Serviço', active: health.androidServiceActive),
          _StateChip(label: 'Câmera', active: health.cameraActive),
          _StateChip(label: 'Frames', active: health.framesActive),
          _StateChip(label: 'IA', active: health.aiActive),
          _StateChip(label: 'LAN', active: health.lanActive),
          _StateChip(
            label: '${health.connectedClients} cliente(s)',
            active: health.connectedClients > 0,
            neutralWhenOff: true,
          ),
          _StateChip(
            label: 'Permissões',
            active: health.permissionsReady,
          ),
          _StateChip(
            label: '2º plano',
            active: health.backgroundOperational,
            neutralWhenOff: !health.backgroundRequested,
          ),
        ],
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({
    required this.label,
    required this.active,
    this.neutralWhenOff = false,
  });

  final String label;
  final bool active;
  final bool neutralWhenOff;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? const Color(0xFF4ADE80)
        : neutralWhenOff
            ? Theme.of(context).colorScheme.onSurfaceVariant
            : const Color(0xFFFFB74D);
    return Container(
      constraints: const BoxConstraints(minWidth: 92, minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 7),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
        ),
      );
}

class _NoDiagnostics extends StatelessWidget {
  const _NoDiagnostics();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 34, 28, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 50,
              color: Color(0xFF4ADE80),
            ),
            const SizedBox(height: 10),
            const Text(
              'Nenhum registro neste filtro',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'O estado atual continua disponível acima.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorEntryCard extends StatelessWidget {
  const _ErrorEntryCard({required this.entry});

  final ErrorLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (entry.level) {
      ErrorLogLevel.info => (Icons.info_outline_rounded, Colors.blueGrey, 'INFO'),
      ErrorLogLevel.warning => (Icons.warning_amber_rounded, Colors.orange, 'AVISO'),
      ErrorLogLevel.error =>
        (Icons.error_outline_rounded, Theme.of(context).colorScheme.error, 'ERRO'),
    };
    final local = entry.timestamp.toLocal();
    final timestamp =
        '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}:'
        '${local.second.toString().padLeft(2, '0')}';

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          entry.message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text('$label · ${entry.source} · $timestamp'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          if (entry.context.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(
                entry.context.entries
                    .map((item) => '${item.key}: ${item.value}')
                    .join('\n'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (entry.details?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(
                entry.details!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                final text = StringBuffer()
                  ..writeln('${entry.source} • $timestamp')
                  ..writeln(entry.message);
                if (entry.context.isNotEmpty) text.writeln(entry.context);
                if (entry.details?.isNotEmpty == true) text.writeln(entry.details);
                await Clipboard.setData(ClipboardData(text: text.toString()));
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copiar detalhes'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PerformanceTelemetryCard extends StatelessWidget {
  const _PerformanceTelemetryCard({
    required this.service,
    required this.exporting,
    required this.onTrace30,
    required this.onTrace60,
    required this.onStopTrace,
    required this.onExport,
  });

  final PerformanceTelemetryService service;
  final bool exporting;
  final VoidCallback onTrace30;
  final VoidCallback onTrace60;
  final VoidCallback onStopTrace;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final active = service.deepTraceActive;
    final deepSamples = service.deepTraceSampleCount;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 2),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.speed_rounded, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Desempenho da sessão',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Telemetria normal: ${service.sampleCount} amostra(s). '
            '${active ? 'Diagnóstico profundo em andamento.' : deepSamples > 0 ? 'Último diagnóstico profundo: $deepSamples amostra(s).' : 'Você pode gravar cada análise por 30 ou 60 segundos.'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!active) ...[
                OutlinedButton.icon(
                  onPressed: onTrace30,
                  icon: const Icon(Icons.timer_outlined),
                  label: const Text('Diagnóstico 30 s'),
                ),
                OutlinedButton.icon(
                  onPressed: onTrace60,
                  icon: const Icon(Icons.timer_rounded),
                  label: const Text('Diagnóstico 60 s'),
                ),
              ] else
                FilledButton.tonalIcon(
                  onPressed: onStopTrace,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('Encerrar diagnóstico'),
                ),
              FilledButton.icon(
                onPressed: service.sampleCount == 0 || exporting ? null : onExport,
                icon: exporting
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.archive_outlined),
                label: const Text('Exportar desempenho'),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            'O ZIP contém resumo.txt, telemetria.json e telemetria.csv. Não inclui imagens.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
