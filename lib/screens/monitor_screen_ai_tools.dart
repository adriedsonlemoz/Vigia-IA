part of 'monitor_screen.dart';

/// Estado de um teste não modal; o usuário continua trocando modelo e câmera.
class _AiDiagnosticRun {
  _AiDiagnosticRun({
    required this.seconds,
    required this.start,
    required this.selection,
    required this.model,
  }) : segmentStart = start,
       currentSelection = selection,
       currentModel = model {
    watch.start();
    events.add('0 s • Início: $selection → $model');
  }

  final int seconds;
  final SessionStatusData start;
  final String selection;
  final String model;
  final Stopwatch watch = Stopwatch();
  final List<String> events = <String>[];
  final List<String> segments = <String>[];
  SessionStatusData segmentStart;
  String currentSelection;
  String currentModel;
  Duration segmentStartedAt = Duration.zero;
  String? lastIssue;
  int changes = 0;

  int get elapsedSeconds => watch.elapsed.inSeconds;
  int get remaining => (seconds - elapsedSeconds).clamp(0, seconds).toInt();

  void _finishSegment(SessionStatusData status) {
    final duration = (watch.elapsed - segmentStartedAt).inMilliseconds / 1000;
    final analyzed = (status.framesAnalyzed - segmentStart.framesAnalyzed)
        .clamp(0, 1 << 30).toInt();
    segments.add('$currentSelection → $currentModel: '
        '${duration.toStringAsFixed(1)} s, $analyzed quadros, '
        '${duration > 0 ? (analyzed / duration).toStringAsFixed(2) : '0'} FPS');
  }

  void observe(SessionStatusData status, String selected, String actual,
      {String? issue}) {
    if (selected != currentSelection || actual != currentModel) {
      _finishSegment(status);
      changes++;
      events.add('$elapsedSeconds s • $currentSelection → $currentModel '
          'para $selected → $actual');
      currentSelection = selected;
      currentModel = actual;
      segmentStart = status;
      segmentStartedAt = watch.elapsed;
    }
    if (issue != null && issue.isNotEmpty && issue != lastIssue) {
      if (events.length < 80) events.add('$elapsedSeconds s • $issue');
    }
    lastIssue = issue;
  }

  void finish(SessionStatusData status) {
    _finishSegment(status);
    watch.stop();
  }
}

class _AiDiagnosticResult {
  const _AiDiagnosticResult({
    required this.run,
    required this.end,
    required this.sampleCount,
    required this.averageLatency,
    required this.batteryTemperature,
  });
  final _AiDiagnosticRun run;
  final SessionStatusData end;
  final int sampleCount;
  final double? averageLatency;
  final double? batteryTemperature;
}

