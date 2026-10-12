# Vigia IA 1.0.218+218

## Ajustes de compatibilidade no mapa

- Corrigido o retorno antecipado da atualização da prévia com chaves explícitas, conforme o analisador Flutter.
- Substituída a condição redundante do controle opcional de gravação por um elemento null-aware no painel de navegação.
- Preservados painel compacto, prévia de alternativas, gravação, roteiro salvo e plano de cicloviagem da 1.0.217.

## Estado de validação

- Logs de Android APK #182 analisados; a etapa de verificação preventiva estava aprovada e `flutter analyze` encontrou somente duas observações.
- A inspeção local e `tool/verify_project.sh` não substituem Flutter analyze/test e o build Android de CI.
