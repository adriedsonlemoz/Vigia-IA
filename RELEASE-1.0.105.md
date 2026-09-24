# Vigia IA 1.0.105+105

Correção de build baseada no Android-APK-73, preservando as funcionalidades entregues na 1.0.104.

## Correções

- Removido `dart:typed_data` de `lib/screens/map_monitoring_screen.dart`, pois os elementos usados já são disponibilizados por `package:flutter/foundation.dart`.
- Removido `package:camera/camera.dart` de `lib/sources/local_camera_source.dart`, pois nenhum símbolo desse pacote é referenciado diretamente pelo arquivo.
- Adicionadas guardas em `tool/verify_project.sh` para detectar a reintrodução desses dois imports enquanto permanecerem desnecessários.

## Versionamento

- Versão: `1.0.105+105`.
- `pubspec.yaml`, `AppMetadata`, `app_identity.json`, tela Mudanças, README, CHANGELOG, ARCHITECTURE, VALIDATION, testes e verificadores sincronizados.
- Android continua derivando `versionName` e `versionCode` de `flutter.versionName` / `flutter.versionCode`, portanto o valor canônico permanece no `pubspec.yaml`.

## Validação

Executar `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh`. Como Flutter/Dart/Android SDK não estão disponíveis neste ambiente, `flutter analyze`, `flutter test` e o build do APK ainda precisam ser confirmados pelo workflow.
