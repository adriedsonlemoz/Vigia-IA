# Relatório técnico da refatoração — Vigia IA 1.0.233+233

Data: 15/10/2026. Base de código: ZIP completo 1.0.232+232, disponibilizado pelo usuário.

## Auditoria estrutural

- `lib/screens/map_monitoring_screen.dart` tinha 11.652 linhas, com estado e callbacks de mapa, navegação, pesquisas, telemetria e módulos opcionais. O `build` principal inicia por volta da linha 6.484. A tela já delegava alguns recursos a `lib/screens/map_monitoring_offline_support.dart` e a vários `lib/services/` e `lib/widgets/`.
- A auditoria desta etapa foi estrutural, não uma demonstração de ausência de bugs. Não houve análise de tempo de CPU, vazamentos em runtime ou potência em hardware.
- Widgets passivos sem controlador, persistência, assinaturas de eventos ou dependências de lifecycle foram priorizados. Não foram movidas políticas de GPS, estados de gravação, requisições, caches, controladores de câmera ou rádio.

## Arquivos movidos e impacto

| Responsabilidade | Origem | Destino | Linhas originais movidas |
| --- | --- | --- | ---: |
| HUD de bateria/GPS/hora e indicador de velocidade/rumo | `_MapSystemHud`, `_MapFocusSpeedPill` | `lib/widgets/map_status_indicators.dart` | 62 |
| Espaçamento e botões de zoom horizontal/vertical | `_MapControlGap`, `_MapZoomCluster`, `_MapZoomAction` | `lib/widgets/map_zoom_controls.dart` | 84 |
| **Total** | | | **146** |

O arquivo central ficou com 11.508 linhas, redução líquida de 144; a diferença de duas linhas decorre do espaço entre os blocos extraídos. Os módulos novos têm 67 e 89 linhas, respectivamente, incluindo imports e comentários. As referências foram atualizadas para as classes exportadas, mantendo o botão `_MapZoomAction` privado em sua nova biblioteca.

## Estabilidade e compatibilidade

- Propriedade de callbacks, ordenação de ações, parâmetros, aparência e orientação visual preservadas por transposição do código dos widgets.
- Nenhum novo listener, timer, polling, estado compartilhado, fluxo de rede ou inicialização em segundo plano.
- Nenhuma modificação no armazenamento ou nas permissões do Android. O Gradle segue derivando `versionName` e `versionCode` da configuração Flutter.
- As regras preventivas que checavam zoom no arquivo antigo foram redirecionadas para conferir a declaração no arquivo novo **e** o uso na tela. As regras anteriores não foram desabilitadas.
- Bugs funcionais reproduzidos/corrigidos: nenhum nesta etapa. Nenhuma nova funcionalidade.

## Validação e pendências

- `tool/verify_project.sh`: aprovado; 36 testes Python da infraestrutura passaram.
- `tool/check_map_refactor_233.py`: 18 contratos aprovados.
- `tool/check_import_targets.py`: aprovado para destinos de import/part locais, **não** verifica tipos Dart.
- `tool/check_version_sync.py`: aprovado.
- JSON, XML e YAML locais: parse aprovado; ZIP íntegro.
- Testes Flutter **criados, ainda não executados**: `test/map_status_indicators_test.dart` e `test/map_zoom_controls_test.dart`.
- **Pendente no GitHub Actions**: `flutter analyze --fatal-infos --fatal-warnings`, `flutter test` integral, geração APK e teste real em Android; execução local indisponível por ausência do SDK Flutter/Android.
- **Pendente em aparelho**: callbacks zoom +/− nos dois layouts, HUD com/sensor GPS, câmera opcional, navegação, rádio, POIs, offline e gravação durante troca de tela, além de medição de bateria.

**Próxima etapa recomendada (1.0.234+234, condicionada à validação da 233):** avaliar cartões de resumo visual que não acessem estado de serviços e extrair um agrupamento independente com testes de widget; manter as áreas de routing/GPS e lifecycle intactas nesta fase.
