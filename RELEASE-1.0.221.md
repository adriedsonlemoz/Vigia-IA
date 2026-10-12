# Vigia IA 1.0.221+221

- Buildfix do workflow Android APK #185: miniaturas de camadas usam `dart:ui.Path` explicitamente, sem confusão com a classe `Path<LatLng>` do Flutter Map.
- Rádio online: filtro genérico de tipo não nulo, blocos `if` corrigidos e construtor do histórico ajustado, preservando a API pública.
- Removidos dois elementos não utilizados (`_mapStyleIcon`, `_KeyMetric`).
- Mantidos mapas offline, configuração Stadia, prévia de rotas, planejamento por dias e rádio da 1.0.220.
- Acrescentado verificador de regressão dos diagnósticos reportados no APK #185.

**Validação:** scripts de projeto e regressão em ambiente local; `flutter analyze`, `flutter test` e compilação Android completos pendentes do CI.
