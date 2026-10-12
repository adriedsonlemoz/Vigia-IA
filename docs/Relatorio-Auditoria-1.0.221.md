# Vigia IA — Auditoria crítica e plano de evolução

**Data:** 12/10/2026  
**Base:** versão 1.0.221+221, código-fonte ZIP e 20 capturas (1000001293–1302 e 1000001305–1314).  
**Escopo:** diagnóstico e planejamento. **Nenhuma alteração no aplicativo foi realizada.**

## 1. Síntese executiva

O Vigia IA tem recursos já implementados de navegação, rota prévia, gravação, meteorologia, consulta a POIs, rádio, configurações de sensores, cache e mapas offline. O maior gargalo é a consolidação desses recursos, não a ausência de funções. As prioridades são (1) consistência e validade dos dados mostrados, (2) fluxo de busca/seleção/rota, (3) mapas com HUD adaptativo, (4) arquitetura testável, (5) confiabilidade do modo offline e do consumo energético.

Não confundir problemas demonstrados nas imagens com hipóteses: screenshots não validam presença de internet, condições de rádio/GPS, métricas de consumo ou confiabilidade real da navegação. O código inspecionado confirma várias fontes dos problemas de UI e de classificação de resultados, mas nenhum teste de compilação/execução Android foi realizado nesta auditoria.

### Principais constatações

| P | Constatação | Evidência | Encaminhamento |
|---|---|---|---|
| P0 | GPS mostra `Leitura antiga` (2 min), mas HUD destaca precisão horizontal de ±7 m | 1000001300.jpg; painel GPS e topo | Explicitar idade da amostra onde se mostra precisão; bloquear indicação de posição *atual* quando ultrapassado limite; reaquisição |
| P0 | Busca por `santo Antônio` mostra títulos geograficamente irrelevantes, como Salvador e Porto Alegre a mais de 1.000 km | 1000001302.jpg; `_bestTitle` do serviço antepõe campo `city` ao nome do objeto e `_dedupeAndSort` ordena por distância após busca sem viés geográfico | Relevância textual + tipo de local + contexto geográfico, título canônico do resultado e área distante separada |
| P0 | Alguns POIs usam nomes genéricos e ficha de saúde sem dados para confirmar disponibilidade de serviço | 1000001294.jpg, 1000001309.jpg | Diferenciar POI mapeado de serviço comprovadamente disponível; sinalizar ausência de horário/telefone; não inferir abertura/segurança |
| P1 | Modal de detalhes possui altura expandida mesmo sem metadados | 1000001309.jpg; `_showPoiDetails(... expand: true)` | Altura ajustada ao conteúdo, expandir apenas quando houver dados |
| P1 | Muitos controles sobre o mapa, inclusive funções opcionais | 1000001307.jpg, 1000001314.jpg | HUD por contexto: Explorar / Pedalar / Navegar / Gravar; mover ações secundárias ao menu |
| P1 | Menus com 3 colunas cortam rótulos, diálogos longos e sem contexto | 1000001295–1296.jpg, 1000001312–1313.jpg | Componentes responsivos, fontes acessíveis, categorias em duas colunas/lista e painéis dimensionados pelo conteúdo |
| P1 | Um arquivo de tela reúne ~11.424 linhas | `lib/screens/map_monitoring_screen.dart` | Refatoração por responsabilidade, gradual e coberta por testes |
| P2 | Limite de pneu configurado por padrão em 30 PSI sem sensores conectados | 1000001306.jpg; `BikeSensorSnapshot.minimumTirePressurePsi = 30` | Exibir “não configurado” enquanto não houver perfil do pneu; separar limites dianteiro/traseiro |
| P2 | Gravação e localização dividem espaço de atribuição/licenciamento | 1000001314.jpg | Reservar safe area fixa e preservar os créditos obrigatórios |

## 2. Análise por fluxo e telas

