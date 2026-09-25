# Vigia IA 1.0.121+121

## Objetivo

Conectar a fundação modular criada na 1.0.120 à telemetria real e contínua dos módulos ESP32, mantendo compatibilidade com firmware legado e preparando múltiplos módulos simultâneos.

## Entregue

- Serviço global de telemetria ESP32 com polling por módulo.
- Descoberta de endpoints versionados e legados.
- Reconexão automática com backoff e estado degradado antes do offline.
- Parsing de payload estruturado, `bikeSensors` legado e campos diretos antigos.
- Runtime por módulo: latência, última leitura, próxima tentativa, falhas, endpoint, RSSI, bateria, firmware, protocolo e capacidades reportadas.
- Agregação de sensores de múltiplos ESP32 no HUD Bike.
- Disponibilidade individual de velocidade, pneu dianteiro, pneu traseiro, bateria e temperatura para evitar falsos alertas.
- Diagnóstico/exportação com seção detalhada dos módulos ESP32.
- Tela ESP32 atualizada com telemetria e estado ao vivo.
- Testes de regressão para parsing e sensores parciais.

## Compatibilidade

Módulos antigos continuam funcionando por `/status` e payloads diretos. Firmware novo pode implementar `/api/v1/telemetry` sem exigir mudança adicional no cadastro do app.

## Validação local

Executar `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh`. O ambiente de empacotamento atual não possui Flutter/Android SDK, portanto `flutter analyze`, `flutter test` e o APK precisam ser reconfirmados pelo workflow Android.
