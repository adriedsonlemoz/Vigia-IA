# Relatório técnico — Vigia IA 1.0.235+235

Data: 2026-10-15. Base de referência: `VigiaIA-v1.0.234-234-source.zip`, preservada. Nenhum APK foi compilado neste ambiente.

## 1. Auditoria e escopo

A tela `lib/screens/map_monitoring_screen.dart` continha **11.227 linhas** na base 1.0.234. Mantém estado GPS, conectividade, câmeras, rádio, Bike, navegação, busca, POIs, planejamento de rotas e composição visual. Após auditoria de código, `AGENTS.md`, README, CHANGELOG, ARCHITECTURE, VALIDATION e verificadores, a etapa 3 escolheu exclusivamente o cartão de prévia visual de rotas, `StatelessWidget` sem ciclo de vida, subscrições ou acesso à rede.

As etapas 1 e 2 já haviam isolado indicadores/zoom e faixa de telemetria. Para não mexer nos controladores de GPS, rota ou gravação, o cartão agora recebe por construtor o destino, a lista de alternativas, seleção, plano, ritmo configurado e callbacks. O fluxo de dados anterior foi mantido.

## 2. Extração concluída

| Item | Linhas | Arquivo |
| --- | ---: | --- |
| `_RoutePreviewCard` -> `MapRoutePreviewCard` | 160 linhas originais transpostas | `lib/widgets/map_route_preview_card.dart` |
| Testes de widget novos | 6 casos | `test/map_route_preview_card_test.dart` |
| Contratos preventivos novos | 14 condições | `tool/check_map_refactor_235.py` |

**Arquivo principal:** 11.227 -> **11.066 linhas**: redução líquida de **161**, sendo 160 linhas efetivamente transpostas e 1 linha de separação removida. O novo arquivo tem 171 linhas, incluindo cabeçalho/imports/comentário. A transposição foi conferida por SHA-256 do corpo original com a única renomeação necessária para torná-lo público entre bibliotecas (`fecf1504102b648af43af5712f4aeb5445907e4fc18da010045f9fd89c9cb9c2`).

**Conteúdo preservado:** resumo com distância e duração, rótulo da fonte, estado carregando, recolher/expandir, alternativas, comparação da rota selecionada, ritmo de bicicleta, planejamento por dias, mostrar trajeto, salvar offline, iniciar navegação e fechar. Nenhuma mudança intencional de estilo, mensagens, dimensões ou comportamento.

## 3. Integração e compatibilidade

- `map_monitoring_screen.dart` importa `MapRoutePreviewCard` e fornece os mesmos 15 argumentos; callback e estado continuam na tela. O serviço `MapRoutePreviewMetrics` foi apenas importado pelo novo componente, sem mudança de cálculo.
- O `part 'map_monitoring_offline_support.dart'` foi preservado. Não houve novas instâncias de controladores, serviços, timers, listeners, tarefas de rede nem consumidores de bateria em segundo plano.
- Nenhum schema de configuração, pacote offline, favorito, trajeto, credencial, permissão ou valor de preferências foi alterado. Compatibilidade 1.0.232–234 mantida por ausência de migração.
- Versão pública `1.0.235+235`: `pubspec.yaml`, `AppMetadata`, metadados JSON, Sobre/Mudanças e Novidades atualizados. Android `versionCode=235`/`versionName=1.0.235` herdados de Flutter por `android/app/build.gradle.kts`.

## 4. Bugs e testes

**Bugs funcionais reproduzidos/corrigidos: nenhum.** Três verificadores legados (`check_map_buildfix_221.py`, `check_map_ui_220.py`, `check_route_preview_229.py`) usavam a localização anterior do cartão; ajustados para verificar **os mesmos contratos** dentro do novo arquivo e seus callbacks na tela. Nenhuma verificação foi desabilitada. Evitou-se uma correção especulativa dos índices de alternativa por não haver reprodução de falha na base.

- `tool/verify_project.sh`: **aprovado**, incluindo **36 testes Python** e checagens antigas.
- `tool/check_map_refactor_233.py`: **18/18 contratos aprovados**.
- `tool/check_map_refactor_234.py`: **16/16 contratos aprovados**.
- `tool/check_map_refactor_235.py`: **14/14 contratos aprovados**, incluindo corpo transposto, import, chamada única, callbacks, limites declarados, sem lifecycle ou dependência circular.
- `check_route_preview_229.py`: **11 contratos aprovados** após atualizar localização dos textos.
- Novos **6 testes Flutter** escritos, **não executados**: bicicleta, prévia recolhida, escolha entre alternativas, ações por callback, carro e carregamento sem resultados.
- JSON **2**, XML **10** e YAML **3** inspecionados sintaticamente: **válidos**.
- Validação de ZIP e CRC: documentada após empacotamento.

**Pendências obrigatórias:** `flutter analyze --fatal-infos --fatal-warnings`, `flutter test`, `flutter build apk`/Gradle, funcionamento e aparência no Android. Flutter SDK/Android SDK não foram encontrados neste ambiente; o gate preventivo estático não comprova compilação. Ainda não foi verificada aprovação de CI das versões 1.0.233 e 1.0.234. Teste físico requer abrir a prévia e comparar com 1.0.234 em bicicleta/carro, alternativas, plano, conexão offline, recolher/expandir, salvar/iniciar, tela pequena e fonte ampliada.

## 5. Próxima etapa sugerida

Após obter CI e validação física da 1.0.235, avaliar a extração **isolada** do botão de alternativas de rota ou métricas visuais da faixa de navegação. Não mover estado, serviços, GPS, assinaturas de stream, gravação ou armazenamento sem testes de integração e ciclo de vida. Não afirmar economia de bateria sem medição antes/depois.
