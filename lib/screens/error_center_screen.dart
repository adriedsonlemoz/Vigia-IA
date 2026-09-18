import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/system_health.dart';
import '../services/diagnostic_report_service.dart';
import '../services/error_log_service.dart';
import '../widgets/help_button.dart';

enum _ErrorFilter { all, errors, warnings, info }

class ErrorCenterScreen extends StatefulWidget {
  const ErrorCenterScreen({super.key});

  @override
  State<ErrorCenterScreen> createState() => _ErrorCenterScreenState();
}

class _ErrorCenterScreenState extends State<ErrorCenterScreen> {
  final ErrorLogService _logs = ErrorLogService.instance;
  final DiagnosticReportService _reports = DiagnosticReportService();
  _ErrorFilter _filter = _ErrorFilter.all;
  DiagnosticReport? _report;
  Timer? _timer;
  bool _loading = true;
  bool _refreshing = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _logs.addListener(_onLogsChanged);
    unawaited(_load());
    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_refreshReport()),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _logs.removeListener(_onLogsChanged);
    super.dispose();
  }

  void _onLogsChanged() => unawaited(_refreshReport());

  Future<void> _load() async {
    await _refreshReport();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refreshReport() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final report = await _reports.capture();
      if (mounted) setState(() => _report = report);
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _copyAll() async {
    final report = _report;
    if (report == null) return;
    await Clipboard.setData(ClipboardData(text: report.toText()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Diagnóstico copiado.')),
    );
  }

  Future<void> _export() async {
    final report = _report;
    if (report == null || _exporting) return;
    setState(() => _exporting = true);
    try {
      final path = await _reports.export(report);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Diagnóstico exportado'),
          content: SelectableText(path),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                unawaited(_share());
              },
              icon: const Icon(Icons.share_outlined),
              label: const Text('Compartilhar'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível exportar: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _share() async {
    final report = _report;
    if (report == null) return;
    final shared = await _reports.share(report);
    if (!shared && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o compartilhamento.')),
      );
    }
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar diagnóstico?'),
        content: const Text(
          'Os registros técnicos armazenados no aparelho serão apagados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _logs.clear();
      await _refreshReport();
    }
  }

  bool _accept(ErrorLogEntry entry) => switch (_filter) {
        _ErrorFilter.all => true,
        _ErrorFilter.errors => entry.level == ErrorLogLevel.error,
        _ErrorFilter.warnings => entry.level == ErrorLogLevel.warning,
        _ErrorFilter.info => entry.level == ErrorLogLevel.info,
      };

  @override
  Widget build(BuildContext context) {
    final report = _report;
    if (_loading || report == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final all = report.entries;
    final entries = all.where(_accept).toList(growable: false);
    final errors = all.where((entry) => entry.level == ErrorLogLevel.error).length;
    final warnings = all.where((entry) => entry.level == ErrorLogLevel.warning).length;
    final infos = all.where((entry) => entry.level == ErrorLogLevel.info).length;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Diagnóstico', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('Estado real e registros técnicos', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          const HelpButton(
            title: 'Diagnóstico',
            message:
                'Use esta tela para conferir câmera, frames, IA, serviço e permissões. Exportar gera um TXT com exatamente o estado e os registros exibidos.',
          ),
          PopupMenuButton<String>(
            tooltip: 'Opções de diagnóstico',
            onSelected: (value) {
              if (value == 'copy') unawaited(_copyAll());
              if (value == 'clear') unawaited(_clear());
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'copy',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.copy_all_outlined),
                  title: Text('Copiar diagnóstico'),
                ),
              ),
              PopupMenuItem(
                value: 'clear',
                enabled: all.isNotEmpty,
                child: const ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline_rounded),
                  title: Text('Limpar registros'),
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _DiagnosticSummary(health: report.health, problems: report.problemCount),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _exporting ? null : _export,
                      icon: _exporting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.file_download_outlined),
                      label: const Text('Exportar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _share,
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Compartilhar'),
                    ),
                  ),
                ],
              ),
            ),
            _CurrentStateGrid(health: report.health),
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                children: [
                  _FilterChip(
                    label: 'Todos ${all.length}',
                    selected: _filter == _ErrorFilter.all,
                    onTap: () => setState(() => _filter = _ErrorFilter.all),
                  ),
                  _FilterChip(
                    label: 'Erros $errors',
                    selected: _filter == _ErrorFilter.errors,
                    onTap: () => setState(() => _filter = _ErrorFilter.errors),
                  ),
                  _FilterChip(
                    label: 'Avisos $warnings',
                    selected: _filter == _ErrorFilter.warnings,
                    onTap: () => setState(() => _filter = _ErrorFilter.warnings),
                  ),
                  _FilterChip(
                    label: 'Info $infos',
                    selected: _filter == _ErrorFilter.info,
                    onTap: () => setState(() => _filter = _ErrorFilter.info),
                  ),
                ],
              ),
            ),
            Expanded(
              child: entries.isEmpty
                  ? const _NoDiagnostics()
                  : Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 920),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                          itemCount: entries.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) =>
                              _ErrorEntryCard(entry: entries[index]),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

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
