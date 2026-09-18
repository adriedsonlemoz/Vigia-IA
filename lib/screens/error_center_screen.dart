import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/error_log_service.dart';

enum _ErrorFilter { all, errors, warnings, info }

class ErrorCenterScreen extends StatefulWidget {
  const ErrorCenterScreen({super.key});

  @override
  State<ErrorCenterScreen> createState() => _ErrorCenterScreenState();
}

class _ErrorCenterScreenState extends State<ErrorCenterScreen> {
  final ErrorLogService _logs = ErrorLogService.instance;
  _ErrorFilter _filter = _ErrorFilter.all;

  @override
  void initState() {
    super.initState();
    _logs.addListener(_refresh);
  }

  @override
  void dispose() {
    _logs.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _copyAll() async {
    await Clipboard.setData(ClipboardData(text: _logs.exportText()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Relatório técnico copiado.')),
    );
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
    if (confirmed == true) await _logs.clear();
  }

  bool _accept(ErrorLogEntry entry) => switch (_filter) {
        _ErrorFilter.all => true,
        _ErrorFilter.errors => entry.level == ErrorLogLevel.error,
        _ErrorFilter.warnings => entry.level == ErrorLogLevel.warning,
        _ErrorFilter.info => entry.level == ErrorLogLevel.info,
      };


  @override
  Widget build(BuildContext context) {
    final all = _logs.entries;
    final entries = all.where(_accept).toList(growable: false);
    final errors = all.where((entry) => entry.level == ErrorLogLevel.error).length;
    final warnings = all.where((entry) => entry.level == ErrorLogLevel.warning).length;
    final infos = all.where((entry) => entry.level == ErrorLogLevel.info).length;
    final healthy = _logs.problemCount == 0;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Diagnóstico', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('Saúde e registros do sistema', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Opções de diagnóstico',
            onSelected: (value) {
              if (value == 'copy') unawaited(_copyAll());
              if (value == 'clear') unawaited(_clear());
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'copy',
                enabled: all.isNotEmpty,
                child: const ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.copy_all_outlined),
                  title: Text('Copiar relatório'),
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
            _HealthCard(
              healthy: healthy,
              problems: _logs.problemCount,
              records: _logs.count,
            ),
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

class _HealthCard extends StatelessWidget {
  const _HealthCard({
    required this.healthy,
    required this.problems,
    required this.records,
  });

  final bool healthy;
  final int problems;
  final int records;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = healthy ? const Color(0xFF4ADE80) : scheme.error;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 2),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
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
            child: Icon(
              healthy ? Icons.verified_outlined : Icons.health_and_safety_outlined,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  healthy ? 'Sistema funcionando normalmente' : '$problems problema(s) encontrado(s)',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  healthy
                      ? '$records registro(s) técnico(s) disponíveis para consulta.'
                      : 'Abra os registros abaixo para ver detalhes e contexto.',
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
              'Nenhum aviso encontrado',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'O sistema não possui registros neste filtro.',
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
