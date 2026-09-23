# Vigia IA 1.0.94+94

## Resumo

Ajuste fino do Monitor vertical para aproveitar melhor a tela e teste temporário de duas câmeras com a frontal do próprio aparelho.

## Interface vertical

- Mini-mapa mais alto, com o resumo **Detectados** deslocado para baixo.
- **Abrir mapa**, **Áudio**, **Painel** e **Ajustes** aparecem juntos em uma única linha, sem rolagem horizontal.
- Os quatro atalhos têm altura, borda, margem e tipografia menores.
- A área inferior esquerda do mapa mostra a altitude real do GPS em formato compacto e remove o texto **Bike**.
- A distância percorrida continua na telemetria superior, evitando duplicação dentro do mapa.
- Cards de velocidade, temperatura, pneu dianteiro, pneu traseiro e distância foram compactados para caber mais telemetria ESP32/Bike.

## Teste temporário de segunda câmera

- O seletor **Uma ou duas câmeras** ganhou **Teste: câmera frontal**.
- A frontal é aberta em baixa resolução, sem áudio e sem análise de IA.
- No Monitor vertical, a segunda câmera usa uma pequena janela Picture-in-Picture no canto inferior direito da câmera principal.
- A câmera principal continua ocupando toda a área de vídeo e continua sendo a única responsável por IA, caixas, histórico e alertas.
- O mapa, os sensores e os quatro atalhos permanecem na tela mesmo com a segunda fonte ativa.
- A mesma composição PiP é utilizada por qualquer segunda fonte no retrato, preparando o espaço para uma segunda câmera real.
- Se o hardware/CameraX não aceitar frontal e traseira simultâneas, a indisponibilidade é mostrada somente no PiP e a principal deve permanecer ativa.

## Validação

- `tool/verify_project.sh` verifica versão, estrutura da nova UI, altitude, linha fixa de quatro ações, fonte frontal temporária, PiP e proteção do pipeline principal.
- Teste de `VideoSourceConfig` cobre o identificador dedicado da frontal temporária.
- Flutter/Dart/Android SDK não estão disponíveis neste ambiente; `flutter analyze`, `flutter test` e o build Android devem ser confirmados no workflow.
