# Vigia IA 1.0.254+254 — ajustes visuais e controle rápido de IA no Ao vivo

## Resumo

Esta versão refina a tela principal **Ao vivo** do Vigia IA.

- corrige inconsistências de cores no strip embutido, incluindo **Receptor (IA)**, bateria e o selo do mapa;
- adiciona um controle rápido sobre o vídeo para **ligar/desligar a IA local** sem interromper a imagem;
- exibe no canto inferior do vídeo um rodapé discreto com **resolução e FPS da análise**;
- o selo da câmera local passa a mostrar **Ao vivo** e o cartão **Detectados** informa quando a análise está desativada.

## Detalhes técnicos

- `MonitorSettings` agora persiste `aiEnabled`.
- `MonitorController` limpa detecções e métricas de inferência quando a IA é desligada.
- `MonitorScreen` e componentes associados exibem estado da IA na própria imagem e alinham melhor as cores ao tema claro da tela principal.

## Compatibilidade

- Mantém os fluxos existentes de câmera local, RTSP, ESP32 e outro celular / Minha Câmera.
- Mapa sob demanda, monitoramento em tela cheia e seleção de fontes continuam disponíveis.
