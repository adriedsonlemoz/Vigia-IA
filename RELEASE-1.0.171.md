# Vigia IA 1.0.171+171 — manutenção do build 133

Esta versão corrige exclusivamente os apontamentos de análise estática encontrados no build 133. Não inicia funcionalidades novas e não altera o comportamento funcional do mapa.

## Ajustes aplicados

- `MapWeatherService._finiteDouble` e `_finiteInt` deixam de usar bindings locais que acionavam quatro `prefer_final_locals`; a conversão e as validações de faixa permanecem iguais.
- `MapNavigation3DView` remove o import `dart:math` sem uso.
- `MapNavigation3DView` remove `_lastCameraPointAt`, campo que recebia valor mas nunca era consultado.
- O verificador passa a bloquear especificamente a reintrodução desses padrões/símbolos que fizeram o build 133 falhar no analyzer.

## Novidades da atualização

Não há mudança visual nesta release técnica. Por isso o catálogo identifica `1.0.171+171`, mas a popup não é exibida e não reutiliza textos de versões anteriores. O histórico completo permanece em `Sobre > Mudanças`.

## Escopo preservado

Mapa 2D/3D, câmera adaptativa, Norte/Direção/Rota, Valhalla, clima ESP32 + online, prédios best-effort, terrain desativado sem API/fonte DEM segura, inicialização MapLibre por estágios, fallback de style/2D, HUD, offline, POIs, câmeras e gravação permanecem funcionalmente inalterados.

## Validação

Executar `python3 tool/check_version_sync.py`, `bash -n tool/verify_project.sh` e `bash tool/verify_project.sh`; validar JSONs, scripts, workflow único, conteúdo do ZIP e repetir tudo em extração limpa. `flutter analyze`, `flutter test` e build Android devem ser executados somente em ambiente com os SDKs disponíveis.
