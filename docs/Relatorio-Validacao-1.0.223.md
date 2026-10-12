# Vigia IA — Relatório de validação da versão 1.0.223+223

**Data:** 12/10/2026  
**Base:** ZIP integral `VigiaIA-v1.0.222+222-source.zip`  
**Objetivo:** bloquear dados vencidos na interface do mapa sem modificar o histórico do percurso e preservar todos os módulos em um único app.

## O que mudou

- `MapTelemetryPolicy.freshPoint` tornou explícita a diferença entre amostra recente (até 20 s) e histórico, inclusive rejeitando timestamps no futuro.
- O HUD usa posição GPS atual apenas quando a amostra está válida; exibe `GPS antigo`, deixa a precisão horizontal e a altitude atuais indisponíveis e indica a idade. Coordenadas históricas podem continuar nos detalhes, identificadas como históricas.
- Rumo GPS e direção extraída da rota dependem de fix recente. Sensor físico de bússola é válido por 3 s; cabeçalho do HUD identifica se a direção vem do sensor, GPS ou geometria da rota.
- Velocidade do ESP32 em simulação é identificada na faixa superior; precisão de velocidade do GPS é exibida apenas com leitura GPS atual. Altitude atual deixa de usar a última amostra do perfil histórico.
- `MapWeatherPolicy.currentValue` separa leituras do ESP32 (90 s) de meteorologia online (atualização até 45 min + observação não superior a 2 h). Clima velho aparece como `Clima antigo`; a previsão vencida não produz avaliação favorável. O resumo falado omite dados online antigos.
- O temporizador do HUD reavalia estados em 10 s e os modais de telemetria recebem os mesmos ticks, mesmo quando o GPS não emite eventos; atualizações de bateria e rádio permanecem em 30 s.
- Adicionados 9 testes Dart (7 de política temporal e 2 widgets) e 3 testes Python de conexão de UI à política de frescor. O teste meteorológico de voz recebeu relógio injetável para execução determinística.
- Mantidos câmeras, IA, rádio, ESP32, rotas, gravação e mapas offline, sem mudança intencional nos contratos públicos ou no armazenamento persistente.

## Evidências de validação

| Verificação | Resultado |
|---|---|
| `tool/check_version_sync.py` | Aprovado `1.0.223+223` |
| `bash tool/verify_project.sh` | Aprovado |
| `python3 -m unittest discover -s tool -p 'test_*.py'` | **13/13 aprovados**, incluindo contratos estáticos |
| `python3 -m compileall -q tool` | Aprovado |
| YAML GitHub Actions | Parsing aprovado |
| JSON/XML | **2 JSON**, **10 XML** sintaticamente válidos |
| Integridade da árvore | Todos os **739 arquivos** originais preservados; **27 modificados** e **2 novos** |
| `flutter analyze` | **Não executado**, Flutter SDK ausente |
| `flutter test` incluindo novos widgets | **Não executado**, Flutter SDK ausente |
| Gradle/compilação Android/APK | **Não executados**, Android SDK ausente |
| Teste manual Android | **Adiado para 1.0.225 conforme preferência do usuário** |

## Riscos e pendências

1. Rodar CI integral em cada versão, mesmo que a instalação e o teste manual só ocorram a cada três entregas. 1.0.223 não é APK compilado/validado.
2. Política GPS de 20 s pode marcar como antiga a posição durante interrupções normais da plataforma; deve ser confirmada em aparelho. A reavaliação do HUD a cada 10 s pode afetar desempenho e autonomia; ainda não há medições.
3. Históricos de rota, mapa e gravação ainda podem usar posição salva para continuidade/recuperação; este release muda apenas a apresentação e o rumo visual. Auditar outros fluxos antes de classificá-los como seguros para uso em tempo real.
4. A fonte física de direção não necessariamente é norte verdadeiro. O sensor é orientação do aparelho; GPS é rumo do movimento e rota é direção geométrica. Conversão de declinação magnética não foi implementada.
5. `pubspec.lock` continua ausente como na base original, o que reduz a reprodutibilidade até ser gerado com o SDK Flutter fixado.
6. O resultado final de build da 1.0.222 e dos workflows anteriores continua não comprovado nesta sessão.

## Lote de teste manual planejado

- **1.0.225**: testar regressões acumuladas da 1.0.223 (GPS/clima/bússola), 1.0.224 (localidades e duplicatas) e 1.0.225 (POIs, cache, 429/504).
- **1.0.228**: próximo lote manual após 1.0.226–1.0.228.
- **1.0.231**: lote seguinte.

## Arquivos-fonte modificados/adicionados

**Modificados:** `ARCHITECTURE.md`, `BACKLOG-ESTABILIZACAO-1.0.222.md`, `CHANGELOG.md`, `README.md`, `VALIDATION.md`, `app_identity.json`, `github-manager.json`, `lib/core/app_metadata.dart`, `lib/screens/app_info_screen_components.dart`, `lib/screens/map_monitoring_screen.dart`, `lib/services/map_cycling_route_service.dart`, `lib/services/map_destination_search_service.dart`, `lib/services/map_telemetry_policy.dart`, `lib/services/map_weather_policy.dart`, `lib/services/map_weather_service.dart`, `lib/services/offline_map_service.dart`, `lib/services/route_explorer_service.dart`, `lib/services/update_news_catalog.dart`, `lib/widgets/map_navigation_3d_view.dart`, `lib/widgets/map_telemetry_panel.dart`, `pubspec.yaml`, `test/app_metadata_test.dart`, `test/map_telemetry_policy_test.dart`, `test/map_weather_policy_test.dart`, `tool/check_map_radio_219.py`, `tool/test_stabilization_contracts.py`, `tool/verify_project.sh`

**Novos:** `RELEASE-1.0.223.md`, `test/map_gps_quality_indicator_test.dart`
