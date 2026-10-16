# Vigia IA 1.0.261+261 — correção do Android APK 215

## Correção

O workflow Android APK 215 bloqueou `flutter analyze --fatal-infos --fatal-warnings` por um `if` sem chaves no seletor de fonte local principal (`monitor_screen_multicamera.dart:249`). O comando `return` agora está em um bloco `{ }`, sem alterar a condição.

## Preservado

- Câmera frontal selecionada como vídeo principal, não PiP, sem disputar CameraX com a traseira.
- Conversão RGB da câmera local limitada para preservar a prévia e análise somente no receptor.
- Seletor de modelos de IA, modo Automático, diagnósticos de 15/30/60 segundos e exportação.
- Transmissão sem IA, RTSP, ESP32, Minha Câmera e módulos de mapas.

## Validação

Verificador focado e quatro testes preventivos adicionados. Flutter SDK e Android SDK necessários para `flutter analyze`, `flutter test`, APK e testes físicos de troca de câmera.
