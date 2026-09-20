import 'package:flutter/material.dart';

import '../models/device_telemetry.dart';
import '../models/session_status.dart';
import '../utils/storage_size_formatter.dart';

part 'session_status_panel_components.dart';

class SessionStatusPanel extends StatelessWidget {
  const SessionStatusPanel({
    super.key,
    required this.data,
    this.showCloseButton = false,
  });

  final SessionStatusData data;
  final bool showCloseButton;

  @override
  Widget build(BuildContext context) {
    final remote = data.remotePhone;
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          final localSection = _DeviceSection(
            title: 'Este celular',
            subtitle: data.aiDevice == 'Este celular'
                ? 'Executa a IA desta sessão.'
                : 'Acompanha a sessão.',
            icon: Icons.smartphone_rounded,
            telemetry: data.localDevice,
            connectionFallback: data.sourceConnection,
          );
          final remoteSection = _DeviceSection(
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
          );
          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
                  if (showCloseButton) ...[
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Fechar',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _SessionHealthCard(data: data)),
                    const SizedBox(width: 12),
                    Expanded(child: _VideoSummaryCard(data: data)),
                  ],
                )
              else ...[
                _SessionHealthCard(data: data),
                const SizedBox(height: 12),
                _VideoSummaryCard(data: data),
              ],
              const SizedBox(height: 16),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: localSection),
                    const SizedBox(width: 16),
                    Expanded(child: remoteSection),
                  ],
                )
              else ...[
                localSection,
                const SizedBox(height: 12),
                remoteSection,
              ],
            ],
          );
        },
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
            const SizedBox(height: 16),
            Text(
              'Pipeline da IA',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            _MetricGroup(
              children: [
                _MetricRow(
                  label: 'Pré-processamento',
                  value: _millisecondsText(data.preprocessMs),
                  detail: 'Recorte da zona e análise de movimento antes do detector.',
                ),
                _MetricRow(
                  label: 'Inferência principal',
                  value: _millisecondsText(data.primaryInferenceMs),
                ),
                _MetricRow(
                  label: 'Inferências auxiliares',
                  value: _millisecondsText(data.auxiliaryInferenceMs),
                  detail: '${data.auxiliaryInferenceRuns} execução(ões) extra(s) no último frame.',
                ),
                _MetricRow(
                  label: 'Pós-processamento',
                  value: _millisecondsText(data.postprocessMs),
                  detail: 'Filtros, rastreamento, regras e preparação dos alertas.',
                ),
                _MetricRow(
                  label: 'Processamento total',
                  value: _millisecondsText(data.totalProcessingMs),
                  detail: 'Orçamento atual: ${data.expectedFrameIntervalMs} ms.',
                ),
                _MetricRow(
                  label: 'Uso do orçamento',
                  value: data.totalProcessingMs == null
                      ? '—'
                      : '${data.processingBudgetUsagePercent.toStringAsFixed(0)}%',
                  detail: _budgetHeadroomText(data.processingHeadroomMs),
                ),
                _MetricRow(
                  label: 'Maior custo local',
                  value: data.pipelineHotspot,
                ),
                _MetricRow(
                  label: 'Detector por frame',
                  value: '${data.detectorRuns} execução(ões)',
                ),
                _MetricRow(
                  label: 'Fim a fim estimado',
                  value: _millisecondsText(data.endToEndMs),
                  detail: 'Da captura até o resultado da análise.',
                ),
                _MetricRow(
                  label: 'Detalhes evitados por orçamento',
                  value: '${data.detailScansSkippedByBudget}',
                  detail: 'Varreduras opcionais puladas para preservar a responsividade.',
                ),
              ],
            ),
          ],
        ),
      );
}

