# Vigia IA 1.0.147+147

## Buildfix Android-APK-110

- Corrige o erro `argument_type_not_assignable` em `MapNavigationVoicePolicy`.
- Elimina chamadas diretas ao método protegido `setState` pela extension de suporte offline.
- Remove uma asserção não nula redundante do provider MBTiles.
- Ajusta a inicialização do catálogo de Novidades para eliminar lint sem quebrar a API existente.
- Não adiciona funcionalidades nem altera as regras de navegação/POIs/offline entregues na 1.0.146.

## Validação

- `python3 tool/check_version_sync.py`.
- `bash tool/verify_project.sh`.
- `python3 tool/check_version_sync.py`: aprovado localmente.
- `bash tool/verify_project.sh`: aprovado localmente.
- `.github/workflows`: preservado sem alterações em relação à 1.0.146.
- Flutter/Dart não estão instalados neste ambiente; `flutter analyze`, `flutter test` e build Android devem ser reconfirmados no workflow.