extension _MonitorAiTools on _MonitorScreenState {
  Future<void> _showAiModelPicker() async {
    final theme = Theme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Modelo da análise local', style: theme.textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                'Ativo: ${_controller.activeDetectorModel}. O vídeo continua '
                'ao trocar de modelo. Durante um diagnóstico, cada troca será '
                'registrada com o modelo realmente ativado.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              ...DetectorModelPreference.values.map((preference) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(preference == _controller.detectorModelPreference
                    ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                title: Text(preference.label),
                subtitle: preference == DetectorModelPreference.automatic
                    ? const Text('Tenta YOLO26s primeiro e faz fallback')
                    : preference == DetectorModelPreference.yolo26s
                    ? const Text('Padrão do Vigia IA; recua se indisponível ou lento')
                    : null,
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  if (preference == _controller.detectorModelPreference) return;
                  _sampleAiDiagnostic();
                  try {
                    await _controller.changeDetectorModel(preference);
                    if (!mounted) return;
                    _sampleAiDiagnostic();
                    final actual = _controller.activeDetectorModel;
                    final fallback = preference != DetectorModelPreference.automatic &&
                        actual != preference.label;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(fallback
                          ? 'Modelo solicitado indisponível; ativo: $actual'
                          : 'Modelo ativo: $actual'),
                    ));
                  } catch (error) {
                    if (!mounted) return;
                    _sampleAiDiagnostic(issue: 'Falha ao trocar para ${preference.label}: $error');
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Falha na troca do detector: $error'),
                    ));
                  }
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAiTestOptions() async {
    if (_aiDiagnostic != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Diagnóstico em execução. Use os controles normalmente; '
            'o progresso fica abaixo da faixa de câmeras.'),
      ));
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Diagnóstico da IA',
                  style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Modelo ativo: ${_controller.activeDetectorModel}'),
              const SizedBox(height: 6),
              const Text('O teste funciona sem bloquear a tela. Você pode '
                  'mudar de modelo, interagir com o vídeo e testar a câmera. '
                  'As trocas, quedas de sinal e falhas observadas entram no relatório.'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final seconds in const <int>[15, 30, 60, 120, 300, 600])
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _runAiDiagnosticTest(seconds);
                      },
                      icon: const Icon(Icons.timer_outlined, size: 18),
                      label: Text(seconds < 60 ? '$seconds s'
                          : '${seconds ~/ 60} min'),
                    ),
                ],
              ),
              if (_lastAiDiagnostic != null)
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _showAiDiagnosticResult(_lastAiDiagnostic!);
                  },
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Último relatório'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _runAiDiagnosticTest(int seconds) {
    if (_aiDiagnostic != null) return;
    if (!_controller.aiEnabled || !_controller.sessionStatus.sourceOnline) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Ative a IA e conecte uma câmera antes do teste.'),
      ));
      return;
    }
    final run = _AiDiagnosticRun(
      seconds: seconds,
      start: _controller.sessionStatus,
      selection: _controller.detectorModelPreference.label,
      model: _controller.activeDetectorModel,
    );
    PerformanceTelemetryService.instance.startDeepTrace(Duration(seconds: seconds));
    _aiDiagnosticTicker?.cancel();
    _updateAiDiagnosticState(() {
      _aiDiagnostic = run;
      _lastAiDiagnostic = null;
    });
    _aiDiagnosticTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _sampleAiDiagnostic();
      if (run.remaining == 0) {
        _finishAiDiagnostic();
      } else {
        _updateAiDiagnosticState(() {});
      }
    });
  }

  void _sampleAiDiagnostic({String? issue}) {
    final run = _aiDiagnostic;
    if (run == null) return;
    final status = _controller.sessionStatus;
    final warning = issue ?? _controller.error ??
        (!status.sourceOnline ? 'Fonte de vídeo desconectada' : null) ??
        (!_controller.aiEnabled ? 'IA desativada durante o teste' : null);
    run.observe(status, _controller.detectorModelPreference.label,
        _controller.activeDetectorModel, issue: warning);
  }

  void _finishAiDiagnostic() {
    final run = _aiDiagnostic;
    if (run == null) return;
    _sampleAiDiagnostic();
    run.finish(_controller.sessionStatus);
    _aiDiagnosticTicker?.cancel();
    _aiDiagnosticTicker = null;
    final telemetry = PerformanceTelemetryService.instance;
    telemetry.stopDeepTrace();
    final samples = telemetry.createReport().deepTraceSamples;
    final inference = samples.map((sample) => sample.primaryRoundTripMs)
        .whereType<double>().where((value) => value >= 0).toList();
    final average = inference.isEmpty ? null
        : inference.reduce((a, b) => a + b) / inference.length;
    final result = _AiDiagnosticResult(
      run: run,
      end: _controller.sessionStatus,
      sampleCount: samples.length,
      averageLatency: average,
      batteryTemperature: samples.isEmpty ? null : samples.last.batteryTemperatureC,
    );
    if (!mounted) return;
    _updateAiDiagnosticState(() {
      _aiDiagnostic = null;
      _lastAiDiagnostic = result;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Diagnóstico encerrado: ${run.elapsedSeconds} s, '
          '${run.changes} troca(s) de modelo.'),
      duration: const Duration(seconds: 8),
      action: SnackBarAction(label: 'Relatório',
          onPressed: () => _showAiDiagnosticResult(result)),
    ));
  }

  Widget _buildAiDiagnosticBanner(BuildContext context) {
    final run = _aiDiagnostic;
    final previous = _lastAiDiagnostic;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(Icons.monitor_heart_outlined, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(run == null
                  ? 'Diagnóstico concluído'
                  : 'Diagnóstico: ${run.remaining} s restantes • ${run.changes} troca(s)',
                  style: Theme.of(context).textTheme.bodySmall)),
              if (run != null)
                TextButton(onPressed: _finishAiDiagnostic,
                    child: const Text('Encerrar')),
              if (run == null && previous != null)
                TextButton(onPressed: () => _showAiDiagnosticResult(previous),
                    child: const Text('Relatório')),
              if (run == null)
                IconButton(
                  tooltip: 'Dispensar relatório',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => _updateAiDiagnosticState(() => _lastAiDiagnostic = null),
                ),
            ]),
            if (run != null) ...[
              LinearProgressIndicator(
                value: (run.elapsedSeconds / run.seconds).clamp(0.0, 1.0),
              ),
              const SizedBox(height: 3),
              Text('Ativo: ${run.currentModel}. Troque pelo botão de ajustes da IA.',
                  style: Theme.of(context).textTheme.labelSmall),
            ],
          ],
        ),
      ),
    );
  }

  String _aiDiagnosticReportText(_AiDiagnosticResult result) {
    final run = result.run;
    final end = result.end;
    final seconds = run.watch.elapsedMilliseconds / 1000;
    final analyzed = (end.framesAnalyzed - run.start.framesAnalyzed)
        .clamp(0, 1 << 30).toInt();
    final received = (end.framesReceived - run.start.framesReceived)
        .clamp(0, 1 << 30).toInt();
    return <String>[
      'Vigia IA • diagnóstico da IA',
      'Duração: ${seconds.toStringAsFixed(1)} s',
      'Fonte: ${end.imageSource}',
      'Modelo inicial: ${run.selection} → ${run.model}',
      'Modelo final: ${run.currentSelection} → ${run.currentModel}',
      'Mudanças: ${run.changes}',
      'Recebidos: $received; analisados: $analyzed',
      'FPS médio: ${seconds > 0 ? (analyzed / seconds).toStringAsFixed(2) : '0'}',
      'Resolução: ${end.analysisResolution}',
      'Amostras detalhadas: ${result.sampleCount}',
      'Desempenho por modelo:',
      ...run.segments,
      'Ocorrências:',
      ...run.events,
    ].join('\n');
  }

  Future<void> _showAiDiagnosticResult(_AiDiagnosticResult result) async {
    if (!mounted) return;
    final run = result.run;
    final end = result.end;
    final received = (end.framesReceived - run.start.framesReceived)
        .clamp(0, 1 << 30);
    final analyzed = (end.framesAnalyzed - run.start.framesAnalyzed)
        .clamp(0, 1 << 30);
    final duration = run.watch.elapsedMilliseconds / 1000;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Resultado do diagnóstico da IA'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Duração efetiva: ${duration.toStringAsFixed(1)} s'),
              Text('Seleção inicial: ${run.selection}'),
              Text('Modelo inicial: ${run.model}'),
              Text('Seleção final: ${run.currentSelection}'),
              Text('Modelo final: ${run.currentModel}'),
              Text('Trocas observadas: ${run.changes}'),
              if (run.currentSelection != 'Automático' &&
                  run.currentModel != run.currentSelection)
                const Text('Atenção: fallback ou incompatibilidade na seleção final.'),
              Text('Fonte: ${end.imageSource}'),
              Text('Quadros recebidos: $received'),
              Text('Quadros analisados: $analyzed'),
              Text('FPS médio geral: ${duration > 0 ? (analyzed / duration).toStringAsFixed(2) : '0'}'),
              Text('FPS instantâneo final: ${end.analyzedFps.toStringAsFixed(2)}'),
              Text('Resolução de análise: ${end.analysisResolution}'),
              Text('Latência média: ${result.averageLatency == null ? 'sem amostras' : '${result.averageLatency!.toStringAsFixed(1)} ms'}'),
              Text('Temperatura da bateria receptora: ${result.batteryTemperature == null ? 'indisponível' : '${result.batteryTemperature!.toStringAsFixed(1)} °C'}'),
              Text('Amostras detalhadas: ${result.sampleCount} (máximo 900)'),
              if (run.segments.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text('Desempenho por modelo',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                for (final segment in run.segments) Text('• $segment'),
              ],
              if (run.events.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text('Alterações e ocorrências',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                for (final event in run.events) Text('• $event'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(
                  text: _aiDiagnosticReportText(result)));
              if (!dialogContext.mounted) return;
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('Relatório copiado.')),
              );
            },
            child: const Text('Copiar'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final path = await PerformanceTelemetryService.instance
                    .exportWithPicker();
                if (!dialogContext.mounted || path == null) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Telemetria exportada.')),
                );
              } catch (error) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text('Não foi possível exportar: $error')),
                );
              }
            },
            child: const Text('Exportar dados'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}
