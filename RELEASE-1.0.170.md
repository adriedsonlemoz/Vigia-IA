# Vigia IA 1.0.170+170 — reempacotamento da etapa final do mapa 3D

Esta versão corrige o erro de análise estática encontrado no build 132 sem iniciar funcionalidades futuras nem alterar o comportamento planejado do mapa.

## Correção aplicada

- `MapWeatherService` usa `Esp32ConnectionState` para filtrar telemetria ESP32 válida, mas a 1.0.169 não importava diretamente o arquivo que declara o enum.
- Foi adicionada a dependência explícita `models/esp32_telemetry.dart`, eliminando os dois `undefined_identifier` reportados por `flutter analyze`.
- A política de clima continua igual: estados `online` e `degraded` podem fornecer dados reais; estados inválidos/desatualizados são ignorados.

## Escopo preservado

A câmera 3D adaptativa, Norte/Direção/Rota, rota com casing temático, prédios best-effort, terrain desativado sem API/fonte DEM segura, inicialização MapLibre por estágios, fallback de style/2D, HUD, clima, offline, POIs, câmeras e Valhalla permanecem inalterados funcionalmente.

## Novidades

A popup continua limitada às mudanças visíveis da entrega do mapa 3D. O detalhe desta correção fica apenas em `Sobre > Mudanças`, CHANGELOG/RELEASE e diagnóstico de build.

## Validação

Executar `python3 tool/check_version_sync.py`, `bash -n tool/verify_project.sh` e `bash tool/verify_project.sh`; validar JSON/workflow/artefatos e repetir sobre uma extração limpa do ZIP. Flutter/Dart devem ser executados somente em ambiente com os SDKs instalados.
