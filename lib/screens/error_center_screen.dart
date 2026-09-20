import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/system_health.dart';
import '../services/diagnostic_report_service.dart';
import '../services/error_log_service.dart';
import '../services/performance_telemetry_service.dart';
import '../widgets/export_destination_dialog.dart';
import '../widgets/help_button.dart';

part 'error_center_screen_components.dart';

enum _ErrorFilter { all, errors, warnings, info }

class ErrorCenterScreen extends StatefulWidget {
  const ErrorCenterScreen({super.key});

  @override
  State<ErrorCenterScreen> createState() => _ErrorCenterScreenState();
}

class _ErrorCenterScreenState extends State<ErrorCenterScreen> {
  final ErrorLogService _logs = ErrorLogService.instance;
  final DiagnosticReportService _reports = DiagnosticReportService();
  final PerformanceTelemetryService _performance =
      PerformanceTelemetryService.instance;
  _ErrorFilter _filter = _ErrorFilter.all;
  DiagnosticReport? _report;
  Timer? _timer;
  bool _loading = true;
  bool _refreshing = false;
  bool _exporting = false;
  bool _exportingPerformance = false;

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
    final chooseLocation = await resolveExportLocation(context, title: 'Salvar diagnóstico');
    if (chooseLocation == null || !mounted) return;
    setState(() => _exporting = true);
    try {
      final path = await _reports.export(
        report,
        chooseLocation: chooseLocation,
      );
      if (!mounted || path == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Diagnóstico salvo em $path')),
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

  Future<void> _exportPerformance() async {
    if (_exportingPerformance || _performance.sampleCount == 0) return;
    final chooseLocation = await resolveExportLocation(
      context,
      title: 'Salvar desempenho da sessão',
    );
    if (chooseLocation == null || !mounted) return;
    setState(() => _exportingPerformance = true);
    try {
      final path = chooseLocation
          ? await _performance.exportWithPicker()
          : await _performance.exportToDownloads();
      if (!mounted || path == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Relatório de desempenho salvo em $path')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível exportar desempenho: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingPerformance = false);
    }
  }

  void _startDeepTrace(Duration duration) {
    _performance.startDeepTrace(duration);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Diagnóstico profundo iniciado por ${duration.inSeconds} s. Use o Monitor normalmente durante esse período.',
        ),
      ),
    );
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
                'Use esta tela para conferir câmera, frames, IA, serviço e permissões. O diagnóstico técnico vai para Downloads por padrão; o relatório de desempenho inclui resumo, JSON e CSV em um ZIP.',
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
            _PerformanceTelemetryCard(
              service: _performance,
              exporting: _exportingPerformance,
              onTrace30: () => _startDeepTrace(const Duration(seconds: 30)),
              onTrace60: () => _startDeepTrace(const Duration(seconds: 60)),
              onStopTrace: () {
                _performance.stopDeepTrace();
                setState(() {});
              },
              onExport: _exportPerformance,
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

