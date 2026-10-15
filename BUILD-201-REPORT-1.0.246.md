# Relatório Android-APK-201 — correção 1.0.246+246

## Diagnóstico confirmado nos logs enviados

- Workflow sobre a 1.0.245+245; `tool/verify_project.sh` e 60 testes Python aprovados.
- `flutter analyze --fatal-infos --fatal-warnings` falhou com **1 issue**: `lib/screens/mcrp_camera_screen.dart:437:56`, regra `curly_braces_in_flow_control_structures`.
- Linha original: `detector == null || generation != _generation) return;` na guarda da função `_onFrame`.
- `flutter test`, cobertura e build APK não foram executados no workflow #201 por causa do gate de análise.

## Mudança

- Inclusão do bloco `{ return; }` para o mesmo `if` de proteção de IA, mantendo todos os predicados e a lógica original.
- `tool/check_build201_lint_246.py` e `tool/test_build201_lint_246.py` para regressão, com mudanças mínimas no código de produção.
- Versão pública e build avançados para 1.0.246+246. Integração com Minha Câmera e caminho de IA preservados.

## Limites de verificação

- `bash tool/verify_project.sh`, testes estruturais, verificação CRC ZIP, JSON/XML/YAML e sintaxe Bash locais.
- Sem Flutter ou SDK Android localmente. `flutter analyze`, `flutter test` e APK precisam de confirmação pelo próximo workflow.
