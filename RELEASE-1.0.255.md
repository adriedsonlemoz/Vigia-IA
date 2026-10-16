# Vigia IA 1.0.255+255: correção do workflow Android APK 209

O workflow Android APK 209 concluiu a verificação preventiva com 90 testes Python, mas falhou em `flutter analyze --fatal-infos --fatal-warnings` antes de gerar o APK.

**Correções:** getter `aiEnabled` do `MonitorController` exposto, seis declarações excedentes de `dividerColor` removidas em widgets sem `embedded`, interpolações de resolução simplificadas. Mantido o único `dividerColor` válido em `_DeviceStatusStrip`.

**Preservado:** botão IA liga/desliga sobre o vídeo, resolução/FPS de análise, Home de quatro modos, MCRP em Câmeras, RTSP, ESP32 e mapa/GPS sob demanda.

**Validação:** gate preventivo e testes de regressão adicionados. `flutter analyze`, `flutter test` e APK ainda devem ser confirmados pelo CI.
