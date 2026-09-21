# Validação — Vigia IA 1.0.69+69

Data: 2026-09-21. Base preservada: 1.0.68+68; correção pontual aplicada sobre o serviço de fala.

## Executado nesta entrega

O Android-APK-37 confirmou que preparação, dependências e verificação preventiva da 1.0.68 passaram. A falha ficou restrita ao lint `use_null_aware_elements` em `speech_service.dart:117`, corrigido na 1.0.69.

| Verificação | Resultado |
|---|---|
| `bash tool/verify_project.sh` | Passou, incluindo sincronização de versão, identidade, contratos e limites dos arquivos principais |
| Novos contratos `tool/verify_release_67.py` | Passaram: buffers, cadência, orçamento, áudio, descarte de fala antiga, câmera, tela inteira e telemetria |
| Sintaxe Dart com parser Tree-sitter | 176 arquivos de código/teste, sem erro sintático detectado |
| Sintaxe Kotlin com parser Tree-sitter | 5 arquivos nativos, sem erro sintático detectado |
| Sintaxe dos scripts shell/Python | 4 scripts shell e 2 scripts Python válidos |
| JSON e XML do projeto | Estruturas válidas |
| Espelhos nativos e bootstrap | Fontes `tool/android/` e `android/app/.../` sincronizadas, incluindo os dois novos componentes |
| Áudios padrão | 78 arquivos decodificados integralmente pelo FFmpeg, sem erro; bytes iguais aos da base 1.0.66 |
| ZIP de entrega | Integridade CRC, arquivos obrigatórios, versão e correspondência com o diretório-fonte conferidos antes da entrega |

Parsers usados: tree-sitter 0.26.0, tree-sitter-dart 0.1.0 e tree-sitter-kotlin 1.1.0. Esses parsers verificam sintaxe; não resolvem tipos, APIs do SDK ou comportamento em execução.

## Testes adicionados

Foram acrescentados **16 casos de teste Flutter**, cobrindo:

- cores, letterbox, interpolação, normalização float32 e reutilização do tensor;
- rotação, espelhamento, padding/strides YUV/BGRA e timestamp da câmera;
- confirmação entre frames lentos, ausência observada, permanência, repetição, evidência forte e idade máxima dos frames;
- política de troca de modelo após aquecimento e lentidão sustentada;
- erro assíncrono de áudio com fallback TTS, desligamento da voz, fila com mensagem mais recente, prioridade e descarte de fala antiga;
- separação de inferência nativa/transferência, contexto de áudio no JSON e alinhamento das colunas CSV.

Os testes existentes foram preservados. Expectativas de versão e nomenclatura da telemetria foram atualizadas.

## Pendente no workflow e no dispositivo

**Não foi possível executar `flutter analyze`, `flutter test` ou compilar o APK neste ambiente, que não possui Flutter/Android SDK.** Portanto, esta entrega não afirma que o analyze, os testes Flutter ou o build passaram. Eles continuam como etapas obrigatórias do workflow incluído.

Também não houve execução em celular ou emulador. Ganho de FPS, precisão, latência até o som, saída por alto-falante/Bluetooth, foco de áudio, rotação, recorte do vídeo e retorno do segundo plano precisam de teste com o APK novo.

O roteiro está em [RELEASE-1.0.67.md](RELEASE-1.0.67.md). Os marcadores dos modelos no ZIP devem ser substituídos pelos arquivos reais por `tool/fetch_model.sh`, como o workflow já faz.
