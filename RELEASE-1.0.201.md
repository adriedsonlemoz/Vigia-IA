# Vigia IA 1.0.201+201

Correção do teste de configuração do provedor de mapa identificada no workflow Android 164.

## Testes

- O teste `test/map_view_settings_provider_test.dart` agora chama `TestWidgetsFlutterBinding.ensureInitialized()` antes de acessar `getApplicationSupportDirectory()`.
- Isso corrige a exceção `Binding has not yet been initialized` do `path_provider` observada no `flutter test`.
- Nenhum arquivo ou funcionalidade do mapa atual, Google Maps, GPS, rotas, POIs ou mapas offline foi removido.

## Documentação e versão

- Versão atualizada para `1.0.201+201`.
- `CHANGELOG.md`, `README.md`, `ARCHITECTURE.md`, `VALIDATION.md`, catálogo de Novidades, metadados e verificador sincronizados.
- User-Agents do aplicativo atualizados para `1.0.201`.

## Validação

O workflow 164 mostrou `flutter analyze` com `No issues found!`; a única falha registrada nos testes foi `map_view_settings_provider_test.dart`, causada pelo binding não inicializado. A correção adiciona a inicialização explícita recomendada para testes Flutter.

Após a correção, executar:

```bash
python3 tool/check_version_sync.py
bash tool/verify_project.sh
flutter analyze
flutter test
```
