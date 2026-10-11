# Vigia IA 1.0.211+211 — Mapa como tela inicial

## Novidades

- O Vigia IA abre diretamente no mapa no papel de uso normal.
- Botão Modos seleciona Explorar, Pedalar, Navegar ou Monitorar sem encerrar a trilha ou rota atual.
- Painéis contextuais mostram gravação e acesso ao monitoramento sem acionar câmeras por conta própria.
- Menu Ferramentas reúne Histórico, Câmeras, Vigia Bike, Configurações, Monitoramento e troca do papel do aparelho.
- Ao abrir uma ferramenta, inscrição passiva GPS do mapa é liberada, preservando sessões de gravação/navegação existentes.
- Inicialização de telemetria ESP32 e checagens de câmera desnecessárias reduzidas para a entrada normal.

## Limites de validação

- Verificadores estáticos locais executados; `flutter analyze`, `flutter test`, compilação Android e testes reais devem ser realizados com SDK.
- Perfis dedicados de câmera/monitor remoto, RTSP, IA, GPX e MBTiles mantidos.
- MBTiles é visualização local; Valhalla continua remoto. Modos visuais não representam gerenciamento completo de tarefas em background.
