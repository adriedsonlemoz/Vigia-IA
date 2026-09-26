# Vigia IA 1.0.177+177

## Manutenção dos builds 136 e 137

- Corrigida a análise estática da pesquisa do mapa: `MapDestinationSearchService` usava `RouteExplorerCategory.label`, definido pela extensão `RouteExplorerCategoryX`, sem importar o arquivo que declara a extensão.
- O serviço agora importa explicitamente `models/route_explorer_models.dart`; os rótulos de Postos, Restaurantes, Camping, Paradas e demais categorias continuam centralizados no modelo existente.
- Nenhuma lógica de busca online/offline, POIs, Valhalla, planejamento Bike, histórico de ritmo, mapa 2D/3D, clima, ESP32, câmeras ou GPX foi removida.
- A versão é técnica e não exibe popup vazia de Novidades.

## Validação

- O verificador preventivo cobre o import necessário para o getter de extensão usado pela pesquisa.
- APK/AAB permanece fora do ZIP fonte.
