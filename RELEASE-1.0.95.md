# Vigia IA 1.0.95+95

## Monitor vertical refinado

- Telemetria ESP32/Bike mais estreita para exibir mais cards na mesma linha.
- Mini-mapa mais alto e clicável para abrir a tela completa.
- Barra inferior passa a usar **Câmera**, **Áudio**, **Painel** e **Ajustes**.
- Novo hub de câmeras reúne fonte principal, modo com uma ou duas câmeras, frontal de teste, ESP32 e demais fontes cadastradas.
- Menu de três pontos sem as duplicações de câmera e Status da sessão; áudio removido do topo.
- Contraste visual de Áudio/Painel/Ajustes corrigido.
- Seis atalhos do painel passam a caber lado a lado quando houver espaço.
- Duplo toque sobre o vídeo ativa tela inteira.
- Selo da câmera local simplificado para **Local**.
- PiP da segunda câmera agora é arrastável e fica limitado à área do vídeo.
- Caixas verdes de detecção preservadas após análise; continuam sendo apenas uma camada visual.

## Validação

- Executar `bash tool/verify_project.sh`.
- `flutter analyze`, `flutter test` e build Android dependem do workflow quando Flutter/Android SDK não estiverem disponíveis localmente.
