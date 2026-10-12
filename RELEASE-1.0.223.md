# Vigia IA 1.0.223+223

## Atualidade de GPS, direção, altitude e clima

- O HUD distingue GPS recente de posição antiga e omite precisão do GPS vencida (20 s), mantendo coordenadas históricas apenas nos detalhes.
- Rumo de GPS/rota depende de localização recente; bússola usa sensor físico somente com timestamp válido.
- O valor de altitude atual e o perfil histórico deixam de ser confundidos; precisão de velocidade GPS só aparece com leitura GPS vigente.
- Dados meteorológicos antigos de ESP32/online deixam de ser anunciados como condição atual e o resumo falado descarta leituras vencidas.
- O temporizador do HUD reavalia o frescor a cada 10 s; bateria e rádio continuam no ciclo de 30 s.
- Foram ampliados os testes determinísticos de fronteiras temporais, incluindo GPS com 2 min e alta precisão.

**Limitação:** esta é uma entrega de código-fonte. Sem Flutter/Dart/Android SDK local; `flutter analyze`, `flutter test`, geração do APK e teste no aparelho seguem não comprovados. Teste manual consolidado na 1.0.225.
