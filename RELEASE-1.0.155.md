# Vigia IA 1.0.155+155

Correção prioritária da tela preta ao iniciar a navegação MapLibre 3D.

## Corrigido

- O `FlutterMap` 2D não é mais removido assim que o modo 3D é solicitado.
- O MapLibre é preparado sobre o mapa 2D e só fica visível depois que mapa nativo, estilo, rota, câmera e primeiro ciclo de render estiverem prontos.
- A transição 2D → 3D passa a usar opacidade animada, evitando troca brusca de renderer.
- Um timeout de 9 segundos impede que o usuário fique preso esperando uma view nativa que não concluiu a inicialização.
- Falhas de criação, estilo, desenho/atualização da rota, posição e câmera acionam fallback automático para 2D.
- O estilo MapLibre ganhou uma camada de fundo clara para evitar quadro preto durante carregamento tardio dos tiles raster.
- Catches silenciosos foram removidos do renderer 3D; as falhas passam a ser registradas no diagnóstico e na telemetria interna, incluindo o fallback 3D → 2D.
- A composição Android do MapLibre fica explicitamente configurada para Texture Layer Hybrid Composition com fallback Hybrid Composition.
- Mudanças de conectividade ou modo offline invalidam a prontidão anterior do renderer, impedindo reaproveitamento indevido de uma view já desmontada.

## Preservado

- Perfis Bicicleta, Moto, Carro e A pé continuam afetando o cálculo real da rota.
- Rota, recálculo, GPS, voz, POIs, gravação, câmera e botão 3D/2D permanecem funcionais.
- Offline continua usando automaticamente `FlutterMap`/MBTiles sem depender do MapLibre.
- A base 3D desta etapa continua raster; evolução para mapa vetorial e prédios 3D permanece para etapa posterior.

## Metadados e validação

- Versão sincronizada em `1.0.155+155`.
- `github-manager.json` adicionado e sincronizado com `pubspec.yaml`, `app_identity.json` e `AppMetadata`.
- `tool/check_version_sync.py` passa a validar também o manifesto do GitHub Manager.
- `tool/verify_project.sh` inclui verificações preventivas da transição segura, timeout, fallback e instrumentação MapLibre.
- O ZIP desta entrega contém somente código-fonte e documentação; nenhum APK/AAB é incluído.

## Resultado da validação local

- `python3 tool/check_version_sync.py`: **aprovado**.
- `bash tool/verify_project.sh`: **aprovado**.
- `app_identity.json` e `github-manager.json`: JSON válido e versões sincronizadas.
- Renderer 3D: nenhum `catch (_) {}` silencioso remanescente.
- Fonte: nenhum APK/AAB presente.
- Flutter/Dart não estão instalados neste ambiente; `flutter analyze`, `flutter test` e o build release ficam para reconfirmação no workflow Android.
