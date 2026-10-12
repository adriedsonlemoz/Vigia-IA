# Vigia IA — Release 1.0.225+225

Data: 12/10/2026 · versionCode 225

## Alterações

- Detalhes de pontos úteis identificam o que é OSM mapeado, cache de consulta ou pacote salvo.
- Data da consulta preservada em JSON e pacotes, com idade desconhecida para registros legados.
- HTTP 429/503/504 gera período de espera por servidor Overpass, inclusive `Retry-After` quando presente, e falha parcial preserva resultados.
- Espaçamento mínimo local de 2 s entre tentativas Overpass; consultas progressivas mantidas.
- Distância indicada em linha reta, sem presumir horário de abertura, atendimento de emergência ou disponibilidade de água.
- POIs sem nome explícito são rotulados como “sem nome” no lugar de estabelecimento “próximo”.
- Painel de detalhes ocupa altura ajustada aos metadados, preservando rolagem e ações anteriores.
- Nenhuma alteração planejada em câmeras, IA local, rádio, ESP32, gravação ou roteamento.

## Validação

A execução local de `flutter analyze`, `flutter test` e Gradle não é possível sem SDK Flutter/Android. Validar no GitHub Actions antes de declarar sucesso de APK. Teste manual das versões 1.0.223 a 1.0.225 somente após CI aprovado e instalação em aparelho.

## Limites

Data da consulta **não é** a data de edição no OSM nem garantia de operação. Instâncias públicas Overpass não oferecem SLA e a pesquisa pode ser parcial. Sem ligação ao estabelecimento, não há garantia de atendimento ou água potável.
