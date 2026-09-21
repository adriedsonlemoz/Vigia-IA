# Vigia IA 1.0.71+71

Data: 2026-09-21.

## Principais mudanças

- Recepção da câmera remota independente da cadência da IA, com consulta rápida e descarte de duplicatas.
- Protocolo LAN com sequência de quadro, timestamp UTC, cache desativado e resposta `204` quando não há imagem nova.
- Faixa permanente para receptor e transmissor com bateria, carregamento, conexão e latência disponível.
- Composição adaptada para retrato, paisagem e tela inteira; o toque abre o Status da sessão completo.
- Resolução robusta dos áudios integrados via `R.raw`, com diagnóstico detalhado em caso de falha.

## Como validar no aparelho

1. Inicie o Modo Câmera no aparelho transmissor e conecte o receptor pela opção Outro celular.
2. Movimente a câmera e confirme atualização contínua sem repetição prolongada do mesmo quadro.
3. Confira se a faixa mostra as duas baterias e muda o estado quando a conexão é interrompida.
4. Teste retrato, paisagem e tela inteira, incluindo Ajustar/Preencher e retorno pelo botão Voltar.
5. Em Configurações de áudio, toque em Ouvir e confirme os áudios padrão antes de testar os alertas reais.
