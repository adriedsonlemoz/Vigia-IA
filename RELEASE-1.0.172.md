# Vigia IA 1.0.172+172 — manutenção do build 134

Esta versão corrige exclusivamente o último warning de análise estática encontrado no build 134. Não inicia funcionalidades novas e não altera o comportamento funcional do mapa.

## Ajuste aplicado

- `MapNavigation3DView._syncCamera` deixa de criar a variável local `recordedAt`, que não era lida em nenhuma condição após os refinamentos anteriores.
- A fonte temporal do ponto continua preservada no modelo e nas rotinas que realmente a utilizam.
- O verificador passa a bloquear a reintrodução desta variável local órfã.

## Novidades da atualização

Não há mudança visual nesta release técnica. O catálogo identifica `1.0.172+172`, mas a popup não é exibida e não reutiliza textos de versões anteriores. O histórico completo permanece em `Sobre > Mudanças`.

## Escopo preservado

Mapa 2D/3D, câmera adaptativa, Norte/Direção/Rota, Valhalla, clima ESP32 + online, prédios best-effort, terrain desativado sem API/fonte DEM segura, inicialização MapLibre por estágios, fallback de style/2D, HUD, offline, POIs, câmeras e gravação permanecem funcionalmente inalterados.

## Validação

Executar `python3 tool/check_version_sync.py`, `bash -n tool/verify_project.sh` e `bash tool/verify_project.sh`; validar JSONs, scripts, workflow único, conteúdo do ZIP e repetir tudo em extração limpa. `flutter analyze`, `flutter test` e build Android devem ser executados somente em ambiente com os SDKs disponíveis.
