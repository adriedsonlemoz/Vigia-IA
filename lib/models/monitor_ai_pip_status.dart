enum MonitorAiPipState {
  active,
  disabled,
  waitingFrames,
  noFrames,
  cameraUnavailable,
  connectionLost,
  analyzing,
  possibleError,
}

class MonitorAiPipStatus {
  const MonitorAiPipStatus({
    required this.state,
    this.detail,
  });

  final MonitorAiPipState state;
  final String? detail;

  String get label => switch (state) {
        MonitorAiPipState.active => 'IA ativa',
        MonitorAiPipState.disabled => 'IA desligada',
        MonitorAiPipState.waitingFrames => 'Aguardando frames',
        MonitorAiPipState.noFrames => 'Sem frames',
        MonitorAiPipState.cameraUnavailable => 'Câmera indisponível',
        MonitorAiPipState.connectionLost => 'Conexão perdida',
        MonitorAiPipState.analyzing => 'Analisando',
        MonitorAiPipState.possibleError => 'Possível erro da IA',
      };
}
