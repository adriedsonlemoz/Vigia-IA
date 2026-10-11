# Relatório técnico: Vigia IA 1.0.210+210

**Base auditada:** arquivo-fonte da versão 1.0.209+209, recebido em 11/10/2026.

**Objetivo:** primeira otimização conservadora do Vigia Maps, mantendo aplicação monolítica modular e compatibilidade com câmera, IA, Bike e ESP32.

## Diagnóstico do código real

| Componente | Evidência encontrada | Problema / limite |
|---|---|---|
| GPS | `MapRouteService` centraliza o único `LocationTrackingService.positionStream()` | `ensureLocation` executava `currentPosition` repetidamente mesmo com stream ativo, criando trabalho redundante na camada de localização |
| Ciclo de vida | `MapRouteService` oferece consumidores, navegação/gravação e pausa/resume; `MapMonitoringScreen` tem listeners e timers | Antes da alteração, a solicitação de GPS não distinguia explicitamente demanda isolada de consumidores; retorno tardio de `await` podia abrir stream ocioso |
| Renderização | `route` e `routeSegments` produziam cópias imutáveis completas a cada acesso; `_routeSegmentsForDisplay()` recriava `LatLng` | Custo proporcional aos pontos do percurso em múltiplos rebuilds, inclusive quando a geometria não mudou |
| ESP32 + clima | `MapWeatherService.initialize()` chamava `Esp32TelemetryService.initialize()` | Abrir mapa/clima podia iniciar sondagens ESP32 de módulos cadastrados sem o usuário abrir Bike/ESP32 |
| Mapas offline | `OfflineMapService` persiste MBTiles raster no aparelho; tela carrega via `MbTilesTileProvider.fromPath` | Mapas locais estão disponíveis, mas problemas ao abrir pacote só apareciam em logs de debug e não no diagnóstico exportável |
| Roteamento | `MapCyclingRouteService.fetchAlternatives()` acessa `https://valhalla1.openstreetmap.de/route` | **Rotas Valhalla não funcionam totalmente offline**. Fallback visual não substitui instruções/roteamento viário |
| Diagnóstico | `DiagnosticReportService` tinha estado do sistema, câmera, áudio, RTSP/Android e ESP32 | Faltavam contadores GPS, status de gravação e MBTiles; memória, bateria e temperatura já existiam |

## Alterações efetivas

1. `MapLocationSubscriptionPolicy`: nova política pura e testável: manter stream com consumidor em primeiro plano, gravação ou navegação. Consultas sem consumidor usam fix pontual, sem assinatura ociosa. Precisão alta, filtro de 8 m e filtro GPS existentes mantidos.
2. `MapRouteService`: elimina `getCurrentPosition` redundante enquanto o stream serve o mapa, evita abrir stream após liberação da última demanda, mantém stream ao iniciar gravação/navegação, contabiliza leituras recentes/erros/assinaturas e libera estado `loading` mesmo diante de exceção. Mantida a persistência já existente.
3. `MapRouteService`/`MapMonitoringScreen`: snapshots imutáveis de rota/segmentos e geometria visual reusados até alteração dos pontos. Economia esperada em percursos longos; **não** há medição de FPS/CPU/dispositivo nesta entrega.
4. `MapWeatherService`: não inicia mais `Esp32TelemetryService` por dependência indireta do clima. Continua ouvindo telemetria quando o módulo é iniciado por outro fluxo; cadastro ESP32 permanece disponível.
5. `MapDiagnosticsService` e `DiagnosticReportService`: novo bloco do diagnóstico reúne disponibilidade/permissões, estado de stream, contadores de amostras/minuto, precisão, idade, rejeições, gravação, navegação e MBTiles. Erros de abertura de MBTiles registrados apenas como contador/hora. Sem exportar latitude, longitude, rotas, caminhos de pacotes nem mensagens de exceção; dados de temperatura, bateria e memória continuam no bloco do dispositivo.

## Matriz de operação offline

| Recurso | Operação offline atualmente |
|---|---|
| Mapas MBTiles raster já importados e compatíveis | Sim, para visualização da área coberta pelo pacote. Formato vetorial MBTiles não é suportado nesta implementação |
| Posição GPS, trilha local, persistência do percurso | Dados locais, sujeitos a permissões e execução Android |
| Exportação GPX de percurso gravado | Sim, já existente |
| Cálculo de rota Valhalla | **Não**: servidor remoto |
| Busca online de pontos, Overpass, clima online | **Não**: depende de rede, com alguns fallbacks/cache conforme módulo |
| Estilos vetoriais remotos/OpenFreeMap, Google Maps | **Não**: dependem de rede, chave/configuração conforme serviço |
| IA local | Pode funcionar offline quando ativada, mas não é dependência do Vigia Maps |

## Verificação de 11/10/2026

- ✅ `python3 tool/check_version_sync.py`: versão consistente.
- ✅ `bash tool/verify_project.sh`: contratos e checagens estáticas do projeto, incluindo os existentes de áudio e Android.
- ✅ `bash -n` nos scripts relevantes e `py_compile` dos validadores Python.
- ✅ Testes adicionados/atualizados: política do GPS, contrato de diagnóstico, segurança do relatório e reutilização de snapshots; **arquivos criados, não executados** sem Flutter.
- ⚠️ `flutter analyze`, `flutter test`, compilação Android e medições reais de CPU/bateria não realizados: SDK Flutter/Dart e toolchain Android de build indisponíveis neste ambiente.
- ⚠️ Testes manuais de tela apagada, geolocalização, MBTiles importados, permissões, rádio, RTSP e ESP32 requerem dispositivo Android e, para ESP32, hardware ou simulação futura.

## Riscos e critérios para a próxima versão

- Validar Android 10–16 (conforme público-alvo), incluindo permissão de localização, serviço foreground de localização, economia de bateria, tela apagada e recuperação após encerramento. O lease Android atual é adquirido no módulo de mapas durante navegação; **o simples stream Dart não garante GPS contínuo em segundo plano**, especialmente se o usuário sair da tela ou o sistema encerrar o processo.
- Testar se o intervalo espacial GPS de 8 m mantém registros confiáveis em deslocamento lento, parada, retomada e túneis. Ajustar apenas com evidência e testes de percurso real.
- Medir jank/tempo de frame, memória e CPU com 10 mil a 100 mil pontos gravados. Se necessário, considerar simplificação progressiva de polilinhas, caching por zoom e gravação incremental sem serializar rota inteira a cada persistência.
- Planejar roteamento realmente offline em módulo separado (grafo local por região, estratégia de atualização, perfil ciclável, armazenamento e energia). Não confundir pacote raster MBTiles com dados roteáveis.
- Preservar módulos Camera/IA e ESP32 fora da inicialização da navegação. Cobrir com testes simulados antes de mudar protocolos reais.
