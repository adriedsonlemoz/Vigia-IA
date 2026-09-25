# Vigia IA 1.0.120+120

## ESP32 modular

- Separa o cadastro do módulo ESP32 da câmera: câmera agora é apenas uma capacidade opcional.
- Migra automaticamente os cadastros ESP32 antigos sem perder endereço, chave, sensores ou calibração.
- Adiciona posição/função do módulo e catálogo extensível de capacidades para futuros mmWave, térmico, ToF, ultrassom, ambiente, GPS, luz e atuadores.
- Mantém compatibilidade com o Monitor/Câmeras publicando uma `CameraEndpoint` somente quando a capacidade de câmera estiver ativa.

## Telemetria preparada

- `BikeSensorService` passa a manter snapshots separados por `moduleId`.
- O timeout de perda de telemetria acompanha o intervalo configurado, evitando falso offline em módulos de 5 segundos.
- Pressão mínima e temperatura máxima configuradas no ESP32 passam a controlar a classificação de saúde e avisos do HUD.
- `/status` já aceita metadados opcionais de protocolo, firmware e capacidades para firmware futuro.

## Validação

- `python3 tool/check_version_sync.py`
- `bash tool/verify_project.sh`
- Integridade do ZIP final
- `flutter analyze`, `flutter test` e build Android precisam ser confirmados pelo workflow quando o SDK estiver disponível.
