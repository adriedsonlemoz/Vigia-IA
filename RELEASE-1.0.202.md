# Vigia IA 1.0.202+202

Ajuste da validação automatizada identificado no workflow Android 165.

## Testes

- `test/map_view_settings_provider_test.dart` inicializa o binding Flutter e registra um canal de teste para `path_provider`.
- O teste `getApplicationSupportDirectory()` passa a funcionar sem depender de uma implementação nativa de plugin no ambiente de `flutter test`.
- Nenhuma funcionalidade de mapa, Google Maps, GPS, rotas, POIs ou mapas offline foi removida ou alterada.

## Documentação e versão

- Versão atualizada para `1.0.202+202`.
- `CHANGELOG.md`, `README.md`, `ARCHITECTURE.md`, `VALIDATION.md`, catálogo de Novidades, metadados e verificador sincronizados.
- User-Agents do aplicativo atualizados para `1.0.202`.

## Validação

O workflow Android 165 apresentou `flutter analyze` sem problemas e uma única falha de teste: `MissingPluginException` no canal `path_provider`. Esta versão trata especificamente essa dependência no teste.
