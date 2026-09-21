# Vigia IA 1.0.75+75

## Motivo da correção

O Android-APK-43 não chegou aos testes nem à geração do APK. O `flutter analyze` encontrou um operador `!` desnecessário em `camera_mode_screen.dart` e encerrou o workflow com código 1. O aviso do Node 20 ocorreu apenas na etapa posterior de artefatos e não foi a causa da falha.

Os logs anexados são do build e não contêm uma execução Android do áudio. Por isso, esta versão corrige o erro confirmado do pipeline e amplia a instrumentação no aparelho para capturar a causa real da reprodução na próxima ocorrência.

## Correção do áudio

- O player deixa de abortar quando `requestAudioFocus` é negado ou lança exceção. A reprodução continua de forma controlada e o evento fica registrado.
- Overrides continuam tendo prioridade; se falharem, o áudio integrado é tentado. Se ambos falharem, o fluxo usa TTS quando disponível.
- O erro nativo registra fase, `what`, `extra`, nomes interpretados, origem, arquivo, tamanho, volume, foco, rota e tempos.
- A tela de teste mostra código e etapa. A Central de Diagnóstico persiste a falha e os relatórios correlacionam o fallback para TTS.

## Privacidade

A telemetria não inclui imagem, áudio gravado, conteúdo falado, credenciais nem caminho privado completo. Ela registra apenas metadados técnicos necessários para reproduzir o defeito.

## Verificação recomendada no aparelho

1. Abra Configurações > Áudios e voz.
2. Teste um áudio padrão e um áudio substituído.
3. Caso não toque, exporte Configurações > Diagnóstico e o relatório de desempenho da sessão.
4. Confira no relatório `lastErrorCode`, `lastErrorPhase`, `lastSource`, `lastFocusResultName`, volume e eventos da tentativa.
