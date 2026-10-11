# Vigia IA 1.0.216+216

## Pesquisa automática de cidades e comunidades

- Busca automática no mapa revisada para usar filtro geográfico bbox no Overpass em vez de `around`, incluindo nós, caminhos e relações etiquetados como cidades, vilas e comunidades.
- Limites de consulta realistas (18 s para a região próxima e 24 s para a expansão), com servidor alternativo se o principal estiver indisponível na primeira etapa.
- O cache não armazena consultas sem localidades como sucesso por três dias; versão anterior do índice é migrada sem apagar as cidades salvas.
- Botão **Atualizar cidades próximas** junto ao título da lista para tentar novamente, sem texto obrigatório.
- Estados de interface distinguem busca em andamento, indisponibilidade online, ausência de dados e modo offline.
- Pesquisa textual no Nominatim, rotas, mapas offline e gravação preservados.

## Validação

Executar `tool/verify_project.sh`, testes de consulta de proximidade e workflow Flutter/Android. O ambiente de preparação não possui SDK Flutter para compilar/analisar o APK.
