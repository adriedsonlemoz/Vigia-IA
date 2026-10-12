# Relatório técnico e de validação — Vigia IA 1.0.231+231

**Data:** 12/10/2026  
**Base:** código-fonte integral 1.0.230+230  
**Nova entrega:** 1.0.231+231, `versionCode` 231  
**Escopo:** mapa offline, proveniência da cobertura e redução de sondagens redundantes de rede. Quarta versão do ciclo 1.0.228–1.0.231, antes dos testes manuais e da refatoração gradual.

## Mudanças verificadas no código

1. **Política de cobertura offline:** `lib/services/offline_map_coverage_policy.dart` distingue ausência de mapa, pacote sem limites geográficos conhecidos, posição fora da região, nível de zoom além da faixa documentada, cobertura regional possível e corredor cujos tiles não podem ser inferidos pelo retângulo. A política **não verifica individualmente todos os tiles** do arquivo, portanto não declara cobertura comprovada.
2. **Avisos no HUD do mapa:** integração em `lib/screens/map_monitoring_screen.dart`, com avisos de área não conhecida, limite geográfico e zoom disponível. O gerenciador em `lib/widgets/offline_map_manager_sheet.dart` informa explicitamente que um download de rota cobre apenas um corredor de tiles e que pacotes antigos podem não ter área conhecida.
3. **Uso conservador da rede:** `MapConnectivityService` altera o intervalo de sondagem de DNS de 15 s no estado conectado para 60 s enquanto desconectado. Ao detectar reconexão, retorna ao intervalo rápido. Os valores permanecem configuráveis no construtor.
4. **Recuperação de rotas:** `map_monitoring_offline_support.dart` deixa de realizar a consulta DNS adicional no fallback a cada 30 s durante falhas de conexão; observa o monitor já existente. A geometria conhecida é preservada. A retomada online e a saída do modo offline manual habilitam uma nova tentativa quando há rota pendente.
5. **Sem mudanças invasivas:** não alteradas as permissões Android, dependências, formatos MBTiles, banco de dados, motor de rotas, câmera/IA, rádio, Bike/ESP32 e gravação de trilha.

## Validações executadas neste ambiente

| Controle | Resultado |
|---|---|
| `python3 tool/check_version_sync.py` | Aprovado: 1.0.231+231 |
| `python3 tool/check_import_targets.py` | Aprovado para existência de destinos locais; não resolve tipos Dart |
| `python3 tool/check_ci_contract.py` | Aprovado |
| `python3 tool/check_offline_autonomy_231.py` | Aprovado: 11 contratos |
| `python3 -m unittest discover -s tool -p 'test_*.py'` | Aprovado: 33 testes Python |
| `bash tool/verify_project.sh` | **Aprovado**, resultado final registrado em `vigia_231_verify_final.log` |
| `test/offline_map_coverage_policy_test.dart` | 6 cenários adicionados, execução Flutter pendente |
| `test/map_connectivity_adaptive_polling_test.dart` | 1 teste adicionado, execução Flutter pendente |
| Flutter Analyzer / Flutter Tests | **Não executados localmente:** SDK Flutter ausente |
| Gradle / Android APK / assinatura | **Não executados localmente:** ferramentas Android indisponíveis |
| Aparelho, sensores reais e consumo de bateria | **Pendente** |

## Limites e riscos conhecidos

- Um MBTiles com dados regionais conhecidos pode conter buracos; `possible` **não significa** tiles comprovados. Um download de corredor jamais garante cobertura de todo o retângulo indicado nos metadados.
- Zoom mais alto que o `maxZoom` do arquivo pode ser renderizado ampliado, mas sem o detalhamento adicional correspondente ao zoom escolhido. O aviso é sobre **detalhe**, não necessariamente tela vazia.
- Download/importação de mapa-base MBTiles não adiciona algoritmo de cálculo ou recálculo de rotas viárias offline. A geometria de rotas já salvas é reutilizável.
- A alteração das sondagens pode retardar em até aproximadamente um minuto a detecção automática de reconexão após estado offline, dependendo do instante do próximo ciclo e do tempo de DNS.
- Nenhuma porcentagem de economia de energia é afirmada. A redução de consultas é uma otimização lógica, não uma medição elétrica. Se outras partes do aplicativo usarem internet, o consumo final pode não seguir proporcionalmente esta redução.
- `flutter analyze` e `flutter test` precisam passar no GitHub Actions antes de considerar a compilação aprovada. A validação Python não comprova compilação Dart.

## Checklist de teste manual no Android (ciclo 228 a 231)

- Confirmar versão 1.0.231+231 e atualização do APK sem perda de favoritos/rotas.
- Abrir região MBTiles; entrar em modo avião e verificar mosaicos, zoom, POIs salvos e atribuição OSM. Testar posição fora da área e pacote legado sem limites.
- Navegar com rota previamente salva; desligar e religar a conexão; verificar que o trajeto conhecido continua disponível e que a navegação se recupera quando possível, sem afirmar recálculo offline.
- Conferir nova interface contextual do HUD, gravação simultânea à navegação, busca de localidades e pontos úteis.
- Reproduzir rádio, minimizar, pausar/retomar, testar timer, favoritos e recentes; verificar sensores sem ESP32 e limites independentes quando hardware estiver disponível.
- Medir consumo com parâmetros controlados, comparando brilho, GPS, conexão e duração do percurso; registrar logs de UI/Android.

**Próximo marco:** validar a compilação no GitHub Actions, executar os testes acumulados no celular e somente depois iniciar a refatoração gradual na versão seguinte. Se o CI ou aparelho revelar regressão, corrigir com nova versão sequencial.
