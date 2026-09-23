# Vigia IA 1.0.96+96

## Mapas offline e câmera no mapa completo

- Suporte a pacotes raster MBTiles no `FlutterMap`.
- Download por link direto com progresso, validação SQLite/MBTiles raster (PNG/JPG/WebP) e armazenamento interno.
- Modos Automático, Online e Offline, com pacote local como base/fallback no modo Automático e respeito ao zoom nativo do pacote.
- Gerenciador para ativar/excluir mapas baixados.
- O servidor público OpenStreetMap permanece apenas para uso online normal; o app não faz prefetch/download em massa dele.
- Câmera principal do Monitor exibida como PiP na tela completa do mapa.
- PiP arrastável por toda a área útil para evitar cobrir o trajeto.
- Modo Bike continua abrindo o mapa mesmo sem uma câmera associada.

## Validação

Executar `tool/verify_project.sh`. `flutter analyze`, `flutter test` e build Android devem ser confirmados no workflow quando Flutter/Android SDK não estiverem disponíveis localmente.
