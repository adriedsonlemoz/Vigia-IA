# Backlog Vigia IA após 1.0.224

| Prioridade | Versão prevista | Ação | Aceitação | Pendência |
|---|---|---|---|---|
| P0 | 1.0.222 | Validar CI real | Flutter analyze/test/Gradle/APK assinados aprovados no mesmo commit | Sem execução local; confirmar workflow no GitHub |
| P0 | 1.0.223 | Atualidade GPS e velocidade | Fix de 2 min nunca aparece como atual; idade identificada no HUD | Política e HUD implementados; Flutter/Android pendentes |
| P0 | 1.0.223 | Bússola, altitude, clima | Fonte/idade diferenciadas; dado antigo não vira atual | Políticas aplicadas; ESP32 simulado, teste widget e sensores reais pendentes |
| P0 | 1.0.224 | Busca localidades | Títulos canônicos, sem duplicação indevida, contexto local e grupos distantes | Implementado em código; testes Flutter/Android pendentes; API pública exige escala moderada |
| P0 | 1.0.225 | POIs | Fontes e idade; serviços não verificados indicados, HTTP 429/504 mantém cache | Testes HTTP injetáveis e UI |
| P1 | 1.0.226 | HUD e diálogos responsivos | 320/360/412 dp com texto 1.0/1.5, teclado e barra de sistema | Widget/golden + Android |
| P1 | 1.0.227 | Prévia vs navegação | Prévia não ativa voz/gravação; rota offline consultável sem falso recálculo | Widget/integração + modo avião |
| P1 | 1.0.228 | Bike/rádio/ESP32 | Sem limite universal PSI, simulação explícita; rádio preserva recursos | Sensores + áudio no Android |
| P1 | 1.0.229 | Offline e autonomia | Tiles, rota, POIs e instruções testados separadamente; consumo medido | Viagem em modo avião; medições reais |
| P2 | 1.0.230+ | Modularização gradual | Comportamento estável, cobertura e métricas comparáveis | Extrações pequenas de map_monitoring_screen.dart |

Testes manuais por lotes: 1.0.225, 1.0.228, 1.0.231. O CI precisa executar analyze/test/build em cada versão.

Não afirmar sucesso do APK 1.0.221/#185 nem da 1.0.222 sem artefato/log. Prioridades mudam somente com evidência.
