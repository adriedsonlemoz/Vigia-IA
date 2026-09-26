# Vigia IA 1.0.150+150

## Revisão visual e funcional do mapa

Esta versão reorganiza o mapa Bike/Viagem para se aproximar do layout visual de referência sem remover os recursos já consolidados de rota, POIs, offline, câmeras e IA.

### Principais mudanças

- Engrenagem de configurações no topo esquerdo.
- `Perto/Região/Rota` reposicionado para o topo.
- Camadas em botão próprio no topo direito.
- `Próximos pontos` em marcador lateral dedicado com contador.
- Card `Locais próximos` com atalho de câmera logo abaixo.
- Velocidade, altitude, bússola e GPS em cards quadrados/uniformes.
- Bússola agora explica sua função e alterna Norte fixo/Acompanhar direção.
- Rotação manual do mapa reativada.
- Card compacto de POI com `Detalhes` e `Navegar`.
- Painel completo de POI com altura adaptativa para reduzir espaço vazio.
- `Gravar` fixado no canto inferior direito.
- Reservas de PiP/HUD recalibradas para o novo layout.

## Compatibilidade

- Nome público: Vigia IA
- Nome técnico: vigiaia
- Package Android: `com.vigiaia.app`
- Versão: `1.0.150+150`

## Validação local

Executar `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh`. Flutter/Dart não estão disponíveis no ambiente de edição atual; `flutter analyze`, `flutter test` e o build Android devem ser confirmados pelo workflow.
