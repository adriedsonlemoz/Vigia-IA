# Vigia IA 1.0.127+127

## Foco

Esta versão evolui a câmera do mapa para uso contínuo em bike e viagem. A coordenada GPS permanece real, mas o enquadramento passa a mostrar mais estrada à frente e pode trabalhar com Norte fixo ou com o rumo do deslocamento apontando para o topo.

## Principais mudanças

- Visão à frente posiciona o usuário abaixo do centro usando offset nativo do mapa.
- Zoom padrão mais aberto e atalhos **Perto / Região / Rota**.
- Modo **Norte fixo** e modo **Acompanhar direção** com heading filtrado da etapa anterior.
- Dead-zone de rotação e limite mínimo de velocidade evitam jitter quando parado.
- Rota enquadra percurso, posição e destino em uma visão geral.
- Preferências visuais são persistidas separadamente do estado GPS/percurso.
- Marcadores estáticos permanecem retos quando o mapa gira.
- Zoom manual pode continuar acompanhando a posição.
- Ticker do percurso deixa de provocar movimentos de câmera sem GPS novo.
- PiPs começam abaixo da nova barra de enquadramento.

## Compatibilidade

- `MapRouteService`, filtros GPS 1.0.126, navegação até destino, RouteExplorer, offline, GPX e câmeras existentes foram preservados.
- O padrão inicial continua **Norte fixo**, evitando mudança inesperada para instalações existentes; o usuário pode ativar acompanhamento por direção.
- Não foi adicionada dependência paga ou novo provedor de mapa nesta etapa.

## Validação

- `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh` devem passar antes do empacotamento.
- O ambiente desta entrega não possui Flutter/Dart SDK; `flutter analyze`, `flutter test` e build Android precisam ser confirmados no workflow com SDK.
