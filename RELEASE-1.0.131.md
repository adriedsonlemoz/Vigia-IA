# Vigia IA 1.0.131+131

## Foco

Fechamento do redesign do mapa: UX responsiva e revisão final de regressão.

## Entregue

- HUD compacto em telas estreitas/paisagem e controles consolidados;
- cluster de zoom e remoção do botão duplicado de camadas, mantendo o chip superior como seletor;
- PiPs restritos às zonas úteis do mapa, sem cobrir HUD, POI, navegação ou barra de percurso;
- correção da persistência de posição dos PiPs e ação para restaurar layout;
- menu único de ações nos PiPs pequenos;
- card de POI/atribuição mais responsivos e tela de GPS indisponível edge-to-edge;
- atualização de pacote offline pela internet com preservação do cache em falha;
- `MapUxPolicy` e testes dedicados ao layout final.

## Validação

Executar `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh`. Quando Flutter/Android SDK estiver disponível, executar também `flutter analyze`, `flutter test` e o build Android.