### 2.1 Mapa principal e HUD (1305, 1307, 1314)
- Cinco cartões de telemetria, barra superior e banner de pontos tomam aproximadamente o primeiro quarto da altura na resolução capturada. Botões do lado direito e esquerdo duplicam algumas entradas do menu.
- Modo **Explorar:** mostrar apenas pesquisa, minha posição, camadas e acesso às funções; telemetria recolhida por padrão. **Pedalar:** velocidade/qualidade de GPS, instrução de próxima manobra quando houver, gravação e alertas. **Navegar:** manobra/distância, ETA, linha da rota e controles grandes. **Gravar:** estado explícito e ações de pausar/encerrar.
- Um botão `Recentrar` deve sempre ser distinguível do botão de `Navegação/direção` e do de `Iniciar`. Reduzir controles secundários ou agrupar em menu.
- Manter marca OSM/licenças legível e ancorada ao rodapé em todas as configurações, inclusive gravação e prévia; evitar superposição.
- Padrão de painel: compacto por padrão; expandido sob demanda; preservar retorno ao mapa sem perder seleção/rota.

### 2.2 Menu Vigia IA / configurações gerais (1312–1313, 1295–1296)
- Menu longo exige rolagem para encontrar funções. Reordenar por frequência e agrupar: `Navegação`, `Mapas e downloads`, `Pontos e alertas`, `Mídia`, `Câmeras e sensores`, `Aparência`, `Avançado`.
- `Configurações do mapa`: raio, categorias e alertas devem ser abas/accordions de seção persistente, não vários submenus encadeados.
- Botões de categoria cortados (`Restau...`, `Rios e pont...`). Usar duas colunas no celular, quebra de linha ou lista acessível; atalhos de “Selecionar todas”, “Limpar”, “Salvar perfil”.
- Evitar que a escolha `No caminho` pareça roteamento confiável quando for apenas filtragem por direção angular. Distinguir “à frente” de “sobre a rota calculada”.

### 2.3 Busca de cidades e destinos (1301–1302)
- A busca local exibe Pinga, Iguatama e outras localidades próximas: ponto positivo de resiliência offline. Há entradas que parecem duplicadas de Iguatama (`Local/Offline` e `Vila/Salvo`) e tipos muito distintos misturados.
- Em buscas online, Nominatim é consultado com `q`, mas sem viés geográfico, e os títulos usam campos administrativos antes do nome principal. Isso pode explicar por que uma consulta por um lugar é apresentada com o nome de uma cidade distante.
- Relevância: nome do próprio objeto em primeiro lugar; igualdade/prefixo aproximado e tipo `cidade/vila/comunidade` acima de itens genéricos; depois distância. Mostrar município/UF como contexto, nunca como substituto de um nome que o usuário digitou.
- Separar: `Próximos`, `Resultados na região`, `Outros lugares`, `Salvos`, `Recentes`. Filtros por tipo e estado. Duplicação por mesmo POI OSM e por nome+administração deve ser tratada com cautela, sem fundir lugares homônimos legítimos.
- Manter autocompletar somente **local** com índice/recente. A política do Nominatim público proíbe autocompletar por requisições a cada tecla. Serviço alternativo apenas se licenciado para isso.
- Quando o teclado abrir, preservar lista útil acima dele, sem rodapé cobrindo os resultados. Mostrar distância em linha reta identificada como tal.

### 2.4 Pontos úteis, saúde e seleção de local (1293–1294, 1308–1309)
- A lista está carregando itens úteis, mas vários são genéricos (`Posto próximo`, `Restaurante próximo`) e a distância exibida não equivale ao percurso por vias.
- Mostrar selo de procedência: `OSM mapeado`, `Salvo localmente`, `Pacote offline` e `Última atualização`; nunca transformar `Online` em confirmação de funcionamento.
- Exibir endereço, horário, telefone, website ou detalhes quando houver. Se faltarem, informar `Serviço não verificado`; em saúde, **não inferir plantão** a partir da categoria.
- A ficha do hospital mantém área branca enorme porque a abertura usa `expand: true`. Aplicar modal compacto quando há apenas localização e metadados mínimos; se muitos detalhes, permitir expandir.
- `Detalhes`, `Parada`, `Visualizar` e `Traçar rota` devem estar presentes em padrão coerente. `Adicionar como candidata` não significa que a parada faça parte da rota; exigir cálculo de desvio real antes de fixar ponto no itinerário.
- Investigar diferença aparente entre distâncias do banner e dos resultados. As capturas podem ter filtros/caches/instantes diferentes; instrumentar fonte, instante, origem e método da distância antes de declarar bug.

