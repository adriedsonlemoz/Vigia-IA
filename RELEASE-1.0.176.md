# Vigia IA 1.0.176+176

## Aprendizado de ritmo da Bike

- O Vigia IA passa a manter um histórico local de percursos Bike válidos concluídos.
- Apenas amostras com distância, duração, movimento e velocidade compatíveis com bicicleta entram no aprendizado; trajetos curtos ou suspeitos são ignorados.
- Após histórico suficiente, o planejamento mostra a média aprendida e permite usá-la no ETA e no plano por dias.
- A média manual continua preservada como alternativa e pode ser retomada a qualquer momento.
- O histórico Bike pode ser apagado pela própria tela de planejamento.
- O arquivo local limita o histórico às 20 amostras mais recentes e usa média robusta para reduzir o efeito de outliers.

## Compatibilidade

- Pesquisa online/offline, Locais próximos, Valhalla, mapa 2D/3D, clima, ESP32, câmeras, GPX e fallback existentes permanecem preservados.
- APK/AAB não faz parte do ZIP fonte.
