# Vigia IA 1.0.100+100

## Buildfix Android-APK-68

- Corrigidos os quatro apontamentos do `flutter analyze` que interrompiam o workflow.
- O módulo MBTiles do mini-mapa reutiliza `_refresh()` do `State`, removendo duas ocorrências de `invalid_use_of_protected_member`.
- A assinatura do stream de localização usa `??=`, removendo `prefer_conditional_assignment`.
- A comparação de validade do cache offline não usa mais um `!` redundante, removendo `unnecessary_non_null_assertion`.
- Nenhuma funcionalidade introduzida na 1.0.99 foi removida ou modificada.

## Validação

Executar `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh`. Como Flutter/Dart/Android SDK não estão disponíveis neste ambiente, `flutter analyze`, `flutter test` e o build do APK precisam ser confirmados no workflow.
