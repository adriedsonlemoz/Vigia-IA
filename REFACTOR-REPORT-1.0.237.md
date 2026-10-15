# Relatório técnico — Vigia IA 1.0.237+237

Data: 2026-10-15. Base funcional de referência: 1.0.232+232; base imediata e efetivamente usada: `VigiaIA-v1.0.236-236-source.zip` (806 entradas, CRC válido).

## 1. Auditoria e responsabilidade extraída

- Antes de alterar: `tool/verify_project.sh` aprovado na 1.0.236+236 (36 testes Python e contratos anteriores), e `AGENTS.md`, README, ARCHITECTURE, VALIDATION e testes existentes revisados.
- Duas classes internas visuais do painel de navegação, `_NavigationMetricCell` e `_NavigationPoiChip`, transpostas em um único módulo coeso: `lib/widgets/map_navigation_metrics.dart` com `MapNavigationMetricCell` e `MapNavigationPoiChip` (`StatelessWidget`).
- Responsabilidades: apresentar valor, unidade/rótulo, ícone, cor e tipografia de métrica; apresentar categoria e distância de ponto próximo. Não calculam distâncias ou percentuais, não consultam rede ou sensores, não iniciam controlador e não persistem estado.
- Quatro chamadas de cada widget permanecem em `_NavigationBanner` com a mesma ordem, layout e parâmetros. Distâncias já formatadas e `--` para indisponível continuam sendo preparados na tela principal.
- **Linhas do arquivo principal:** **10.957 antes → 10.843 depois**; **115 linhas originais extraídas** e **114 linhas de redução líquida** por conta do import adicional; novo módulo com 119 linhas incluindo imports e documentação.
- A comparação exata da seção original com o módulo novo, após substituir somente os dois nomes de classe/construtor, confirmou igualdade. A tela principal também foi comparada integralmente com uma transformação esperada aplicada à base anterior: sem diferenças adicionais.

## 2. Arquivos e testes novos

- `lib/widgets/map_navigation_metrics.dart`: dois componentes de apresentação sem estado compartilhado.
- `test/map_navigation_metrics_test.dart`: **7 testes de widget escritos** para valor/ícone/rótulo, estilo compacto/expandido, truncamento de valores, placeholder e visualização de distância. **Não executados** pela ausência de Flutter SDK.
- `tool/check_map_refactor_237.py`: **15 contratos preventivos**, inclusive hash SHA-256 dos widgets transpostos, chamadas, inputs, placeholder, integração e ausência de efeitos colaterais. Integrado no `tool/verify_project.sh` preservando verificadores anteriores.
- `RELEASE-1.0.237.md` e este relatório; README, CHANGELOG, ARCHITECTURE, VALIDATION, metadados, tela Sobre/Mudanças (ambos os painéis), catálogo Novidades e User-Agents atualizados.

## 3. Erros, segurança e compatibilidade

- Nenhum bug funcional do aplicativo foi reproduzido no escopo, portanto nenhuma correção funcional foi feita.
- Corrigidas referências de versão/build no gate preventivo, e as checagens legadas de 1.0.199 passaram a procurar as duas classes no módulo novo, sem remover cobertura. Uma primeira execução do gate durante o versionamento identificou expectativa antiga de build `236`; após correção, o gate passou integralmente.
- Nenhuma alteração deliberada em GPS, rota, persistência, MBTiles, câmera, IA, áudio, Bike, ESP32, esquema, permissões ou timers. Sem novos listeners, streams, serviços, tarefas periódicas, objetos de estado ou migração de dados.

## 4. Validação executada

- Fonte original 1.0.236: gate preventivo **aprovado**.
- Fonte 1.0.237: `tool/verify_project.sh` **aprovado**, com **36 testes Python** e **15 contratos novos**, além dos contratos anteriores; `tool/check_version_sync.py` aprovado.
- Paridade exata entre código original e movido, descontados nomes públicos; paridade da tela principal com alteração projetada **aprovadas**.
- JSON: **2** válidos; XML: **10** válidos; YAML: **3** válidos; Python AST: **28** arquivos válidos.
- Integridade ZIP e número de arquivos: conferir evidência de empacotamento na entrega final.
- **Pendências:** `flutter analyze --fatal-infos --fatal-warnings`, `flutter test`, teste visual de 320/360/412 dp e fonte ampliada, build Gradle/Flutter/APK no GitHub Actions e teste em dispositivo. SDK Flutter, Dart e Android indisponíveis localmente. Não alegar compilação aprovada.

## 5. Próxima etapa proposta

Depois de aprovar CI e avaliar a UI em aparelho, selecionar um widget visual do painel de navegação ou um agrupamento de ações secundárias de baixo risco. Evitar mover estado da navegação, serviços GPS, gravação ou tarefas de segundo plano sem teste de integração e medição; a redução de linhas por si só não comprova ganho de bateria.
