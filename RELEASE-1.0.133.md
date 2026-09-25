# Vigia IA 1.0.133+133

Refinamento visual do mapa após revisão em vídeo de uso real.

## Principais mudanças

- clustering de POIs e densidade adaptativa ao zoom, com redução de rios/pontes em visões amplas;
- cores/ícones por categoria e cluster numérico que aproxima ao toque;
- HUD superior mais leve e controles laterais reduzidos;
- barra de gravação compacta com tempo/distância durante o percurso;
- contraste melhor das barras do Android sobre mapas claros;
- PiPs com bolha minimizada, duplo toque para tamanho, arranjo automático da segunda câmera e troca entre slots internos;
- card do POI não duplica a informação quando o mesmo ponto já está em navegação;
- testes de política de POIs e UX atualizados.

## Compatibilidade

Mantém GPS filtrado, gravação/GPX, navegação direta, RouteExplorer, pacotes de POI offline, MBTiles, camadas de mapa, duas câmeras e integração Home/Monitor das versões anteriores.

## Validação

Executar `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh`. Flutter/Dart devem executar `flutter analyze`, `flutter test` e o build Android no workflow quando disponíveis.
