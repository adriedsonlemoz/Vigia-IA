# Vigia IA 1.0.74+74

Data: 2026-09-22.

## Principais mudanças

- Monitor em paisagem sem AppBar fixa ocupando faixa preta.
- HUD superior translúcido agrupando estado, IA, detecções, aparelhos, voz, preenchimento e dados Bike.
- Botão claro para sair/encerrar o monitoramento em paisagem e tela cheia.
- Tela cheia mantém opção separada de sair da tela cheia.
- Preview passa a preencher automaticamente em paisagem/tela cheia.
- Modo Câmera usa barra superior translúcida e painel adaptativo inferior/lateral.
- Estado parado do Modo Câmera agora explica a função do transmissor, em vez de mostrar só câmera desligada.

## Fluxo inicial

O fluxo permanece:

1. Acesso inicial e permissões.
2. Escolha de modo: Normal, Bike ou Transmissão.
3. Possibilidade de trocar o modo depois em Configurações > Monitoramento > Modo inicial.

## Como validar

1. Abra o Monitor em retrato e paisagem.
2. Confirme que paisagem não mostra AppBar fixa preta.
3. Confirme que pressão, velocidade e status ficam agrupados no topo.
4. Entre em tela cheia e confirme as ações de sair da tela cheia e sair do monitoramento.
5. Abra Modo Câmera parado e confirme o novo estado visual.
6. Inicie Modo Câmera e confirme os controles Parar e Voltar.
