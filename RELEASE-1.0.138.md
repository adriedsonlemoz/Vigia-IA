# Vigia IA 1.0.138+138

## POIs enriquecidos + natureza/cicloviagem

- Pontos encontrados pelo mapa agora preservam endereço, horário de funcionamento, telefone, site, operador/marca e comodidades quando essas informações existem no OpenStreetMap.
- Lista de próximos pontos exibe um resumo adicional, e os dados enriquecidos continuam disponíveis nos pacotes offline.
- O catálogo de POIs foi separado em `RouteExplorerPoiCatalog`, evitando ampliar ainda mais a lógica de rede/tags dentro da tela do mapa.
- Novas categorias próprias: Camping, Mirantes, Cachoeiras e Mercados/Suprimentos; Oficinas continuam cobrindo bicicletarias e estações de reparo.
- Filtros rápidos ganham Natureza e Bike/viagem; configurações do mapa permitem ativar/desativar cada nova categoria individualmente.
- Instalações atualizadas da 1.0.137 recebem as novas categorias uma vez, sem exigir limpar dados ou reinstalar o aplicativo.
- A seleção dos resultados reserva diversidade mínima entre categorias antes de completar pelos locais mais próximos, evitando que restaurantes/postos ocultem pontos de cicloviagem em áreas densas.
- A consulta Overpass usa `nwr` para buscar nós, vias e relações sem triplicar cada cláusula.
