# Vigia IA 1.0.158+158

Etapa 3 da evolução do mapa: reformulação dos cards superiores de telemetria sem aumentar o HUD.

## Implementado

- Velocidade, Altitude, Bússola e GPS continuam em quatro cards quadrados uniformes.
- O valor principal ganhou tipografia maior e prioridade visual.
- Ícone e título foram compactados no cabeçalho de cada card.
- Unidades `km/h` e `m` aparecem menores que o valor.
- Altitude e precisão GPS sem leitura válida mostram `--`, sem estimativa ou dado inventado.
- A bússola mantém o toque para alternar a orientação do mapa e o estado ativo continua destacado.

## Preservado

- A altura da faixa de telemetria permanece 64 px no HUD compacto e 72 px no normal.
- Rota, recálculo, GPS, voz, POIs, gravação, mapas offline, MapLibre 3D, fallback 2D e perfis Bicicleta/Moto/Carro/A pé permanecem funcionais.
- Nenhuma parte da Etapa 4 (controle rápido de áudio) foi antecipada.

## Validação

- `tool/verify_project.sh` valida a nova hierarquia visual e garante que a altura externa do HUD não foi aumentada: **aprovado localmente**.
- `python3 tool/check_version_sync.py` valida a sincronização de versão e build: **aprovado localmente**.
- JSONs de identidade e sintaxe shell foram validados; apenas o workflow principal `android-apk.yml` permanece e não há APK/AAB no fonte.
- Flutter/Dart não estão instalados neste ambiente local; `flutter analyze`, `flutter test` e build Android release precisam ser reconfirmados no workflow.
- O ZIP de código-fonte não deve conter APK/AAB.
