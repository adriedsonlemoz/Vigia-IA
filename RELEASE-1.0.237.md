# Vigia IA 1.0.237+237

Refatoração gradual, etapa 5. Os cartões visuais com métricas e pontos próximos durante a navegação agora ficam no módulo `lib/widgets/map_navigation_metrics.dart`.

A disposição visual, ícones, medidas apresentadas, distância em linha reta, valores indisponíveis (`--`), tipografia e callbacks foram preservados. Nenhuma alteração de estado, serviços GPS, gravação, rádio, câmeras, ESP32, IA, mapas offline ou persistência.

**Verificações:** gate preventivo e verificações de consistência; testes Flutter e compilação APK pendentes do GitHub Actions.
