# Vigia IA 1.0.98+98

## Mapa adaptativo e rota persistente

- O Monitor agora oferece **Automático**, **Sempre mostrar** e **Ocultar** para o mini-mapa. No automático, o mapa libera espaço no uso doméstico e reaparece com Bike, rota ativa ou deslocamento recente detectado pelo GPS.
- `MapRouteService` unifica o trajeto do mini-mapa e do mapa completo, incluindo posição, distância, início/fim, cronômetro e estado de rastreamento.
- A sessão da rota é persistida em `map_route_state.json` para sobreviver à troca de telas e reinício do aplicativo.
- O mapa completo identifica a fonte como **Online**, **Offline** ou **Mapa local** e preserva a câmera principal flutuante e arrastável.

## Mapas offline

- O gerenciador agora pode **importar MBTiles do aparelho** usando o seletor nativo do Android, além do download por link direto.
- Foram adicionados os planejadores **Região atual**, **Selecionar região** e **Trajeto**, com estimativa de tiles, tamanho aproximado e espaço livre.
- Esses planejadores preparam a área, mas a obtenção do arquivo continua exigindo um pacote/fonte autorizada; o Vigia IA não faz prefetch em massa de `tile.openstreetmap.org`.

## Validação local

Executar `tool/verify_project.sh` e `python3 tool/check_version_sync.py`. Flutter/Dart/Android SDK dependem do workflow quando indisponíveis no ambiente local.
