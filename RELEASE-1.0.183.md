# Vigia IA 1.0.183+183

## Escopo

Release técnica de estabilização para permitir testar integralmente as funcionalidades implementadas até a 1.0.182.

## Alterações

- Removidas quatro asserções de nulidade redundantes em `map_monitoring_screen.dart` apontadas pelo `flutter analyze` nos builds 141 e 142.
- Nenhuma funcionalidade nova foi iniciada.
- Mapa, pesquisa, Próximos pontos, planejamento de cicloviagem, PiPs, rotas alternativas e navegação foram preservados.

## Validação

- `check_version_sync.py` e `verify_project.sh` devem passar na árvore e na extração limpa do ZIP.
- Flutter/Dart não estão disponíveis localmente neste ambiente; `flutter analyze`, `flutter test` e o build Android ficam para o workflow.
