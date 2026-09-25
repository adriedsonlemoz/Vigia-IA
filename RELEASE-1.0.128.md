# Vigia IA 1.0.128+128

## Foco

Buildfix do Android-APK-95. A evolução de mapa da 1.0.127 é preservada; esta versão corrige a incompatibilidade de um Material Icon que impedia a análise estática de continuar no workflow.

## Correção

- `flutter analyze` com Flutter 3.44.9 reportou `undefined_getter` para `Icons.offline_map_rounded`.
- O erro de constante na mesma linha era consequência direta desse getter inexistente.
- O botão **Mapas offline** passa a usar `Icons.download_for_offline_outlined`, já reconhecido pelo SDK e já utilizado na tela.
- `tool/verify_project.sh` passa a bloquear o identificador inválido para evitar regressão.

## Preservado

- GPS filtrado e gravação de percurso.
- Navegação até destino.
- Visão à frente, Perto/Região/Rota e Norte fixo/acompanhamento por direção.
- RouteExplorer, POIs online/offline, alertas e mapas offline.
- PiPs de câmera existentes.

## Validação

- Executar `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh`.
- Validar integridade do ZIP e ausência de APK/AAB no pacote-fonte.
- Quando Flutter/Android SDK estiver disponível, confirmar `flutter analyze`, `flutter test` e build Android.
