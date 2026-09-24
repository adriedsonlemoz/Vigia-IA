# Vigia IA 1.0.118+118

Entrega focada em qualidade de transmissão e áudio configurável.

## Principais mudanças

- Bike Economia: 7 FPS, até 960 px, JPEG 76.
- Bike Economia extrema: 5 FPS, até 800 px, JPEG 72.
- Controle individual das 78 falas em **Ajustes > Áudios e voz**.
- Ações rápidas para ativar ou silenciar todas as falas.
- TTS dinâmico e fallback TTS separados; fallback desligado por padrão.
- 64 falas Bike/ESP32 liberadas no catálogo, sem rótulo “Futuro”.
- Emulador ESP32 reproduz os áudios integrados correspondentes aos cenários de teste.
- Aproximação de veículo prioriza o áudio integrado de veículo para reduzir TTS.

## Validação local

- `python3 tool/verify_audio_resource_catalog.py`
- `python3 tool/check_version_sync.py`
- `bash tool/verify_project.sh`
- Integridade do ZIP final com `unzip -t`.

`flutter analyze`, `flutter test` e o build Android precisam ser confirmados pelo workflow porque este ambiente não possui Flutter/Android SDK.
