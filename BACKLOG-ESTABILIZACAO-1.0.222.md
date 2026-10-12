# Backlog Vigia IA após 1.0.231

| Prioridade | Versão prevista | Ação | Aceitação | Pendência |
|---|---|---|---|---|
| P0 | 1.0.222 | Validar CI real | Flutter analyze/test/Gradle/APK assinados aprovados no mesmo commit | Sem execução local; confirmar workflow no GitHub |
| P0 | 1.0.223 | Atualidade GPS e velocidade | Fix de 2 min nunca aparece como atual; idade identificada no HUD | Política e HUD implementados; Flutter/Android pendentes |
| P0 | 1.0.223 | Bússola, altitude, clima | Fonte/idade diferenciadas; dado antigo não vira atual | Políticas aplicadas; ESP32 simulado, teste widget e sensores reais pendentes |
| P0 | 1.0.224 | Busca localidades | Títulos canônicos, sem duplicação indevida, contexto local e grupos distantes | Implementado em código; testes Flutter/Android pendentes; API pública exige escala moderada |
| P0 | 1.0.226 | POIs | Fontes e idade; serviços não verificados indicados, HTTP 429/504 mantém cache | Proveniência e backoff implementados; injeção HTTP e teste físico pendentes |
| P1 | 1.0.228+ | HUD e diálogos responsivos | 320/360/412 dp com texto 1.0/1.5, teclado e barra de sistema | Widget/golden + Android |
| P1 | 1.0.228+ | Prévia vs navegação | Prévia não ativa voz/gravação; rota offline consultável sem falso recálculo | Widget/integração + modo avião |
| P1 | 1.0.228 | Bike/rádio/ESP32 | Sem limite universal PSI, simulação explícita; rádio preserva recursos | Sensores + áudio no Android |
| P1 | 1.0.229 | Offline e autonomia | Tiles, rota, POIs e instruções testados separadamente; consumo medido | Viagem em modo avião; medições reais |
| P2 | 1.0.230+ | Modularização gradual | Comportamento estável, cobertura e métricas comparáveis | Extrações pequenas de map_monitoring_screen.dart |

Testes manuais por lotes: após APK validado no CI, manter ciclos acumulados sem obrigar instalação a cada versão. O CI precisa executar analyze/test/build em cada versão.

Não afirmar sucesso do APK 1.0.221/#185 nem da 1.0.222 sem artefato/log. Prioridades mudam somente com evidência.

## Ajuste após Android APK #187

- **1.0.226 (feito no código, CI pendente):** corrigir 3 lints do analyzer e reforçar regressão preventiva; preservar POIs e geocodificação.
- **1.0.228+ (próximo funcional):** HUD e menus responsivos, sem novos fluxos de GPS desnecessários. Adia a reorganização visual originalmente proposta para 1.0.226.
- **Teste no aparelho:** aguardar APK com `flutter analyze`, testes e build aprovados. O workflow #187 analisou 1.0.224+224, apesar de 1.0.225 já ter sido entregue como ZIP.
- **1.0.228+:** rever planejamento de rota, rádio, telemetria Bike e offline conforme prioridades e risco observado; replanejar após validação real.

## Ajuste após Android APK #188

- **1.0.227:** buildfix isolado do `RenderFlex` da ficha de POI. CI #188 (1.0.226) aprovou análise estática e 429 testes; 1 teste widget falhou, impedindo build Android.
- **1.0.228+:** retomar HUD adaptativo e fluxo de prévia/navegação somente com CI de 1.0.227 aprovado, preservando regressões de 320/360/412 dp e texto ampliado.
- **Ciclo físico de testes:** instalar apenas APK produzido por CI completo (análise + testes + assinatura), mantendo frequência manual agrupada por versões.

## Ciclo acordado 1.0.228 a 1.0.231 (teste manual somente no final)

- **1.0.228:** HUD contextual inicial e exposição progressiva de instrumentos/atalhos. Implementado no código; widgets e APK pendentes do CI. Passos restantes: golden/inspeção visual, teclado e paisagem.
- **1.0.229:** fluxo de prévia, rotas e planejamento de paradas, sem início automático de gravação/voz; manter geometrias offline.
- **1.0.230:** rádio, clima, Bike, sensores e ESP32, incluindo diferenciação de simulação e limites configuráveis.
- **1.0.231:** camadas offline e autonomia; teste manual acumulado do ciclo antes de iniciar 1.0.232+ (refatoração gradual).
- Gates de CI (analyze/test/APK) continuam necessários a cada versão, apesar do teste de instalação ser agrupado.

## Situação após 1.0.229

- **Feito em código (CI pendente):** métricas isoladas para alternativas, tempo de bicicleta com preferência persistida, ritmo editável na prévia, maior precisão geométrica das paradas e aviso de distância reta sem acesso viário confirmado.
- **Pendente até 1.0.231:** testes Dart no CI, layout real 320/360/412 dp, análise de rotas alternativas longas, percursos no modo avião e validação da geometria salva após reinício do processo.
- **1.0.230:** revisão delimitada de Bike, rádio e sensores, sem exigir hardware ESP32 para mapas.
- **1.0.231:** prontidão offline e energia, teste manual conjunto do ciclo de quatro versões.

## Situação após 1.0.230

- **Feito em código (CI pendente):** limites de alerta de pneus por módulo, origem preservada na consolidação de sensores, ausência de leitura distinguida de zero e consistência do polling de rádio.
- **Risco restante:** validação com hardware real, unidades de pressão e calibração, testes Dart/widget e comportamento de streaming sob troca rápida de estações. O limite inicial 30 PSI é somente configurável.
- **1.0.231:** capacidade offline e economia de bateria; teste Android acumulado de 228 a 231 antes de refatoração gradual 232+.

## Situação após 1.0.231

- **Quarto marco implementado em código:** avisos MBTiles por limite/zoom/origem incerta, cadência de rede adaptada a offline e ausência de sondagem duplicada da recuperação de rotas. Não há recálculo offline por estradas nem confirmação de todos os tiles de um corredor.
- **Próxima ação obrigatória:** compilar e testar 1.0.231 no GitHub Actions e testar no aparelho as versões 1.0.228–1.0.231, inclusive modo avião e bateria. Corrigir regressões com incrementos sequenciais se necessário.
- **1.0.232+:** refatoração gradual da tela do mapa após validação no celular, protegendo módulos opcionais e priorizando cicloviagem.
