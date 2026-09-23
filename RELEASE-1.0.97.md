# Vigia IA 1.0.97+97

## Correção

- Corrige a falha do workflow registrada em `Android-APK-65-logs.zip`.
- `flutter analyze` já havia passado; a única falha era `test/app_metadata_test.dart`, ainda fixado em `1.0.95+95` enquanto a aplicação estava em `1.0.96+96`.
- O teste foi sincronizado para a nova entrega `1.0.97+97`.
- `tool/check_version_sync.py` agora valida também as expectativas desse teste, evitando que a divergência volte a escapar da verificação preventiva.
- Nenhuma funcionalidade de mapas offline, câmera flutuante, IA, monitoramento ou gravação foi alterada.

## Validação local

Executar `tool/verify_project.sh` e `python3 tool/check_version_sync.py`. Flutter/Dart/Android SDK dependem do workflow quando indisponíveis no ambiente local.
