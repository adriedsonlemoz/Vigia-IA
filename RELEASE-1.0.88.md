# Vigia IA 1.0.88+88

## Resumo

Esta entrega implementa a nova tela Ao vivo em paisagem, priorizando a câmera, o mapa do trajeto e a telemetria da bike na mesma interface.

## Principais mudanças

- Dashboard ao vivo redesenhado para câmera única em paisagem.
- Mini-mapa integrado ao monitor com posição, rota atual e orientação para ativação da localização.
- Cards fixos para velocidade, temperatura, pneus e distância.
- Ações rápidas inferiores para sair, ver detectados, abrir mapa, controlar áudio e acessar mais opções.
- Painel de detecções sob demanda, sem consumir espaço lateral no layout principal.

## Compatibilidade

- O modo de duas câmeras mantém o fluxo anterior.
- O mapa completo `MapMonitoringScreen` continua disponível.
- GPS só é solicitado explicitamente quando necessário; a checagem passiva evita pedir localização de forma agressiva ao abrir o monitor.