### 2.5 Modos de transporte e bicicleta (1310–1311, 1305–1306)
- Fluxo atual pode exigir selecionar meio de transporte e depois confirmar velocidade média para cada nova rota de bicicleta. Salvar preferências por perfil e oferecer edição avançada por ação voluntária. Nunca começar a navegar sem decisão explícita.
- `Usar média aprendida` está corretamente indisponível sem histórico suficiente. Indicar critérios mínimos, amostras e confiabilidade da média, além da configuração manual.
- Revisar a faixa de velocidade média e tempo máximo de pedal com validação de limites, unidades e acessibilidade. Evitar qualquer equivalência entre tempo de movimento e chegada no relógio sem contabilizar pausas.
- Tela de pneus mostra **limite 30 PSI**, mas sensores desconectados. Isto deve ser parâmetro individual do conjunto pneu/aro/carga, não padrão universal. Mostrar `Limite não configurado` e não disparar alertas de pressão sem valor calibrado e conexão válida. Preservar simulador com sinalização inequívoca `SIMULAÇÃO`.
- Modo de tela cheia é promissor para economia visual; medir se reduz atualizações gráficas e não apenas esconde controles.

### 2.6 Telemetria: GPS, bússola, altitude, clima (1297–1300)
- O código usa janela de frescor de **20 segundos** em `MapTelemetryPolicy`, mas um painel pode mostrar velocidade/precisão históricos mesmo quando a leitura tem 2 minutos. Apresentar idade no cartão principal e desativar interpretação de dado atual quando vencido o prazo.
- GPS: distinguir precisão do último fix de idade, fonte da posição e adequação para gravação/navegação; exibir instrução acionável em ausência de posição.
- Bússola: distinguir rumo magnético/orientação do aparelho do rumo de deslocamento. Preservar fonte (`rotation_vector`, GPS, rota) e idade do sensor. Indicação de `210° SO` parece consistente com o exemplo.
- Altitude: com uma única amostra, perfil e tendência ficam vazios. Em vez de ocupar espaço fixo, mostrar `Aguardando mais leituras`, quantidade e qualidade das amostras. Não inferir ganho acumulado por ruído do GPS.
- Clima: `Favorável` significa apenas que os **limites locais programados** não foram excedidos; não deve parecer previsão de segurança da estrada. Exibir hora da atualização, validade das próximas horas e distinguir ausência de alerta oficial de ausência de risco.

### 2.7 Gravação e trabalho em segundo plano
- Enquanto grava, há miniplayer de registro inferior com pausa, tempo, distância e encerrar: útil. Tornar inequívoco se o app continua gravando com tela apagada ou em segundo plano e informar permissões/FGS apenas quando necessário.
- Testar recuperação após fechamento forçado, perda de GPS, mudança de rede, bateria baixa, permissão removida e tela bloqueada.
- Não vincular gravação GPX à prévia de rota, salvo ação explícita. Monitorar consumo; com gravador inativo, evitar streaming GPS de alta precisão desnecessário.

### 2.8 Mapas offline e privacidade
- O modo offline deve ser verificado por **quatro camadas independentes**: (1) mapa base presente no dispositivo, (2) geometria da rota salva, (3) locais/POIs guardados e (4) instruções/navegação utilizáveis sem internet. Uma chave Stadia válida não significa que tiles estejam baixados.
- Criar checklist de prontidão offline e diagnóstico sem rede: `Mapa`, `Rota`, `Pontos`, `Áudio`, com estados individuais.
- Uso da localização em pesquisas de terceiros deve ser explícito; registrar parâmetros técnicos em diagnóstico sem expor coordenadas privadas, API keys ou credenciais. Atribuição OSM/fornecedores deve permanecer visível.

