# Vigia IA 1.0.234+234 — refatoração gradual, etapa 2

Data: 2026-10-15. Base: ZIP 1.0.233+233.

## Mudança controlada

A faixa de telemetria de cinco cartões foi extraída de `map_monitoring_screen.dart` para `lib/widgets/map_telemetry_strip.dart` com o componente de cartão interno. A ordem, exibição, formatação e os callbacks foram preservados. Nenhum serviço, cache, timer, listener, permissão ou formato de dados foi alterado.

## Validação

A verificação preventiva Python e os testes estruturais devem passar antes do empacotamento; foram adicionados cinco testes Dart/Flutter de regressão. `flutter analyze --fatal-infos --fatal-warnings`, `flutter test` e APK Android ainda **não** foram executados sem SDK Flutter; confirmação pendente no GitHub Actions.

## Compatibilidade

`versionName=1.0.234` e `versionCode=234` derivam de `pubspec.yaml`. Nenhuma migração e nenhuma mudança de compatibilidade de dados.
