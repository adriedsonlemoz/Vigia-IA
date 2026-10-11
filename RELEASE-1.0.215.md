# Vigia IA 1.0.215+215

## Ajustes de compatibilidade

- Buildfix do workflow Android APK #179, interrompido no `flutter analyze`.
- `map_monitoring_screen.dart`: uso de `TextStyle` em tempo de execução corrigido para seleção compacta de fonte; callbacks sem parâmetros úteis usam coringas `_` válidos.
- Interface e funcionalidades da 1.0.214 mantidas: cartões horizontais, menu Vigia IA, seleção por toque longo, instruções/gravação integradas e atribuição OSM.

## Validação

Verificação preventiva local e integridade do ZIP verificadas. `flutter analyze`, `flutter test` e `flutter build apk --release` precisam ser executados no GitHub Actions; não há Flutter SDK no ambiente de preparação.
