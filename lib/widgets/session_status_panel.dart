import 'package:flutter/material.dart';
import '../models/device_telemetry.dart';
import '../models/session_status.dart';
import '../utils/storage_size_formatter.dart';
part 'session_status_panel_components.dart';
class SessionStatusPanel extends StatefulWidget {
  const SessionStatusPanel({
    super.key,
    required this.data,
    this.showCloseButton = false,
  });
  final SessionStatusData data;
  final bool showCloseButton;
  @override
  State<SessionStatusPanel> createState() => _SessionStatusPanelState();
}
class _SessionStatusPanelState extends State<SessionStatusPanel> {
  bool _showVideoDetails = false;
  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    if (_showVideoDetails) {
      return VideoSessionDetailsPanel(
        data: data,
        onBack: () => setState(() => _showVideoDetails = false),
      );
    }
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
                  if (widget.showCloseButton) ...[
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
                    Expanded(child: _VideoSummaryCard(
                      data: data,
                      onTap: () => setState(() => _showVideoDetails = true),
                    )),
                  ],
                )
              else ...[
                _SessionHealthCard(data: data),
                const SizedBox(height: 12),
                _VideoSummaryCard(
                      data: data,
                      onTap: () => setState(() => _showVideoDetails = true),
                    ),
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
  const VideoSessionDetailsPanel({
    super.key,
    required this.data,
    this.onBack,
  });
  final SessionStatusData data;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Row(
              children: [
                if (onBack != null) ...[
                  IconButton(
                    tooltip: 'Voltar ao status',
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 2),
                ] else ...[
                  const Icon(Icons.videocam_outlined),
                  const SizedBox(width: 10),
                ],
                const Expanded(
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
                  label: 'Inferência (round-trip)',
                  value: data.inferenceMs == null
                      ? '—'
                      : '${data.inferenceMs!.toStringAsFixed(0)} ms',
                  detail: 'Inclui fila/transferência do isolate e execução do detector.',
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
                  label: 'Conversão/decodificação da fonte',
                  value: _millisecondsText(data.sourceConversionMs),
                  detail: 'YUV/BGRA → RGB na câmera local ou decodificação da imagem recebida.',
                ),
                _MetricRow(
                  label: 'Pré-processamento do Monitor',
                  value: _millisecondsText(data.preprocessMs),
                  detail: 'Recorte da zona e análise de movimento antes do detector.',
                ),
                _MetricRow(
                  label: 'Fila + transferência do isolate',
                  value: _millisecondsText(data.isolateTransferAndQueueMs),
                ),
                _MetricRow(
                  label: 'Materialização no worker',
                  value: _millisecondsText(data.workerMaterializeMs),
                ),
                _MetricRow(
                  label: 'Imagem RGB no detector',
                  value: _millisecondsText(data.detectorImageBuildMs),
                ),
                _MetricRow(
                  label: 'Resize + letterbox',
                  value: _millisecondsText(data.resizeLetterboxMs),
                ),
                _MetricRow(
                  label: 'Montagem do tensor',
                  value: _millisecondsText(data.tensorBuildMs),
                ),
                _MetricRow(
                  label: 'LiteRT / TFLite puro',
                  value: _millisecondsText(data.liteRtMs),
                  detail: 'Tempo efetivamente gasto pelo modelo, separado do código ao redor.',
                ),
                _MetricRow(
                  label: 'Pós-processamento do detector',
                  value: _millisecondsText(data.detectorPostprocessMs),
                ),
                _MetricRow(
                  label: 'Inferência principal (round-trip)',
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
