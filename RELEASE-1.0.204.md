# Vigia IA 1.0.204+204

Correção da troca de estação no rádio online e maior robustez do stream.

## Causa

Cada reprodução criava um novo `AudioFocusRequest` com um novo listener e não abandonava o anterior. Ao pedir o novo foco, o Android enviava `AUDIOFOCUS_LOSS` ao pedido antigo, cujo listener chamava `stopSelf()`. O serviço terminava junto com a estação recém-escolhida, sem mensagem.

## Alterações

- `RadioPlaybackService.kt` (e a cópia em `tool/android`): listener e pedido de foco únicos e reutilizados; `startPlayback()` descarta o player anterior e ignora callbacks de players antigos.
- Reconexão automática (até 3 tentativas), tempo limite de conexão de 25 s e estado `indisponível` mantido após o encerramento do serviço.
- Perda transitória de foco pausa/retoma; pausar durante a conexão é respeitado.
- `AudioAttributes` de mídia e `WAKE_LOCK` parcial no `MediaPlayer`.
- `MapRadioPanel`: aviso quando uma estação ativa deixa de responder; botão "Pausar" durante "Conectando…".
- Novas verificações em `tool/verify_project.sh`.

## Validação

`flutter analyze`, `flutter test` e o build ainda precisam ser confirmados pelo workflow (SDK Flutter/Android indisponível no ambiente de edição). O comportamento do foco de áudio só pode ser confirmado em aparelho.