## 3. Inspeção de arquitetura

**Confirmado no ZIP 1.0.221:** `lib/screens/map_monitoring_screen.dart` possui aproximadamente **11.424 linhas**, projeto contém **244 arquivos Dart** e **111 arquivos de teste Dart**. Há políticas e serviços já separados, como `map_gps_filter.dart`, `map_destination_search_service.dart`, `route_explorer_service.dart`, `bike_trip_schedule.dart` e `map_telemetry_policy.dart`. Portanto, não é um projeto sem modularização; o problema está na concentração de composição e orquestração da tela principal.

Recomendações:
1. Extrair UI sem alterar comportamento, por blocos: `MapHud`, `MapSearchDialog`, `PoiListPanel`, `PoiDetails`, `MapLayersPanel`, `MapRoutePreview`, `MapTelemetryPanels`, `MapRecordingControls`.
2. Introduzir estados explícitos de navegação/recursos, evitando múltiplos booleanos independentes: `exploring`, `previewing`, `navigating`, `recording`, `locationStale`; gravação é estado ortogonal, não modo mutuamente exclusivo.
3. Serviços via interface/adaptador de rede/tempo/localização para injeção de dublês (HTTP 200/429/504, atraso, GPS antigo, offline).
4. Regressão visual: testes widget/golden em 320/360/412 dp e fatores de texto 1.0/1.3/1.5; conferência vertical/horizontal e com teclado.
5. CI: `dart format --output=none --set-exit-if-changed`, `flutter analyze`, `flutter test`, teste de widget e build antes de empacotar; gerar APK de teste em pipeline. Scripts preventivos não substituem o analisador Dart.
6. Telemetria: latência p50/p95 de buscas, falhas por provedor/código HTTP, hit ratio do cache, tamanho dos pacotes, consumo de rede por módulo, frames lentos e bateria no uso prolongado. Não enviar coordenadas pessoais em logs por padrão.

## 4. Backlog e sequência proposta

| Etapa | Versão proposta* | Entrega delimitada | Critério de aceite |
|---|---|---|---|
| 0. Segurança e baseline | 1.0.222 | Pipeline forte, observabilidade mínima sem dados sensíveis, capturas comparativas e cenários de teste | `flutter analyze`, testes e APK verdes antes da entrega; relatório de baseline |
| 1. Integridade GPS/POI | 1.0.223 | Datas de atualização, GPS antigo no HUD, sem inferir serviços, distâncias explicitadas | Fix de 2 min nunca exibido como atual; POI desconhecido não vira “atendimento confirmado” |
| 2. Busca de destinos | 1.0.224 | Relevância, título correto, agrupamento geográfico, deduplicação e teclado | Busca `Santo Antônio` não rotula logradouro com cidade distante; Iguatama sem duplicatas indevidas; teste offline |
| 3. Pontos úteis | 1.0.225 | Nomes/metadata, cache e status de fonte, distinguir “na rota” de “à frente” | `Offline/Salvo/Online` e idade coerentes; nenhum resultado inventado; falhas HTTP não apagam cache |
| 4. Interface enxuta | 1.0.226 | HUD adaptativo e controles contextuais; menus/categorias legíveis; modal compacto | Mapa predominantemente visível; sem sobreposição; texto legível em 360 dp/1,5x |
| 5. Fluxos de navegação | 1.0.227 | Escolher ponto → prévia → parada opcional → iniciar; preferências de transporte persistentes | Ver rota sem navegar nem gravar; iniciar somente após comando explícito |
| 6. Bike + telemetria | 1.0.228 | Pressões configuráveis, estados ESP32, altitude/clima/bússola claros | Sensor ausente aparece ausente; limiar psi não presumido; simulação identificada |
| 7. Prontidão offline | 1.0.229 | Checklist, teste em modo avião, rota/POIs/tiles separados | Abrir mapa e rota previamente salvos offline; mostrar limites de recálculo |
| 8. Arquitetura + desempenho | 1.0.230+ | Extrações incrementais, golden/integration, profiling, consumo | Não regressão de recursos, baseline comparável e metas de desempenho definidas por medidas |

