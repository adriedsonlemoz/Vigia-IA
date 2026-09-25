# Vigia IA 1.0.130+130

## Foco

Câmeras diretamente no mapa e redução de consumo para uso prolongado em bike/viagem.

## Entregue

- seleção de fonte por PiP: local/traseira, frontal, RTSP, celular remoto, ESP32 e câmera já aberta pelo Monitor;
- até duas câmeras sobre o mapa com trocar fonte, minimizar, ocultar, tamanho e encaixe nos cantos;
- persistência de posição/tamanho/estado visual sem duplicar credenciais;
- Home e Monitor convergem para a mesma experiência de mapa;
- câmeras abertas só pelo mapa não executam pipeline de IA e são suspensas quando não visíveis ou em background;
- GPS com contagem de consumidores e liberação quando ocioso;
- cronômetro isolado da árvore do mapa, sem notificação global por segundo;
- recálculo de POIs apenas em coordenada nova e redução de pontos apenas na renderização de rotas longas;

## Validação

Executar `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh`. Quando Flutter/Android SDK estiver disponível, executar também `flutter analyze`, `flutter test` e o build Android.
