# Vigia IA 1.0.148+148

## Desempenho e estabilidade

- GPS do mapa ajustado para `distanceFilter` de 8 m, reduzindo amostras redundantes sem perder a precisão necessária para navegação de bicicleta.
- Distâncias de POIs continuam sendo atualizadas para alertas em tempo real, mas a interface da lista só é notificada a cada 20 m ou 4 s, reduzindo rebuilds.
- Buscas automáticas de POIs ganharam cooldown de 90 s entre tentativas, evitando rajadas de consultas após falhas de rede ou mudanças sucessivas de direção.
- A fonte de câmera remota deixa de publicar repetidamente o mesmo estado de streaming, reduzindo notificações e reconstruções desnecessárias dos PiPs.
- Nenhuma regra de detecção, TTC, recálculo de rota, alertas ou navegação por voz foi relaxada.

## Compatibilidade

- Identidade preservada: `Vigia IA`, `vigiaia`, `com.vigiaia.app` e `vigiaia://pair`.
- `.github/workflows` preservado.
- APK continua fora do ZIP de código-fonte.