*Sequência **planejada**, não versões já criadas. Em cada entrega, cumprir `AGENTS.md`: incrementar versão e build, atualizar metadados/notas e validar. Etapas podem ser divididas em releases menores conforme riscos.

## 5. Critérios transversais de aceitação

- **Exatidão:** nenhuma informação ausente deve ser transformada em valor real; distâncias em linha reta e por rota separadas; sensor antigo/dado offline/cache diferenciado.
- **Busca:** abrir, digitar, apagar, fechar e navegar sem perder contexto; resultados próximos pertinentes vêm antes dos distantes, sem bloquear destino distante buscado intencionalmente.
- **Interface:** largura 320–412 dp, fatores de texto 1x/1,3x/1,5x, com teclado aberto, orientação retrato/paisagem, tema claro/escuro; sem botões cobertos pelo teclado ou rodapé.
- **Offline:** três cenários: só mapa, mapa + POIs, mapa + rota. Aplicativo explica o que ainda não está disponível sem rede.
- **Bateria:** medir três percursos equivalentes por modo (exploração, navegação, gravação); padronizar brilho, rede e intervalo de amostragem. Só prometer economia após linha de base real.
- **Segurança:** confirmação antes de encerrar gravação com perda de dados ou excluir chave; sem credenciais nem histórico exato de localização em logs compartilháveis.
- **Compilação:** todo ZIP segue análise Dart, testes automatizados e build Android em CI, com artefatos e log quando a validação passar.

## 6. Cenários de validação manual

1. Abrir mapa parado com GPS antigo e confirmar que idade da leitura aparece no HUD.
2. Buscar `santo Antônio`, `Iguatama`, `Divinópolis` (com/sem acento) e local remoto escolhido intencionalmente; verificar nomes, filtros, duplicados.
3. Abrir busca com teclado SwiftKey e verificar visibilidade dos três primeiros resultados e botão de fechar.
4. Abrir saúde sem telefone/horário; garantir que ficha é pequena e não anuncia serviço confirmado.
5. Selecionar local, abrir prévia de rota, mudar transporte, retornar ao mapa e cancelar sem iniciar a navegação.
6. Iniciar/pausar/retomar/encerrar gravação e conferir GPX após bloqueio de tela.
7. Ativar modo avião depois de baixar um mapa e salvar rota/POIs; conferir independência dos quatro componentes offline.
8. Visitar telas GPS, bússola, altitude, clima com leituras inexistentes ou envelhecidas.
9. Abrir categoria, alertas e mapas em fonte ampliada e aparelho estreito.
10. Simular telemetria ESP32 e confirmar aviso de simulação e desativação de alarmes de pressão sem limites configurados.

## 7. Metas e dependências

Metas de UX propostas, **não medidas**: mapa ocupar a maior parte da área utilizável no modo Pedalar; dados críticos serem lidos sem abrir diálogos; ao aumentar texto para 1,5x, a interface rolar em vez de cortar opções; botão principal ter alvo confortável para toque sem distração. Para taxa de quadros e bateria, estabelecer baseline no aparelho antes de fixar números. Metas de latência online não podem pressupor SLA dos servidores públicos.

Fontes técnicas:
- Política oficial do Nominatim: https://operations.osmfoundation.org/policies/nominatim/
- Android, localização e consumo: https://developer.android.com/develop/sensors-and-location/location/battery
- Testes Flutter (unitários/widget/integração): https://docs.flutter.dev/testing/overview e https://docs.flutter.dev/cookbook/testing/integration/introduction

## 8. Deliberação

Recomendação de arranque: etapas **0 → 1 → 2 → 3**, antes da reformulação visual ampla. Assim, a próxima tela desenhada refletirá dados mais confiáveis, e a refatoração será protegida por testes. A validação física no dispositivo e o modo avião são portas de saída obrigatórias para qualquer release orientada à cicloviagem.

**Status:** somente análise e plano. O aplicativo não foi modificado. A versão permanece 1.0.221+221.
