# Vigia IA 1.0.69+69 — Buildfix do serviço de fala

## Correção

O Android-APK-37 avançou pela preparação do Android, download dos modelos, dependências e `tool/verify_project.sh`, mas o `flutter analyze` encerrou o workflow com um único lint em `lib/services/speech_service.dart:117`: `use_null_aware_elements`.

A entrada opcional de telemetria foi atualizada de um `if` com pattern de null-safety para o elemento de mapa null-aware do Dart 3.8+:

```dart
'error': ?error,
```

Assim, a chave `error` continua sendo adicionada somente quando existe texto de erro, sem alterar a semântica do relatório.

## Escopo preservado

- Detecção e troca de modelo da IA.
- Regras Inteligentes e confirmação de alertas.
- Áudio integrado, TTS e fallback.
- Tela inteira horizontal.
- Telemetria e diagnóstico.

## Validação

- `tool/verify_project.sh`: deve confirmar `1.0.69+69`.
- `flutter analyze`, `flutter test` e build Android dependem de um ambiente com Flutter/Android SDK e devem ser confirmados no workflow.
