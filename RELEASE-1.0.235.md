# Vigia IA 1.0.235+235 — refatoração gradual, etapa 3

Data: 2026-10-15. Base: ZIP completo 1.0.234+234.

## Mudança controlada

A prévia visual de rotas, incluindo comparação de alternativas e botões de ação, foi transposta para `lib/widgets/map_route_preview_card.dart`. Sem alterações de dados, callbacks, mensagens, layout, navegação ativa ou gravação. Serviços permanecem sob o controle da tela principal. Não há migrações de dados.

## Validação e limites

Verificadores estruturais/Python e integridade de arquivo ZIP podem ser executados localmente. Testes Flutter adicionados para estados de prévia e toque. **Não foi possível executar `flutter analyze`, `flutter test`, Gradle ou APK por ausência de SDK; necessários em CI.** Não considerar a versão compilada sem resultado do CI.

## Compatibilidade

`versionName=1.0.235`, `versionCode=235`, derivados do `pubspec.yaml`. Nenhuma configuração anterior é apagada ou migrada.
