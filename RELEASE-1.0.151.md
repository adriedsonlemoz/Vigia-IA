# Vigia IA 1.0.151+151

Correção do build Android-APK-114 após a reformulação visual do mapa.

## Corrigido

- `flutter analyze` não é mais bloqueado pelo campo `_offlineTileError` sem leitura.
- O estado morto foi removido de `MapMonitoringScreen`.
- Erros ao abrir pacotes MBTiles continuam registrados via `debugPrint`, preservando diagnóstico sem adicionar estado desnecessário.

## Preservado

- HUD 1.0.150, rotação manual, POIs, navegação, camadas, gravação, PiPs e suporte offline permanecem sem mudança funcional.
