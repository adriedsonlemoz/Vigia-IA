# Vigia IA 1.0.152+152

Primeira etapa da navegação em perspectiva 3D durante uma rota ativa.

## Adicionado

- Seletor de modo de deslocamento antes de navegar: Bicicleta, Moto, Carro ou A pé.
- `MapTravelMode` com persistência no destino e compatibilidade com destinos antigos.
- Renderer `MapNavigation3DView` em MapLibre para rotas online, com pitch de 54°, rotação por rumo, acompanhamento de posição e desenho da rota/destino.
- Botão para alternar entre navegação 3D e o mapa 2D durante a rota.

## Roteamento

- Valhalla passa a receber o perfil correspondente ao modo escolhido: `bicycle`, `motorcycle`, `auto` ou `pedestrian`.
- Alternativas, manobras, voz, progresso e recálculo continuam usando a infraestrutura existente.

## Compatibilidade

- O mapa principal continua em FlutterMap.
- Offline/MBTiles permanece no renderer 2D atual; a navegação 3D desta etapa exige rota online carregada.
- Esta entrega implementa perspectiva 3D de navegação, ainda sem prédios ou terreno extrudados.
