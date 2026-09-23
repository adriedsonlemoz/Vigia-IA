# Vigia IA 1.0.99+99

## Mapas offline baixáveis no app

- O gerenciador pode baixar uma **região** ou um **corredor do trajeto** usando uma fonte raster autorizada configurada pelo usuário.
- A integração inicial suporta Stadia Maps Alidade Smooth com API key própria, protegida pelo Android Keystore. Nenhuma chave é incluída no código-fonte.
- Antes do download, o app estima quantidade de tiles/tamanho, confere espaço livre e aplica margem de segurança do limite de cache.
- O progresso mostra tiles e bytes; o processo pode ser pausado, retomado ou cancelado.
- O resultado é um MBTiles raster SQLite validado, com bounds, níveis de zoom, provedor e expiração estimada persistidos.
- Importar `.mbtiles` e baixar um MBTiles pronto por link direto continuam disponíveis.

## Rota

- A sessão compartilhada pode ser **Pausada/Continuada** sem somar o deslocamento ocorrido durante a pausa.
- A retomada cria um novo segmento visual para não desenhar uma linha artificial entre os dois pontos.
- A tela completa pode exportar a rota em **GPX 1.1** pelo seletor nativo do Android, com segmentos, coordenadas, elevação e horário quando disponíveis.

## Validação

Executar `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh`. Como Flutter/Dart/Android SDK não estão disponíveis no ambiente local desta entrega, `flutter analyze`, `flutter test` e o build do APK precisam ser confirmados no workflow.
