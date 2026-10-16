part of 'monitor_screen.dart';

// Os controles de análise pertencem ao receptor, nunca ao transmissor.
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
                'ao trocar de modelo. Quando o escolhido não estiver disponível, '
                'um modelo compatível será utilizado.',
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
                    ? const Text('Seleciona a melhor opção disponível e faz fallback')
                    : null,
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  if (preference == _controller.detectorModelPreference) return;
                  try {
                    await _controller.changeDetectorModel(preference);
                    if (!mounted) return;
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
              const Text('Escolha a duração. A análise continua recebendo '
                  'quadros durante o teste, mesmo de câmeras remotas.'),
              const SizedBox(height: 10),
              for (final seconds in const <int>[15, 30, 60])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      unawaited(_runAiDiagnosticTest(seconds));
                    },
                    icon: const Icon(Icons.timer_outlined),
                    label: Text('Testar por $seconds segundos'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _runAiDiagnosticTest(int seconds) async {
    if (!_controller.aiEnabled || !_controller.sessionStatus.sourceOnline) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Ative a IA e conecte uma câmera antes do teste.'),
      ));
      return;
    }
    final telemetry = PerformanceTelemetryService.instance;
    final start = _controller.sessionStatus;
    final selected = _controller.detectorModelPreference.label;
    final startedModel = _controller.activeDetectorModel;
    var remaining = seconds;
    var completed = false;
    telemetry.startDeepTrace(Duration(seconds: seconds));
    Timer? ticker;
    try {
      final elapsed = Stopwatch()..start();
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
              if (!dialogContext.mounted) return;
              remaining = (seconds - elapsed.elapsed.inSeconds)
                  .clamp(0, seconds).toInt();
              if (remaining == 0) {
                completed = true;
                Navigator.of(dialogContext).pop();
              } else {
                setDialogState(() {});
              }
            });
            return AlertDialog(
              title: const Text('Testando análise da IA'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$remaining s',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: (seconds - remaining) / seconds),
                  const SizedBox(height: 8),
                  const Text('A câmera permanece ativa. Não altere o modelo '
                      'durante a medição.'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      ticker?.cancel();
      telemetry.stopDeepTrace();
    }
    if (!mounted || !completed) return;
    final end = _controller.sessionStatus;
    final samples = telemetry.createReport().deepTraceSamples;
    final inference = samples
        .map((sample) => sample.primaryRoundTripMs)
        .whereType<double>()
        .where((value) => value >= 0)
        .toList(growable: false);
    final average = inference.isEmpty
        ? null
        : inference.reduce((a, b) => a + b) / inference.length;
    final temperature = samples.isEmpty
        ? null
        : samples.last.batteryTemperatureC;
    final actualModel = _controller.activeDetectorModel;
    final received = (end.framesReceived - start.framesReceived).clamp(0, 1 << 30);
    final analyzed = (end.framesAnalyzed - start.framesAnalyzed).clamp(0, 1 << 30);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Teste de IA concluído'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Duração: $seconds segundos'),
              Text('Seleção: $selected'),
              Text('Modelo inicial: $startedModel'),
              Text('Modelo final: $actualModel'),
              if (selected != 'Automático' && actualModel != selected)
                const Text('Atenção: ocorreu fallback do modelo solicitado.'),
              Text('Fonte: ${end.imageSource}'),
              Text('Quadros recebidos: $received'),
              Text('Quadros analisados: $analyzed'),
              Text('FPS médio de análise: ${(analyzed / seconds).toStringAsFixed(2)}'),
              Text('FPS instantâneo final: ${end.analyzedFps.toStringAsFixed(2)}'),
              Text('Resolução de análise: ${end.analysisResolution}'),
              Text('Latência média: ${average == null ? 'sem amostras' : '${average.toStringAsFixed(1)} ms'}'),
              Text('Temperatura da bateria: ${temperature == null ? 'indisponível' : '${temperature.toStringAsFixed(1)} °C'}'),
              Text('Amostras de telemetria: ${samples.length}'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Fechar')),
          FilledButton.icon(
            onPressed: () async {
              try {
                final file = await telemetry.exportWithPicker();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(file == null
                      ? 'Exportação cancelada.'
                      : 'Relatório exportado: $file'),
                ));
              } catch (error) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Falha na exportação: $error'),
                ));
              }
            },
            icon: const Icon(Icons.ios_share_rounded),
            label: const Text('Exportar ZIP'),
          ),
        ],
      ),
    );
  }
}
