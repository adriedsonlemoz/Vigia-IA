# Vigia IA 1.0.73+73

Data: 2026-09-21.

## Principais mudanças

- Adicionada seleção inicial de modo após o acesso inicial/permissões.
- Modos disponíveis: Normal, Bike e Transmissão.
- A escolha fica salva em `launch_mode.json` e decide a primeira tela nas próximas aberturas.
- Configurações > Monitoramento ganhou o item Modo inicial para revisar ou trocar a escolha.
- O Modo transmissão abre diretamente o Modo Câmera, mantendo o celular transmissor dedicado ao envio de imagem.

## Decisão de produto

O transmissor deve continuar leve. O futuro mini mapa/GPS e as melhorias da Bike, como identificar contexto de veículo vindo atrás, devem ficar no aparelho receptor/visualizador.

## Como validar

1. Em uma instalação nova, conclua o acesso inicial.
2. Confirme que a tela Escolha o modo aparece antes da Home.
3. Escolha Normal e confirme abertura da Home.
4. Troque para Bike em Configurações > Monitoramento > Modo inicial e confirme que a próxima abertura vai para Bike.
5. Troque para Transmissão e confirme que a próxima abertura vai para Modo Câmera.
