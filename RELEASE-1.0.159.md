# Vigia IA 1.0.159+159

Etapa 4 da evolução do mapa: controle rápido e independente de áudio sobre o mapa.

## Implementado

- Botão circular de áudio integrado ao dock lateral do mapa, acessível em 2D e durante a navegação MapLibre 3D.
- Popup compacto com controles independentes para `Navegação`, `IA / Detecções` e `Pontos próximos`.
- Ação `Silenciar tudo` para desligar os três canais, interromper a voz de mapa em reprodução e atalho discreto para a tela completa `Áudios e voz`.
- Preferência de voz da navegação persistida no `MapViewSettingsService`; Pontos próximos preserva sua preferência persistente do Route Explorer.
- Navegação e Pontos próximos deixam de depender da chave global de voz usada pelo monitoramento da IA.

## Preservado

- Áudios personalizados, TTS, fallback, preferências individuais dos slots, `MapVoiceService`, `AlertVoiceService`, sistema de alertas e configurações gerais de áudio.
- Rota, recálculo, GPS, POIs, perfis de transporte, MapLibre 3D, fallback 2D, mapas offline, câmeras e gravação.
- Nenhuma parte da Etapa 5 (evolução vetorial/3D real) foi antecipada.

## Validação

- `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh` devem validar versão, persistência e separação dos canais.
- Flutter/Dart não estão instalados neste ambiente; `flutter analyze`, `flutter test` e build Android release precisam ser reconfirmados pelo workflow.
- O ZIP de código-fonte não deve conter APK/AAB.
