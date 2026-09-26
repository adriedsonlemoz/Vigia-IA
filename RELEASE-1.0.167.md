# Vigia IA 1.0.167+167

## Escopo
Etapas 4 e 5 do plano do mapa, agrupadas por solicitação: seletor de transporte ultracompacto + reforma das Configurações do mapa.

## Entrega
- Seletor de Bicicleta, Moto, Carro e A pé em uma única linha, com seleção atual destacada e Safe Area preservada.
- Perfis de roteamento continuam `bicycle`, `motorcycle`, `auto` e `pedestrian`; última escolha permanece persistida.
- Configurações reorganizadas em seções expansíveis para Busca, Categorias, Alertas, Áudio, Mapas offline, Gravação de percurso e Navegação.
- Categorias em grade uniforme 2/3 colunas e controles compactos para raio, busca durante deslocamento e distância de alerta.
- Controles já existentes de áudio, offline, GPX, gravação e orientação continuam disponíveis no painel reorganizado.

## Validação local
Sincronização de versão, `verify_project.sh`, catálogo de áudio, contratos estruturais, sintaxe shell/Python, JSONs, workflow Android único e ausência de APK/AAB foram aprovados localmente. Flutter/Dart não estão instalados neste ambiente; `flutter analyze`, `flutter test` e o build release precisam ser confirmados pelo workflow.
