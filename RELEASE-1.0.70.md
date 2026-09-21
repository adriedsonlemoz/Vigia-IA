# Vigia IA 1.0.70+70

## Correção

O Android-APK-38 parou na verificação preventiva antes do `flutter analyze` porque o ZIP 1.0.69 não continha o arquivo oculto `.gitignore`.

A 1.0.70 corrige o processo de entrega e inclui novamente o `.gitignore`, com proteção explícita para:

- `*.jks`;
- `*.keystore`;
- `android/key.properties`.

A verificação preventiva continua rejeitando qualquer arquivo de keystore presente no projeto. Nenhuma função da IA, câmera, áudio, alertas ou tela inteira foi alterada.

## Validação

- `tool/check_version_sync.py`: esperado em 1.0.70+70.
- `tool/verify_project.sh`: deve passar com o `.gitignore` presente.
- `flutter analyze`, `flutter test` e build Android dependem do workflow com Flutter/Android SDK.
