# Vigia IA 1.0.210+210 — Vigia Maps (primeira etapa)

## Entrega

- Consumo de GPS sob demanda: uma assinatura quando mapa está visível ou gravação/navegação precisa de dados; evita `getCurrentPosition()` redundante enquanto a assinatura atende o mapa.
- Isolamento gradual: serviço de clima não aciona varreduras ESP32 ao abrir mapas. Sensores existentes permanecem integrados se estiverem ativos.
- Snapshots do percurso e geometria renderizada reaproveitados em reconstruções enquanto o percurso não muda, melhorando o uso de memória em trilhas longas.
- Diagnóstico exportável de mapas, sem coordenadas e caminhos de arquivos. Inclui disponibilidade de GPS, frequência, precisão, gravador, estado MBTiles e falhas de abertura.
- Política GPS com testes unitários; testes de diagnóstico e privacidade atualizados.
- Preservados os recursos existentes e o comportamento de Valhalla remoto, sem motor de rotas offline novo.

## Observações

- MBTiles raster: leitura local de mapas importados. GPX já é exportável pelo gravador; roteamento Valhalla, Overpass, clima e Google Maps exigem rede.
- Navegação em segundo plano, consumo real de bateria e renderização exigem testes de aparelho físico. Foreground service disponível no projeto não é garantia isolada de GPS contínuo.
- SDK Flutter/Dart e Android indisponíveis neste ambiente de empacotamento. Confirmar `flutter analyze`, `flutter test` e APK pelo workflow Android CI.
