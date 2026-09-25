# Vigia IA 1.0.132+132

Buildfix do Android-APK-99.

## Correções

- Corrige dois erros `undefined_class` em `map_monitoring_screen.dart` adicionando o import explícito de `OfflinePoiPackage`.
- Remove `package:flutter/foundation.dart` redundante de `map_route_service.dart`, eliminando `unnecessary_import`.
- Reforça `tool/verify_project.sh` para detectar a ausência desse import e a reintrodução do import redundante.
- Mantém sem alterações funcionais o ciclo completo do mapa entregue na 1.0.131.

## Validação

- `python3 tool/check_version_sync.py`
- `bash tool/verify_project.sh`
- Integridade do ZIP e ausência de APK/AAB dentro do fonte.
- `flutter analyze`, `flutter test` e build Android devem ser reconfirmados pelo workflow com Flutter 3.44.9.
