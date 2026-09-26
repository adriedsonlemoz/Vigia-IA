# Vigia IA 1.0.168+168

## Escopo
Etapas 6 e 7 do plano do mapa, agrupadas por solicitação: polimento visual do HUD + temas e cores do mapa.

## Entrega
- Badge de locais saiu da área recortada do botão, usa largura adaptativa e compacta contagens acima de 99 para `99+`.
- Dock de câmera/3D/áudio/zoom/centralizar/locais recebeu espaçamento uniforme e sombras mais leves, preservando as áreas de toque.
- Card `Locais próximos` foi reduzido e separa quantidade, origem Online/Offline e atualização em andamento.
- Banner inferior de navegação foi condensado para duas linhas, mantendo próxima instrução, distância da manobra, restante, tempo, progresso e encerramento.
- Aparência do mapa agora é independente da camada base e oferece Padrão, Escuro, Alto contraste e Bike/Viagem.
- MapLibre 3D usa style vetorial coerente com o tema, enquanto o 2D aplica tratamento de cor aos tiles; Satélite permanece sem filtro destrutivo.
- Rota, contorno, posição atual, destino e prédios 3D usam paleta própria por tema para manter contraste.
- Modos Manual, seguir Sistema e Dia/noite pelo relógio local foram adicionados sem depender de horário online.

## Validação local
Sincronização de versão, `verify_project.sh`, catálogo de áudio, contratos legados, sintaxe shell/Python, JSONs, workflow Android único, regra de Novidades current-only e ausência de APK/AAB foram aprovados antes do pacote final. Flutter/Dart não estão instalados neste ambiente; `flutter analyze`, `flutter test` e build release precisam ser confirmados pelo workflow.
