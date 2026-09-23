# Vigia IA 1.0.86+86

## Mapa e GPS — primeira etapa

- Adicionada a tela **Mapa do monitoramento** ao Modo Bike.
- Integração com OpenStreetMap por `flutter_map`, sem chave de API nesta etapa.
- GPS local por `geolocator`, com posição atual, precisão, velocidade e horário da última atualização.
- Botão para recentralizar o mapa após navegação manual.
- Início/encerramento de rota com linha do trajeto, marcadores de início/fim, distância acumulada e cronômetro.
- Tratamento de localização desligada, permissão negada e permissão bloqueada permanentemente.
- Adicionadas somente permissões de localização durante o uso; localização em segundo plano não foi habilitada.

## Escopo preservado

- IA, câmeras, transmissão LAN, ESP32, Histórico e telemetria existentes não foram refatorados nesta etapa.
- O trajeto ainda é temporário e existe somente durante a sessão do mapa.
- Eventos da IA no mapa, persistência de rotas, mini mapa no Monitor e mapas offline ficam para as próximas etapas.

## Validação

- Verificações estáticas do projeto e sincronização de versão executadas localmente.
- O ambiente desta entrega não possui Flutter/Android SDK completo; `flutter analyze`, `flutter test` e o build Android precisam ser confirmados no workflow.
