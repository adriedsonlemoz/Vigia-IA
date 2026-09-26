# Vigia IA

Aplicativo Flutter, inicialmente para Android, para monitoramento local por câmera do aparelho, câmera IP/RTSP ou outro celular na mesma rede. A detecção de objetos, regras, histórico, alertas e processamento de IA são executados localmente sempre que possível.

> **Versão atual:** `1.0.148+148`

## Estado atual

A `1.0.148+148` é a etapa de **desempenho e estabilidade** do bloco mapa + Bike, reduzindo atualizações, consultas e rebuilds redundantes sem afrouxar navegação, alertas ou IA.

### Evolução 1.0.148 — desempenho e estabilidade

A `1.0.148+148` reduz trabalho repetido no bloco mapa + Bike: GPS menos ruidoso, POIs sem rebuild por amostra, cooldown para buscas automáticas e deduplicação dos estados de câmera remota. Navegação, alertas, IA e TTC mantêm a mesma lógica funcional.

### Correção 1.0.147 — Android-APK-110

- `MapNavigationVoicePolicy` captura o marco selecionado em uma variável não nula antes do filtro, removendo o erro `int?` → `num` apontado pelo analyzer.
- O módulo `map_monitoring_offline_support.dart` passa a solicitar atualizações de UI por um método do próprio `State`, em vez de chamar o método protegido `setState` diretamente pela extension.
- Removidos a asserção `!` redundante do provider offline e o aviso de inicialização do catálogo de Novidades, sem mudança funcional.

### Evolução 1.0.146 — offline aprimorado + revisão visual do mapa

- `MapConnectivityService` acompanha a conectividade somente enquanto o mapa está em uso e diferencia online/offline sem depender de um booleano da interface.
- Ao perder a rede durante uma navegação, a geometria viária já carregada é preservada; se nunca houve rota viária, o app informa claramente que está mostrando apenas a direção ao destino.
- A recuperação é automática: ao detectar internet novamente, o Vigia IA atualiza POIs online e tenta obter/recalcular a rota sem exigir reiniciar a navegação.
- `RouteExplorerService` seleciona imediatamente o melhor pacote offline para a posição atual, recalcula distâncias localmente e evita insistir em consultas online quando a conexão já está marcada como indisponível.
- O seletor de camada passa a mostrar `Sem internet`, `Offline automático` ou `Reconectando rota`, sem criar uma barra adicional cobrindo o mapa.
- Controles laterais, margens, zoom, filtros rápidos, banner de navegação e barra de percurso foram compactados; PiPs recebem limite menor durante navegação, com reservas ajustadas em retrato e paisagem.

### Evolução 1.0.145 — POIs + navegação por voz

- Alertas de POIs respeitam as categorias selecionadas no momento do aviso, a distância configurada e a direção do deslocamento.
- O mesmo fluxo funciona para resultados online e pacotes offline; um intervalo global de 1 minuto impede rajadas de alertas quando vários locais estão próximos.
- Quando um POI só é descoberto já perto, marcos maiores já ultrapassados são consumidos para evitar avisos atrasados/repetidos.
- `MapNavigationVoicePolicy` anuncia a próxima manobra nos marcos de 1 km, 500 m, 200 m e 80 m, com distância arredondada para fala natural.
- Saída confirmada da rota, recálculo, rota recalculada e chegada têm anúncios próprios; chegada é falada uma única vez.
- `MapVoiceService` reutiliza `AlertVoiceService` e as preferências globais de voz/TTS, e também coordena os avisos falados de POIs para não criar outro sistema paralelo.

### Evolução 1.0.144 — estados da IA nos PiPs

- `MonitorAiStatusResolver` centraliza a prioridade dos estados e impede `Analisando` quando a IA não está habilitada.
- O PiP que reutiliza o Monitor lê detector, processamento, fonte e último frame do `MonitorController`; nenhum detector adicional é instanciado.
- `IA ativa`, `IA desligada`, `Aguardando frames`, `Sem frames`, `Analisando` e `Possível erro da IA` ficam explícitos em um chip compacto.
- Falha de câmera local aparece como `Câmera indisponível`; RTSP, celular remoto e ESP32 distinguem `Conexão perdida`.
- Câmeras secundárias e fontes abertas apenas pelo mapa permanecem somente visuais e exibem `IA desligada` quando a fonte está normal.
- O estado da IA convive com o indicador de aproximação/TTC dentro do PiP sem ocupar a área do mapa.

### Evolução 1.0.143 — aproximação de veículos + novidades da atualização

- O mapa reutiliza `MonitorController.bikeApproachStatus`; não existe um segundo estimador nem uma segunda inferência para o PiP.
- O PiP analisado distingue veículo detectado sem aproximação, aproximação em observação, risco alto e risco crítico, incluindo TTC quando disponível.
- A informação fica em uma faixa compacta dentro do PiP e não altera as reservas de HUD, rota ou cards de navegação.
- Câmeras abertas apenas pelo mapa não recebem o indicador de risco, evitando atribuir IA a uma fonte que não está sendo analisada pelo Monitor.
- `UpdateNewsService` compara a versão realmente instalada no Android, persiste `version+build` localmente e reúne versões não vistas quando o usuário pula atualizações.
- `UpdateNewsHost` libera a abertura do app mesmo se leitura/persistência das novidades falhar.

### Buildfix 1.0.142 — Android-APK-107

- `flutter analyze` voltou a passar sem avisos e o workflow chegou à suíte de testes.
- A falha permaneceu isolada em `map_poi_details_sheet_test.dart`: uma rolagem fixa podia apenas expandir o `DraggableScrollableSheet`, sem alcançar a seção de comodidades.
- O teste agora usa `scrollUntilVisible` no `Scrollable` do painel e continua até `Água potável` realmente entrar na árvore renderizada.
- Nenhuma lógica de produção do mapa, painel de POI ou PiPs foi alterada neste buildfix.

### Buildfix 1.0.141 — Android-APK-106

- `flutter analyze` do build 106 passou sem avisos; a falha ficou isolada em `map_poi_details_sheet_test.dart`.
- O teste agora rola o `ListView` antes de validar a comodidade `Água potável`, respeitando a construção lazy de conteúdo fora da dobra.
- Nenhuma lógica de produção do painel de POI ou dos PiPs foi alterada neste buildfix.

### Evolução 1.0.140 — PiP de câmera mais inteligente

- O estado global de exibição das câmeras sobre o mapa passa a ser persistido junto do layout dos PiPs.
- Quando todas as câmeras estiverem ocultas, o mapa mostra um atalho compacto **Mostrar câmera** sem exigir abrir o menu de opções.
- Durante navegação ativa, PiPs grandes recebem redução temporária de escala para preservar instruções, rota e área útil do mapa; o tamanho salvo volta automaticamente ao encerrar a navegação.
- Ao arrastar e soltar um PiP, o encaixe considera a outra câmera e evita deixar as duas no mesmo canto; em retrato separa verticalmente e em paisagem separa lateralmente.
- O gerenciador continua permitindo trocar fonte, minimizar, ocultar, alterar tamanho e restaurar o layout, agora sincronizando também a visibilidade global.

### Evolução 1.0.139 — painel completo do local

- Tocar em um marcador individual abre o painel completo; o componente foi extraído da tela principal para `MapPoiDetailsSheet`, reduzindo acoplamento no mapa.
- Cabeçalho resume nome, categoria, distância e origem online/offline.
- Endereço, horário, telefone, site e operador/marca são exibidos em uma área estruturada quando disponíveis.
- Endereço, telefone, site e coordenadas têm cópia rápida para a área de transferência.
- Comodidades aparecem em chips e as coordenadas permanecem disponíveis mesmo quando a origem não fornece outros dados.
- A ação principal é `Ir até lá`; `Mostrar no mapa` permanece como ação secundária.

### Evolução 1.0.138 — POIs enriquecidos + natureza/cicloviagem

- POIs preservam endereço, horário, telefone, site, operador/marca e comodidades quando publicados na base consultada.
- `RouteExplorerPoiCatalog` centraliza classificação e metadados sem aumentar a responsabilidade da tela do mapa.
- Novas categorias: Camping, Mirantes, Cachoeiras e Mercados/Suprimentos; Oficinas seguem incluindo suporte para bicicleta.
- Filtros rápidos `Natureza` e `Bike/viagem` ajudam a separar pontos úteis durante deslocamentos.
- Pacotes offline guardam os novos campos e continuam recalculando distância localmente.
- Migração do catálogo habilita as novas categorias para quem atualizar da versão anterior, sem limpar dados.
- Seleção equilibrada impede que categorias muito numerosas eliminem totalmente POIs de viagem/natureza da lista limitada.

### Evolução 1.0.137 — rotas alternativas

- `MapCyclingRouteService` solicita até duas alternativas além da rota principal e remove respostas duplicadas.
- Todas as opções disponíveis aparecem sobre o mapa; alternativas ficam secundárias e a rota escolhida permanece em destaque.
- O banner de navegação mostra qual rota está ativa e oferece um seletor com distância e duração de cada opção.
- Ao trocar de rota, instruções, progresso e detecção de desvio passam imediatamente a usar a nova geometria.
- Recálculo automático continua protegido por confirmação de desvio e cooldown, retornando um novo conjunto de opções quando disponível.

### Evolução 1.0.136 — navegação guiada + recálculo automático

- O roteador passa a solicitar instruções em português e importar as manobras retornadas junto da geometria da rota.
- O HUD mostra instrução atual, próxima manobra, distância até a próxima ação, distância/tempo restantes e progresso percentual.
- `MapNavigationGuidance` calcula progresso e distância até a geometria sem chamadas de rede.
- Desvio só dispara recálculo após duas leituras consecutivas fora da rota; há cooldown de 45 s para evitar chamadas repetidas.
- Rota restaurada ao reabrir a tela volta a ser consultada para recuperar geometria e instruções.
- O fallback por direção direta continua disponível quando o serviço de rota não responde.

### Refinamento 1.0.133 — mapa mais limpo em uso real

- POIs usam clustering por proximidade, limite de densidade por zoom e prioridade para combustível, saúde, comida e água; rios/pontes deixam de dominar a visão regional.
- Marcadores recebem cores e ícones por categoria; tocar em um cluster aproxima o mapa e o POI selecionado permanece sempre individual.
- HUD superior prioriza velocidade, GPS e altitude; distância/tempo saem do topo e aparecem na barra compacta de gravação quando o percurso está ativo.
- Coluna lateral fica reduzida a zoom, seguir posição e Opções; camadas, orientação e câmeras continuam acessíveis pelo menu rápido e pelo chip de camada.
- Barra de percurso passa a ocupar menos mapa: `Gravar` quando inativa e, durante a gravação, mostra pausa, tempo, distância e encerrar.
- PiPs minimizados viram bolhas, duplo toque alterna tamanho, a segunda câmera ganha posição automática e fontes abertas pelo mapa podem trocar entre câmera 1 e 2.
- Scrims transparentes mantêm status/navigation bar legíveis sobre mapas claros; o card do POI é ocultado quando o mesmo ponto já está representado pela navegação.

### Correção 1.0.132 — Android-APK-99

- Corrigidos dois erros `undefined_class` em `MapMonitoringScreen`: o modelo `OfflinePoiPackage` existia, mas seu arquivo não estava importado na tela.
- Removido `package:flutter/foundation.dart` redundante de `MapRouteService`, eliminando o `unnecessary_import` reportado pelo analyzer.
- A verificação preventiva agora cobre ambos os casos para evitar regressão do buildfix.

### Evolução 1.0.131 — UX final + revisão do mapa

- HUD do mapa fica responsivo em telas estreitas e paisagem: telemetria/atalhos compactam sem esconder velocidade, distância, rumo e acompanhamento;
- zoom +/− vira um único cluster fixo e o acesso a camadas permanece no chip superior, removendo um controle duplicado da lateral;
- PiPs passam a respeitar zonas seguras acima do HUD e acima de percurso/navegação/POI, evitando cobrir controles e cards importantes;
- corrigida a normalização da posição persistida dos PiPs, que antes ignorava as margens mínimas e podia deslocar as janelas ao reabrir;
- ações da câmera foram condensadas em um menu único para manter PiPs pequenos utilizáveis; gerenciador ganhou restauração de posição/tamanho;
- card de POI fica mais compacto em telas estreitas e continua acessível por toque no próprio texto; atribuição do mapa sobe automaticamente quando há cards inferiores;
- tela de localização indisponível abandona AppBar grande e preserva o padrão de controles flutuantes;
- atualização de pacote offline passa a consultar a internet diretamente e preserva o pacote salvo se a atualização falhar, em vez de regravar silenciosamente os dados antigos;
- revisão final inclui `MapUxPolicy` e testes de HUD, zonas seguras e normalização de posição.

A `1.0.130+130` fecha os blocos de câmeras sobre o mapa e desempenho para uso prolongado, unificando Home/Monitor na mesma experiência de mapa e reduzindo trabalho contínuo de câmera, GPS, POIs e desenho de percurso.

### Evolução 1.0.130 — câmeras no mapa + desempenho

- o mapa passa a gerenciar até dois PiPs próprios e também reutiliza as visualizações já abertas pelo Monitor, sem duplicar o pipeline de IA;
- seletor de fonte disponível dentro do mapa para traseira/local, frontal, RTSP, celular remoto, ESP32 e fontes cadastradas na Central multicâmera;
- cada PiP pode trocar fonte, minimizar, ocultar, alternar tamanho e encaixar no canto mais próximo; posição, tamanho e estado visual ficam persistidos;
- fontes abertas exclusivamente pelo mapa são suspensas quando minimizadas, ocultas ou quando o app vai para background e retomadas somente quando necessário;
- Home e Monitor continuam abrindo `MapMonitoringScreen`, mas agora a Home não depende de câmera previamente injetada para usar os PiPs;
- `MapRouteService` deixa de notificar a árvore inteira a cada segundo apenas pelo cronômetro; o tempo fica em um widget isolado;
- GPS contínuo passa a usar contagem de consumidores e pode ser liberado quando nenhuma tela precisa dele e não há gravação/navegação ativa;
- `RouteExplorerService` ignora notificações sem nova posição GPS e percursos longos são reduzidos apenas para renderização, preservando os dados completos para GPX/histórico;
- adicionados testes do layout persistente dos PiPs e verificações preventivas da integração de câmera/desempenho.

A `1.0.129+129` fecha dois blocos do redesign do mapa: camadas/tipos de mapa com controles reorganizados e Próximos pontos com pacotes offline regionais, card compacto de seleção e atualização automática durante o deslocamento.

### Evolução 1.0.129 — camadas + POIs offline por região

- modos **Padrão**, **Bike/Viagem**, **Terreno**, **Topográfico** e **Satélite**; OSM continua sendo a base gratuita, Bike usa Outdoors quando a chave Stadia já existente está disponível e Topográfico usa OpenTopoMap com atribuição;
- Terreno e Satélite usam a infraestrutura configurável da Stadia e ficam indisponíveis sem chave, sem criar dependência paga obrigatória;
- controles permanentes foram reduzidos e funções secundárias passaram ao menu **Opções**;
- Próximos pontos ganhou card compacto persistente no mapa, destaque do marcador, detalhes e **Navegar até**;
- dados offline de POI agora são pacotes independentes com nome, área coberta, data, raio e quantidade de pontos; o formato legado de lista única migra automaticamente para **Lista offline antiga**;
- atualização automática de POIs deixa de depender da gravação de percurso e considera deslocamento, tempo em movimento, mudança relevante de direção e aproximação da borda da região pesquisada;
- adicionados testes para modos de mapa e serialização/bounds dos pacotes de POI offline.

A `1.0.128+128` é um buildfix do mapa para o workflow Android: corrige o Material Icon inválido identificado pelo `flutter analyze` do Android-APK-95, sem alterar o comportamento funcional da visão à frente introduzida na 1.0.127.

### Correção 1.0.128 — Android-APK-95

- Corrigido `Icons.offline_map_rounded`, que não existe no Flutter 3.44.9 e interrompia `flutter analyze` com `undefined_getter` e `const_with_non_constant_argument`.
- O botão **Mapas offline** usa `Icons.download_for_offline_outlined`, já utilizado em outros pontos da mesma tela e reconhecido pelo SDK do workflow.
- `tool/verify_project.sh` passa a rejeitar o identificador inválido para evitar regressão antes do próximo build.
- Nenhum fluxo de GPS, percurso, orientação, POIs ou câmeras foi removido nesta correção.

### Evolução 1.0.127 — visão à frente e orientação do mapa

- Ao acompanhar o GPS, o usuário deixa de ficar cravado no centro: `MapController.move(offset:)` o posiciona mais abaixo da tela para ampliar a estrada visível à frente sem alterar a coordenada real.
- O zoom de acompanhamento padrão abre mais contexto (`14.7`) e o modo **Região** usa `12.2`; zoom manual continua possível sem desligar automaticamente o acompanhamento.
- Novo controle alterna **Norte fixo** e **Acompanhar direção**. O modo por direção gira a câmera no sentido oposto ao heading para manter o deslocamento apontando para o topo.
- A rotação por heading só é atualizada acima de 3 km/h e com mudança angular relevante, reduzindo tremedeira quando a bike está parada ou o rumo oscila poucos graus.
- Gestos de rotação manual ficam desativados; a orientação é explícita e previsível pelos dois modos do mapa.
- Atalhos flutuantes **Perto / Região / Rota** permitem trocar o enquadramento rapidamente. **Rota** ajusta a câmera para conter percurso gravado, posição atual e destino ativo quando disponíveis.
- Orientação e preset de acompanhamento ficam persistidos em `map_view_settings.json` para manter a preferência entre aberturas.
- POIs, início/fim e destino são contrarrotacionados para permanecerem legíveis; o marcador do usuário gira junto com o mapa e mantém a seta coerente com o heading.
- Corrigido trabalho desnecessário: ticks do cronômetro do percurso não recentralizam mais a câmera quando não chegou uma nova posição GPS.
- Posições iniciais dos PiPs foram deslocadas para não cobrir os novos atalhos de visão.
- Adicionado `MapViewPolicy` com testes de zoom, rotação, dead-zone angular e deslocamento visual.

### Evolução 1.0.126 — GPS confiável, percurso e destino separados

- Novo `MapGpsFilter` valida coordenadas, precisão, ordem temporal, velocidade reportada e deslocamento plausível antes de atualizar a posição usada pelo mapa.
- Leituras com precisão pior que 60 m são descartadas; a gravação do percurso exige até 35 m, evitando que GPS fraco infle a distância.
- Posição, velocidade baixa e rumo recebem suavização; rumo cruza 0/360 pelo caminho curto e, quando necessário, pode ser derivado do deslocamento aceito.
- Jitter pequeno deixa de entrar no percurso: o limiar mínimo cresce conforme a incerteza das duas leituras, além da proteção já existente para saltos >250 m.
- `MapRouteService` passa a expor **gravação** explicitamente (`startRecording`, pausar/retomar/encerrar), mantendo wrappers antigos para compatibilidade.
- A interface troca **Iniciar rota** por **Gravar percurso** e diferencia a sessão registrada da nova ação **Navegar até**.
- POIs podem virar um `MapNavigationTarget` persistente; o mapa mostra destino, distância e rumo direto sem fingir que isso é navegação curva-a-curva.
- Ao encerrar, o fim do percurso usa o último ponto realmente gravado, e não uma posição atual possivelmente inadequada para a trilha.
- Se o processo for recriado durante uma gravação, o tempo sem coleta é tratado como interrupção e o próximo ponto abre novo segmento, evitando tempo/distância artificiais.
- Persistência sobe para schema 3 mantendo leitura de `tracking` legado, e novos testes cobrem filtros, limiares, suavização de rumo e serialização do destino.

### Evolução 1.0.125 — mapa em tela cheia e percurso integrado

- O mapa completo ocupa praticamente toda a tela, sem AppBar fixa; o conteúdo continua atrás das áreas do sistema e somente os controles respeitam notch/status/navigation bar.
- Voltar, zoom +/−, seguir GPS, Próximos pontos, câmeras, mapas offline e configurações viram controles flutuantes; em paisagem a coluna se transforma em uma faixa horizontal para não perder botões.
- A visualização padrão abre um pouco mais ampla (zoom 15) e mantém zoom manual fixo, navegação livre e retorno rápido ao acompanhamento da posição.
- **Próximos pontos** é integrado ao mapa: resultados Online/Offline aparecem como marcadores clicáveis, com filtros Todos/Postos/Comida/Saúde/Água/Outros, distância e detalhes.
- Tocar em um ponto na lista do Monitor agora abre o mapa completo já centralizado naquele local.
- A busca inicial é executada ao abrir o mapa e, em rota ativa com modo **No caminho**, é renovada automaticamente após 1,5 km ou 5 minutos; se a rede falhar, a lista offline permanece como fallback.
- O limite visual da busca foi ampliado de 12 para 36 resultados para dar mais contexto em viagem sem transformar a tela em catálogo infinito.
- A barra de percurso foi compactada e mantém iniciar/encerrar, pausar/continuar e exportar GPX sem roubar a largura inteira do mapa.
- Saltos de GPS acima de 250 m passam a iniciar um novo segmento, evitando linhas artificiais atravessando o mapa e sem somar o salto na distância.
- Uma ou duas câmeras continuam móveis sobre o mapa; a posição inicial deixa livre a coluna de controles e se adapta a retrato/paisagem.
- Configurações de raio, categorias, busca no caminho, voz/notificação, distância de alerta, mapas offline e exportação GPX ficam acessíveis sem sair do mapa.
- Foram adicionadas verificações/testes de regressão para política de rota e atualização automática de pontos.

### Evolução 1.0.124 — estado individual dos sensores ESP32

- O card de cada módulo ganha a seção **Sensores e recursos**, em vez de misturar capacidades e valores em chips genéricos.
- Cada item pode aparecer como **Lendo agora**, **Detectado**, **Aguardando leitura**, **Módulo offline** ou **Detectado · não configurado**.
- Temperatura, Hall, pneus, bateria do módulo e energia exibem o último valor recebido na própria linha do recurso.
- Firmware legado continua útil: velocidade, pressão, temperatura, bateria e energia são inferidos pela telemetria mesmo quando o ESP32 não publica `capabilities`.
- Se o firmware anunciar um sensor novo que não foi marcado no wizard, ele aparece automaticamente e oferece atalho para revisar o cadastro.
- Wi‑Fi, endpoint, uptime, sequência e reconexão ficam separados em **Conexão**, reduzindo confusão entre rede e sensores físicos.
- Adicionados testes de regressão para os cinco estados e para inferência de capacidades em firmware legado.

### Evolução 1.0.123 — energia, bateria e solar no ESP32

- Nova capacidade **Energia** separa a alimentação do próprio ESP32 da bateria principal monitorada.
- O wizard permite escolher alimentação do módulo por detecção automática, power bank USB, tomada/fonte USB, bateria do sistema ou outra fonte.
- A bateria principal pode ser **Chumbo-ácido**, **LiFePO₄**, outra química ou simplesmente inexistente durante testes de bancada.
- O cadastro prepara medição por firmware, divisor de tensão, **INA219**, **INA226** ou BMS com telemetria; INA226 fica indicado como opção recomendada para instalação definitiva.
- Tensão nominal, capacidade em Ah, níveis de aviso/crítico e monitoramento da entrada solar passam a fazer parte do perfil persistente do módulo.
- O protocolo `/config` passa a enviar o bloco `energy`, enquanto a telemetria aceita bateria principal, corrente, potência, temperatura da bateria, fonte de alimentação, modelo do monitor e dados solares.
- A tela ESP32 diferencia **bateria do módulo** de **bateria principal** e mostra A/W/solar quando o firmware fornecer esses dados.
- O diagnóstico exportado inclui configuração e runtime de energia sem exigir que uma bateria física esteja conectada.
- A integração é compatível com módulos antigos: os novos campos são opcionais e não alteram câmera, Hall, pneus ou temperatura.

### Evolução 1.0.122 — wizard de configuração ESP32

- A configuração deixa o diálogo técnico único e passa para um wizard de 5 etapas em tela inteira.
- A primeira etapa testa o endereço atual e tenta `192.168.4.1`/`esp32.local`, mantendo endereço/chave manual como opção avançada.
- Nome e posição ficam separados da conexão; capacidades detectadas pelo firmware são pré-selecionadas e sensores futuros continuam disponíveis no mesmo cadastro.
- A etapa de ajustes só mostra temperatura, Hall, pneus e câmera quando essas capacidades foram escolhidas; telemetria e ativação ficam em opções avançadas.
- A revisão final permite testar novamente antes de salvar, e o cadastro continua permitido mesmo com o hardware desligado.
- A tela vazia mantém apenas um CTA; o FAB aparece somente quando já há módulos cadastrados.
- Corrigido o Android-APK-90 removendo o import desnecessário de `foundation.dart` em `esp32_telemetry_service.dart`.
- Uma lista de capacidades explicitamente vazia agora permanece vazia após reiniciar, sem reativar sensores padrão indevidamente.


### Evolução 1.0.121 — telemetria contínua e reconexão ESP32

- `Esp32TelemetryService` acompanha todos os módulos habilitados enquanto o app está em primeiro plano e pausa o polling em segundo plano para economizar energia.
- A descoberta aceita `/api/v1/telemetry`, `/telemetry`, `/api/v1/status` e `/status`, memorizando o endpoint que respondeu sem abandonar firmware legado.
- Cada módulo mantém estado de conexão, latência, última leitura, próxima tentativa, falhas consecutivas, RSSI, bateria/alimentação, firmware, protocolo e capacidades reportadas.
- A reconexão é automática e usa backoff até 30 s; leituras ainda dentro do `staleAfter` ficam como conexão instável antes de serem declaradas offline.
- `BikeSensorService` agrega vários ESP32 sem alternar aleatoriamente o HUD: velocidade, pneus, bateria e temperatura podem vir de módulos diferentes.
- Sensores ausentes são marcados como indisponíveis em vez de assumirem valor zero, evitando falsos alertas de pneu, bateria ou temperatura.
- O relatório de Diagnóstico passa a incluir o estado detalhado de cada módulo ESP32.

### Evolução 1.0.120 — fundação modular do ESP32

- `Esp32Module` passa a ser a fonte de verdade para identidade, posição, capacidades, limites e intervalo de telemetria do hardware.
- `Esp32ModuleService` persiste os módulos separadamente, protege endereço/chave, migra cadastros ESP32 antigos e só publica uma `CameraEndpoint` derivada quando o módulo realmente possui câmera.
- O catálogo de capacidades já reconhece câmera, temperatura, Hall, pneus, bateria, mmWave, térmico, ToF, ultrassom, ambiente, GPS, luz e atuadores.
- Cada módulo pode ser identificado por posição/função, como dianteiro, traseiro, guidão, caixa, capacete, reboque ou posição personalizada.
- `BikeSensorService` passa a manter telemetria por `moduleId`, preparando múltiplos ESP32, e o timeout de perda de dados acompanha o intervalo configurado (`max(6 s, 3× intervalo)`).
- Pressão mínima e temperatura máxima configuradas no módulo passam a participar de fato da classificação de saúde/alertas do snapshot.
- Firmware antigo continua compatível: os cadastros baseados em `CameraEndpoint` são migrados automaticamente na primeira abertura.

### Evolução 1.0.119 — ícones reais na Home e telas compactadas

- **Ao vivo**, **Transmissão**, **Remoto** e **ESP32** usam os quatro PNGs transparentes gerados para o redesign diretamente como assets Flutter.
- `VigiaModeCard` aceita `imageAsset` sem perder o ícone Material de fallback e sem alterar o destino de cada card.
- O Histórico usa quatro filtros compactos próprios — **Todos, Pessoas, Veículos e Animais** — evitando o check/ícone desalinhado do `ChoiceChip`.
- O card de cada câmera coloca **Monitorar** no cabeçalho, ao lado do nome, reduz altura e mantém **Abrir com segunda câmera** dentro do menu de opções.

### Evolução 1.0.118 — qualidade Bike e controle fino de voz

- Perfil **Economia** passa para 7 FPS, até 960 px e JPEG 76; **Economia extrema** usa 5 FPS, até 800 px e JPEG 72.
- A tela **Áudios e voz** permite ativar/silenciar cada aviso individualmente e ativar ou silenciar todos de uma vez.
- O TTS de fallback fica desligado por padrão para evitar mistura com a voz gravada; TTS de mensagens sem áudio integrado continua configurável separadamente.
- Os 64 avisos Bike/ESP32 deixam de aparecer como “Futuro”; continuam usando os recursos integrados já presentes no APK.
- O emulador ESP32 reproduz automaticamente o aviso integrado correspondente ao cenário selecionado, respeitando as preferências de voz.
- O alerta de aproximação usa o áudio integrado de veículo em vez de depender de TTS sempre que a voz estiver habilitada.

### Evolução 1.0.117 — Home compacta, Bike como perfil e Transmissão ajustável

- A Home usa quatro cards curtos em 2x2: **Ao vivo**, **Transmissão**, **Remoto** e **ESP32**.
- Os cinco acessos rápidos ficam na mesma linha no celular para reduzir rolagem.
- **Bike e economia** passa a ser configuração em Ajustes, e instalações antigas com Bike como modo inicial são migradas com segurança para Ao vivo sem apagar o perfil Bike salvo.
- O emulador de sensores saiu da tela Bike e foi para **ESP32 > engrenagem > Emulador de sensores**.
- A tela Transmissão ganhou engrenagem para editar Bike/economia sem trocar de modo e mostra a bateria do aparelho transmissor.
- A transmissão passou a usar uma frequência própria de frames: padrão 10 FPS; Bike Normal 10 FPS; Economia 6 FPS; Economia extrema 3 FPS. O receptor continua responsável pela IA.
- Para preservar legibilidade, os perfis usam até 960 px/78, 800 px/72 e 640 px/64 de qualidade JPEG, respectivamente.

### Correção 1.0.116 — Android-APK-84 e compactação segura

- `flutter analyze` passou sem problemas no workflow; a falha ocorreu em `flutter test` por dois `RenderFlex overflow` na nova interface compacta.
- `VigiaModeCard(compact: true)` recebeu padding, ícones, espaçamentos, tipografia e pills mais densos para caber em células estreitas sem esconder título, descrição ou tags.
- `VigiaQuickAction` foi reduzido para manter rótulos longos, como **Diagnóstico**, dentro da célula responsiva de 104x96 usada pela Home.
- Os testes de regressão que falharam no Android-APK-84 foram preservados; a correção atua nos componentes reais em vez de afrouxar as expectativas.
- IA, mapas, áudio, transmissão, multicâmera, ESP32, Bike e histórico não tiveram sua lógica alterada.

### Evolução 1.0.115 — Home compacta, mapa compacto e ESP32 dedicado

- Os quatro módulos principais ficam em grade 2x2: **Monitor ao vivo**, **Modo transmissão**, **Modo Bike** e **ESP32**.
- O card **ESP32** abre a tela já existente de configuração do módulo, sensores, calibração e câmera; o item duplicado foi removido de **Ajustes > Monitoramento**.
- Os cinco **Acessos rápidos** usam grade responsiva em telas estreitas para evitar corte de rótulos como Diagnóstico.
- **Configurações do mapa e percurso** concentra mais opções na mesma área sem misturar uso e configuração: chips menores para raio, busca, categorias, alertas e distância; ações offline em duas colunas; mini mapa compacto.
- Os controles continuam ligados aos mesmos `RouteExplorerService` e `MapRouteService`; mapas offline, alertas, busca e persistência não foram duplicados.

### Correção 1.0.114 — Android-APK-82

- Corrigidos dois parâmetros inválidos `minSize` no `ButtonStyle`; o design system agora usa `minimumSize`, compatível com Flutter 3.44.9.
- Corrigidos os delimitadores de listas/`Stack` em `monitor_screen_multicamera.dart` que interrompiam o parser do analyzer.
- O estado dos toggles da Home deixou de chamar `setState` diretamente pela extension e passa por um helper pertencente ao próprio `State`.
- Removidos componentes/método privados não utilizados que geravam warnings no analyzer.
- Mantidas a fundação do redesign, a Home, mapas, IA, áudio, transmissão, multicâmera, ESP32 e Bike sem duplicação de lógica.

### Evolução 1.0.113 — fundação do novo design e Home

- Criado `lib/core/vigia_design.dart` como base compartilhada de cores, superfícies, raios, botões, chips, diálogos e navegação, mantendo o tema escuro como padrão visual principal.
- Criado `lib/widgets/vigia_ui.dart` com componentes reutilizáveis de seção, superfície, status, cards de modo e acessos rápidos para as próximas etapas do redesign.
- A Home passou a destacar **Monitor ao vivo**, **Modo transmissão** e **Modo Bike**, cada um com descrição curta e acesso direto.
- Adicionados acessos rápidos para **Câmeras**, **Mapa**, **Histórico**, **Diagnóstico** e **Ajustes**.
- Fonte, objetos, regras, agenda e automações continuam disponíveis, mas ficam recolhidos em **Preparar monitoramento**, evitando poluição visual sem remover funcionalidades.
- A navegação principal agora tem cinco destinos: **Início**, **Histórico**, **Ao vivo**, **Câmeras** e **Ajustes**; em paisagem/tablet continua migrando para `NavigationRail`.
- Nenhum asset foi criado a partir do mockup; a imagem fornecida foi usada apenas como direção visual.

### Evolução 1.0.112 — Próximos pontos e mapa expandido

- O botão **Mapa** abre diretamente **Próximos pontos**, com filtros rápidos, distância, categoria, origem Online/Offline e atualização sem misturar configurações.
- A engrenagem abre **Configurações do mapa e percurso**, reaproveitando `RouteExplorerService`, mapas offline, alertas, fala/notificação e preferência do mini mapa.
- O botão **Câmera** oferece **Ligada**, **Desligada** e **Mapa**; no modo Mapa a área principal da transmissão é ocupada pelo mapa expandido.
- Retrato e paisagem mantêm as cinco ações fixas: Câmera, Mapa, Áudio, Painel e Ajustes.

### Evolução 1.0.111 — mapa e percurso com pontos úteis

- o botão **Mapa** do monitor agora abre o painel **Mapa e percurso**, em vez de apenas alternar o mini mapa diretamente;
- dentro do painel é possível ajustar o raio da busca e filtrar categorias como **postos, restaurantes, paradas, oficinas, saúde, água/banheiro e rios/pontes**;
- o app consulta pontos úteis próximos via OpenStreetMap/Overpass quando houver internet e exibe a listagem no próprio pop-up;
- a lista atual pode ser salva para **uso offline**, servindo de fallback quando a conexão falhar;
- foi adicionada uma área de **alertas no percurso** com fala e/ou notificação para avisar sobre locais importantes se aproximando;
- o painel também concentra o controle do mini mapa e o atalho para **Mapas offline** e **Abrir mapa completo**.

### Evolução 1.0.110 — quinto botão de mapa + correção Android-APK-78

- a fileira fixa do monitor passa de quatro para cinco ações: **Câmera, Mapa, Áudio, Painel e Ajustes**;
- **Mapa** alterna diretamente entre mostrar e ocultar o mini mapa, usando a mesma preferência persistida já existente;
- o botão fica destacado quando o mapa está visível e continua funcionando fora do modo Bike;
- restaurado `.gitignore` com bloqueio de `*.jks`, `*.keystore` e `android/key.properties`;
- o ZIP final passa obrigatoriamente por `tool/package_source.sh`, que inclui arquivos ocultos necessários e falha se `.gitignore` estiver ausente.

### Evolução 1.0.109 — atalho global do mapa no monitor

- o menu dos três pontinhos do monitor agora mostra **Mostrar mapa** quando o mini mapa está oculto e **Ocultar mapa** quando ele está visível;
- ao escolher **Mostrar mapa**, o app força o modo **Sempre** e exibe o mapa mesmo fora do modo Bike;
- ao escolher **Ocultar mapa**, o app força o modo **Ocultar** e libera mais espaço para a câmera;
- quando o mapa estiver forçado ou ocultado, o mesmo menu oferece **Mapa automático** para restaurar a lógica anterior baseada em Bike, rota ativa ou movimento recente;
- a preferência continua persistida em `MapRouteService`, então o estado escolhido é lembrado ao reabrir o monitor.

### Correção 1.0.108 — Android-APK-76

- restaurados `@mipmap/ic_launcher`, `@style/LaunchTheme` e `@style/NormalTheme` no projeto Android versionado;
- adicionados `launch_background`, temas claro/escuro e launcher adaptativo compatível com o `minSdk 29`;
- o workflow só considera o projeto Android íntegro quando os recursos-base também existem, evitando pular o bootstrap com uma árvore incompleta;
- `verify_project.sh` agora falha imediatamente se os recursos referenciados pelo Manifest forem removidos;
- preservados a compilação única, universal + três ABIs, Build Cache e paralelismo introduzidos na 1.0.106.

### Correção 1.0.107 — Android-APK-75

- removido `id("kotlin-android")` explícito de `android/app/build.gradle.kts`, conforme o template do Flutter 3.44.9;
- `android { kotlinOptions { ... } }` legado foi substituído por `kotlin { compilerOptions { ... } }`;
- preservados `VIGIAIA_CI_MULTI_APK=1`, universal + três ABIs, Build Cache e paralelismo;
- o verificador preventivo agora bloqueia a reintrodução do DSL Kotlin que derrubou o Android-APK-75.

### Otimização 1.0.106 — Android-APK-74

- removida a segunda compilação release; `:app:assembleRelease` produz universal, `armeabi-v7a`, `arm64-v8a` e `x86_64` de uma só vez;
- `org.gradle.caching=true` e `org.gradle.parallel=true` ativados;
- `gradle/actions/setup-gradle@v6` substitui v4, instala Gradle 9.1.0 e evita depender de `gradlew` ausente no ZIP;
- o diretório `android/` versionado é reutilizado e o bootstrap fica apenas como recuperação;
- nomes finais são derivados do `output-metadata.json`, com falha explícita se qualquer um dos quatro APKs não for produzido;
- baseline de comparação: Android-APK-74 levou cerca de 10m16s, sendo aproximadamente 7m30s na etapa de build.

#### Estado anterior preservado — 1.0.105

A `1.0.105+105` corrige o bloqueio do `flutter analyze` encontrado no Android-APK-73 sem alterar o comportamento funcional do mapa ou das câmeras.

### Correção 1.0.105 — Android-APK-73

- removido o import redundante `dart:typed_data` de `map_monitoring_screen.dart`;
- removido o import não utilizado `package:camera/camera.dart` de `local_camera_source.dart`;
- o verificador preventivo passa a bloquear a reintrodução exata desses dois imports enquanto permanecerem desnecessários;
- versionamento, metadados, Mudanças, documentação, testes e verificadores foram sincronizados em `1.0.105+105`.

#### Estado anterior preservado — 1.0.104

A `1.0.104+104` melhora a configuração da Stadia Maps, os controles de seleção offline e a experiência do mapa completo com telemetria compacta e até duas câmeras flutuantes.

### Evolução 1.0.104 — Painel Stadia, seleção offline e câmeras no mapa

- **Configurar fonte** virou um painel completo: identifica se há chave salva, mostra versão mascarada, permite **Colar**, **Ver**, **Copiar**, **Testar**, **Trocar** e **Remover**;
- o teste da chave faz uma requisição mínima, informa sucesso/erro e latência e avisa quando aproximadamente 1 crédito foi consumido;
- a seleção visual de região offline ganhou modos **Mapa / Área** e controles inferiores explícitos **− / z / +**, evitando depender apenas de gestos;
- no mapa completo, velocidade, distância, tempo, altitude, rumo e **Seguindo / Mapa livre** foram movidos para chips compactos no topo;
- a parte inferior do mapa mantém somente a ação principal **Iniciar rota / Encerrar rota**; pausar/continuar e exportar GPX ficam no menu de ações da rota;
- a câmera principal pode ser mostrada/ocultada e o PiP muda de formato conforme a proporção da transmissão detectada;
- quando houver segunda câmera, ela também é enviada ao mapa completo, aparece inicialmente abaixo da principal e pode ser arrastada de forma independente;
- removido o rodapé textual **Local** do PiP para liberar imagem e reduzir poluição visual.


### Evolução 1.0.103 — Créditos de mapas e buildfix Android-APK-71

- corrigido `unnecessary_non_null_assertion` no planejador de mapas offline que fazia o `flutter analyze` do Android-APK-71 encerrar com código 1;
- cada planejamento direto exibe **Créditos estimados** junto de tiles, tamanho e espaço de cache;
- para tiles raster padrão da Stadia Maps, o Vigia IA usa a relação atual de **1 tile = 1 crédito**;
- contador mensal local persiste o consumo dos downloads diretos concluídos por este aparelho e reinicia automaticamente quando muda o mês;
- limite local mensal configurável, com padrão conservador de **150 mil créditos** e atalhos de 50 mil, 100 mil, 150 mil e 200 mil;
- downloads que ultrapassariam o saldo local são bloqueados antes de iniciar e há aviso ao passar de 80% do limite;
- o app deixa explícito que esse contador **não lê a conta Stadia** nem inclui consumo de outros aparelhos, apps ou serviços;
- o mapa online atual continua usando sua camada online existente e não consome a chave Stadia configurada para os downloads diretos.


### Evolução 1.0.102 — Ajuda para configurar a API de mapas

- o diálogo **Configurar fonte** ganhou o atalho **Como conseguir a chave?** com passo a passo dentro do próprio Vigia IA;
- a ajuda explica onde entrar no painel da Stadia Maps, como acessar **Manage Properties** e **Authentication Configuration**, gerar a API key e voltar ao app para colá-la;
- botão **Abrir painel** abre diretamente `https://client.stadiamaps.com/dashboard/`;
- botão **Instruções oficiais** abre a seção oficial de API keys da documentação da Stadia Maps;
- caso o Android não consiga abrir o navegador, o link é copiado automaticamente para a área de transferência;
- a credencial continua protegida pelo Android Keystore e não é gravada em texto puro pelo Vigia IA.


### Evolução 1.0.101 — Limite offline inteligente e mapa de navegação

- raio, margem do trajeto e zoom agora se ajustam entre si para permanecer dentro do espaço seguro restante do cache direto;
- **Ajustar ao limite disponível** encontra automaticamente a maior configuração válida, deixando explícitos o limite de 100 MB e a reserva técnica de 5 MB;
- a seleção de região ganhou um quadro arrastável e redimensionável sobre o mapa, em vez de depender de toda a viewport;
- o mapa completo passa a mostrar altitude, rumo, precisão do GPS e estado **Seguindo / Mapa livre** em um painel compacto;
- o marcador de posição usa a direção do GPS quando disponível, facilitando leitura do sentido de deslocamento.

### Evolução 1.0.100 — Correção do Android-APK-68

- corrigidas duas ocorrências de `invalid_use_of_protected_member` no módulo MBTiles do mini-mapa, reutilizando o refresh seguro do próprio `State`;
- o stream de localização passa a usar atribuição condicional (`??=`), eliminando `prefer_conditional_assignment`;
- removido o `!` redundante na comparação de expiração de pacotes offline, eliminando `unnecessary_non_null_assertion`;
- nenhuma funcionalidade de mapa offline, rota, GPX, câmera ou IA foi alterada nesta correção.

### Evolução 1.0.99 — Download offline direto, pausa de rota e GPX

- **Mapas offline** agora pode baixar diretamente uma região retangular ou um corredor ao redor do trajeto usando a fonte Stadia Maps configurada pelo usuário, sem usar prefetch do servidor público do OpenStreetMap;
- a chave da fonte é protegida pelo Android Keystore por meio da ponte nativa já existente e não é gravada em texto puro no manifesto;
- antes do download, o app calcula tiles e tamanho aproximado, compara com espaço livre e aplica margem de segurança ao limite total do cache direto no aparelho;
- o download mostra porcentagem, tiles concluídos e bytes, pode ser pausado/continuado ou cancelado e grava o resultado como MBTiles raster validado;
- pacotes baixados registram limites geográficos, zoom e validade estimada do cache, permitindo avisar quando a posição sair da área offline ou quando a atualização for recomendada;
- importação de `.mbtiles` e download de pacote pronto por link direto continuam disponíveis;
- a rota compartilhada agora pode ser **Pausada/Continuada**; ao retomar, um novo segmento evita somar um salto artificial entre o ponto de pausa e o novo ponto;
- a tela completa exporta o percurso em **GPX 1.1**, preservando segmentos, coordenadas, altitude e horário quando disponíveis.

### Evolução 1.0.98 — Mapa adaptativo, rota persistente e offline ampliado

- o mini-mapa do Monitor ganhou **Automático**, **Sempre mostrar** e **Ocultar**; no automático, monitoramento doméstico sem Bike/rota/movimento libera o espaço para a câmera;
- uma rota ativa mantém o mapa visível até ser encerrada, e Bike conectada ou deslocamento recente pelo GPS também faz o mapa aparecer automaticamente;
- `MapRouteService` passa a ser a sessão única de GPS/trajeto para o Monitor e o mapa completo, eliminando duas rotas independentes;
- trajeto, início/fim, distância, modo de exibição e estado de rastreamento são persistidos em `map_route_state.json` e restaurados após reabrir o app;
- a tela completa mostra de forma compacta **Online**, **Offline** ou **Mapa local** e mantém o PiP da câmera principal arrastável;
- **Mapas offline** passa a importar `.mbtiles` do armazenamento do Android além de aceitar link direto;
- o gerenciador ganhou planejamento de **Região atual**, **Selecionar região** e **Trajeto**, com estimativa de tiles/tamanho e espaço livre antes de escolher/importar um pacote autorizado;
- o app continua sem fazer download em massa de `tile.openstreetmap.org`; download direto por área depende de uma fonte/servidor que autorize esse uso.

### Evolução 1.0.97 — Correção do workflow e sincronização de versão

- Corrige `test/app_metadata_test.dart`, que ainda esperava `1.0.95+95` apesar de o aplicativo já estar em `1.0.96+96`.
- `tool/check_version_sync.py` passa a validar também o teste de AppMetadata, impedindo que a mesma divergência volte a chegar ao workflow.
- Mantém integralmente mapas offline, câmera flutuante, IA e demais funções da 1.0.96.

### Evolução 1.0.96 — Mapas offline e câmera flutuante

- o mapa completo ganhou **Mapas offline**, com download de pacotes raster `.mbtiles` por link direto e armazenamento interno do aparelho;
- o gerenciador lista tamanho/origem, permite ativar e excluir pacotes e mostra progresso do download; arquivos são validados como MBTiles raster PNG/JPG/WebP antes da ativação;
- os modos **Automático**, **Online** e **Offline** permitem escolher como o mapa será carregado; no automático, o pacote local funciona como base/fallback e a internet atualiza tiles quando disponível, respeitando o zoom nativo do MBTiles;
- o servidor público `tile.openstreetmap.org` continua sendo usado apenas para visualização online normal, nunca para download em massa;
- ao abrir o mapa completo a partir do Monitor, a câmera principal aparece em uma janela PiP compacta;
- a janela da câmera pode ser arrastada por toda a área útil da tela para não cobrir o trajeto;
- abrir o mapa a partir do modo Bike continua funcionando sem PiP de câmera.

### Evolução 1.0.95 — Monitor mais denso e câmeras unificadas

- os cards de velocidade, temperatura, pneus e distância reduzem largura mínima, padding e ícones para mostrar mais telemetria na mesma linha;
- o mini-mapa cresce novamente e tocar na área do mapa abre a tela completa; **Abrir mapa** sai da barra fixa e dá lugar a **Câmera**;
- **Câmera** abre um hub único com fonte principal, escolha de uma ou duas câmeras, câmera local, frontal de teste, ESP32 e demais fontes cadastradas;
- o item **Uma ou duas câmeras** e **Status da sessão** deixam o menu de três pontos, e o botão de áudio do topo é removido por duplicar o atalho inferior;
- **Áudio**, **Painel** e **Ajustes** passam a usar contraste explícito de estado ativo, evitando aparência de botões desabilitados;
- os seis atalhos do painel do Monitor usam distribuição responsiva e ficam na mesma linha quando houver largura suficiente;
- duplo toque sobre a área das câmeras ativa a mesma tela inteira do botão superior;
- o selo sobre a câmera principal fica reduzido a **Local** quando a fonte é a câmera deste aparelho;
- o PiP da segunda câmera pode ser arrastado livremente dentro da área de vídeo, permanecendo longe de mapa e controles externos;
- as caixas verdes da IA foram analisadas: elas são apenas overlay visual e não interferem na detecção; nesta versão foram preservadas para manter referência de validação.

### Evolução 1.0.94 — Ajuste fino e teste de duas câmeras

- o mini-mapa vertical ficou mais alto, empurrando o resumo **Detectados** para baixo sem remover o acesso rápido às ações;
- **Abrir mapa**, **Áudio**, **Painel** e **Ajustes** ficam fixos na mesma linha, com botões mais baixos, bordas menores e espaçamento reduzido;
- a sobreposição inferior esquerda do mapa deixa de repetir distância/**Bike** e passa a usar a altitude real do GPS em formato compacto; a distância continua disponível na telemetria superior;
- os cards ESP32/Bike de velocidade, temperatura, pneus e distância ficaram menores para exibir mais dados na faixa horizontal;
- o seletor de segunda câmera ganhou **Teste: câmera frontal**, abrindo uma prévia local de baixa resolução em uma janela PiP sobre a câmera principal;
- a câmera principal continua sendo a única fonte da IA e dos alertas; a frontal é apenas visualização de teste;
- em aparelhos que não suportem câmera frontal e traseira simultâneas, a falha da frontal fica isolada e não deve derrubar a câmera principal.

### Evolução 1.0.93 — Monitor vertical mais compacto

- o bloco fixo **Detectados agora** foi substituído por um resumo compacto com quantidade e detecção principal;
- tocar no resumo abre as detecções em um painel inferior arrastável, com altura ajustável;
- o mini-mapa usa rótulos curtos (**Mapa**, **Ao vivo**, **Rota**, **Distância/Bike**) e controles menores;
- localização e zoom do mini-mapa ficam em uma linha compacta para evitar sobreposição;
- a faixa de telemetria da bike ficou mais baixa, liberando espaço para temperatura, pressão dos pneus, câmera e mapa.

### Evolução 1.0.92 — Orientação por modo

- telas normais do Vigia IA ficam limitadas a `portraitUp`/`portraitDown`;
- o modo Transmissão libera as quatro orientações e acompanha a posição física do celular sem forçar paisagem;
- ao sair da Transmissão, a política de retrato é restaurada antes de voltar à seleção de modo;
- a tela inteira do Monitor não força mais `landscapeLeft`/`landscapeRight` e mantém o monitor vertical;
- a rotação dos frames continua calculada por `sensorOrientation` + `deviceOrientation`, preservando o envio correto quando o transmissor está deitado.

### Evolução 1.0.91 — Correção do analyzer

- corrigido `separatorBuilder: (_, __)` para `separatorBuilder: (_, _)` em `monitor_screen_portrait.dart`;
- eliminado o aviso `unnecessary_underscores` que fazia `flutter analyze` retornar código 1 no Android-APK-59;
- nenhuma mudança funcional de orientação, mapa, câmera, IA ou transmissão foi aplicada nesta entrega.

### Evolução 1.0.90 — Tela vertical com mapa

- a tela vertical do monitor foi reorganizada para priorizar a imagem da câmera e se adaptar melhor quando a fonte remota estiver filmando em horizontal;
- o mapa do trajeto passa a aparecer também no modo retrato, com botão para abrir a rota completa, recentralização e zoom rápido;
- os atalhos avançados deixam de ocupar uma faixa fixa entre a câmera e as detecções e passam a ficar no botão **Painel**;
- o bloco **Detectados agora** continua visível, mas com altura ajustada para coexistir com o mapa e as novas ações.

### Evolução 1.0.89 — Correção do dashboard

- corrigidos quatro avisos `invalid_use_of_protected_member` do `flutter analyze` em `monitor_screen_landscape_dashboard.dart`;
- a extensão do dashboard deixa de chamar `setState` diretamente e passa a atualizar o estado pelo método seguro da própria `State`;
- preservados o novo visual Ao vivo, o mini-mapa, a telemetria, os alertas e as ações rápidas da 1.0.88.

### Evolução 1.0.88 — Dashboard ao vivo com mapa

- tela Ao vivo em paisagem redesenhada com cabeçalho, câmera em destaque, mapa do trajeto e barra de ações inferior;
- painel lateral antigo deixa de ser o foco na câmera única e as detecções passam a abrir em painel dedicado sob demanda;
- mini-mapa integrado ao monitor acompanha posição/rota quando a localização está disponível e aponta para a tela completa do mapa quando necessário;
- cards de velocidade, temperatura, pneus e distância ficam sempre visíveis junto da faixa de status da sessão.

### Evolução 1.0.87 — Correção de build do mapa

- corrigida a ordem da diretiva `part of` em `bike_mode_screen_components.dart`;
- eliminado o erro `directive_after_declaration` reportado pelo `flutter analyze`;
- mantida intacta a implementação do mapa/GPS introduzida na 1.0.86.

### Evolução 1.0.86 — Mapa e GPS no Modo Bike

- nova tela `Mapa do monitoramento` acessível diretamente pelo Modo Bike;
- mapa online baseado em OpenStreetMap via `flutter_map`, sem chave de API;
- localização pelo GPS do Android com `geolocator`, solicitada apenas quando o mapa é aberto;
- exibição de posição atual, precisão, velocidade, horário da última atualização e centralização;
- início e encerramento de rota com linha do trajeto, marcadores de início/fim, distância e cronômetro;
- tratamento dedicado para GPS desligado, permissão negada e permissão bloqueada permanentemente;
- esta etapa mantém o trajeto apenas durante a sessão; histórico geográfico, eventos da IA e mapa offline ficam para as próximas etapas.

### Evolução 1.0.85 — Telemetria e diagnóstico mais compactos

- a faixa de telemetria do ESP32/Bike deixa de quebrar em grade e passa a priorizar uma única linha horizontal rolável;
- velocidade, temperatura, pneus, sensores/simulação e distância ficam em mini-cards horizontais, liberando mais altura para a câmera;
- em Diagnóstico, os estados Serviço, Câmera, Frames, IA, LAN, clientes, Permissões e 2º plano passam a ficar em uma faixa horizontal compacta;
- em Desempenho da sessão, os botões `Diagnóstico 30 s`, `Diagnóstico 60 s` e `Exportar` ficam juntos na mesma linha horizontal, com rolagem lateral quando necessário.

### Evolução 1.0.84 — Correção de build

- Corrigidos três `invalid_constant` nos rótulos responsivos da Central de Câmeras.
- Removido o parâmetro interno não utilizado em Configurações.

### Evolução 1.0.83 — Fontes, modos e organização

- o cadastro manual passa a diferenciar explicitamente celular transmissor e câmera RTSP antes dos campos de conexão;
- a Central de Câmeras organiza QR, celular, RTSP e ESP32 em uma grade compacta; fontes remotas mostram modelo, resolução transmitida, FPS e bateria quando informados;
- os filtros de Histórico ficam em uma única linha em telas usuais, com altura menor e rótulo curto para carros;
- Normal, Monitor, Bike e Transmissão oferecem acesso direto à seleção `Alterar modo`, sem limpar dados; o Monitor ativo também traz essa opção no menu;
- Configurações agrupa preferências, monitoramento, sistema e diagnóstico; Sobre permanece como último grupo;
- a tela Mudanças mostra somente as cinco versões mais recentes.

### Evolução 1.0.82 — APKs diretos por arquitetura

- cada execução gera `VigiaIA-v1.0.82+82-universal.apk` e também APKs individuais para `arm64-v8a`, `armeabi-v7a` e `x86_64`;
- os APKs são anexados à GitHub Release e podem ser baixados diretamente, sem a camada ZIP dos artifacts;
- relatórios de tamanho e dependências ficam em um artifact técnico separado;
- o APK universal continua disponível para quem não quiser escolher arquitetura;
- `x86_64` é preservado para emuladores e dispositivos compatíveis.

### Evolução 1.0.81 — Monitor vertical fixo

- status do receptor e da fonte fica em uma faixa própria no topo;
- atalhos de Ao vivo, IA ativa, Painel e Ajustes ficam alinhados antes da câmera;
- a câmera passa a usar um cartão delimitado e mantém sua altura quando surgem detecções;
- ações de Áreas, Objetos, Regras, Fonte, segunda câmera e Recursos ficam logo abaixo da imagem;
- `Detectados agora` deixa de ser um painel expansível sobreposto e passa a ter área fixa com rolagem interna;
- quando a fonte é a câmera deste aparelho, somente o Receptor mostra bateria; fontes remotas continuam mostrando a bateria do transmissor;
- corrigido o lint `use_build_context_synchronously` encontrado no Android-APK-49.

### Evolução 1.0.80 — Histórico, ESP32, câmeras e APK

- filtros de Tudo, Pessoas, Automóveis e Animais ficam na mesma linha quando houver largura e usam ícones de identificação;
- cards do Histórico agrupam câmera, horário e entrada/saída de modo compacto; o detalhe permite salvar a mídia ou excluir com confirmação;
- Configurações > Monitoramento ganhou painel próprio para ESP32, com conexão, chave, teste, sensores Hall/temperatura/pneus, calibração, intervalo e envio de configuração ao módulo;
- módulos com câmera habilitada aparecem como fonte ESP32 na Home, no seletor do Monitor e na página Câmeras;
- o Monitor deixa explícita a ação `2ª câmera`; somente a fonte principal executa IA, histórico, alertas e áudio;
- a página Câmeras identifica Local, RTSP, Celular remoto e ESP32, com ações de monitorar, combinar duas fontes e gerenciar o módulo;
- o workflow nomeia o arquivo como `VigiaIA-v1.0.80.apk`, usa cache de Gradle/modelos e evita recomprimir o APK durante o upload;
- cada build gera `apk-size-report.txt`, `flutter-dependencies.txt` e `gradle-release-dependencies.txt`, detalhando os maiores arquivos internos e as árvores de dependências para localizar o peso real sem remover recursos necessários.

### Evolução 1.0.79 — Buildfix e navegação essencial

- corrige os oito usos protegidos de `setState` nos módulos multicâmera extraídos;
- qualifica o intervalo estático da Central multicâmera, eliminando o erro restante do Android-APK-47;
- o menu inferior e a barra lateral ficam apenas com Início, Histórico, Monitor e Câmeras;
- Modo Bike continua disponível na seleção inicial e passa a ter acesso direto em Configurações > Monitoramento;
- a tela Bike deixa de exibir um quinto destino sem função e ganha atalho claro para Configurações;
- o teste da navegação protege os quatro destinos e confirma que Bike não reaparece no menu principal.

### Evolução 1.0.78 — Câmeras adaptativas e sensores Bike

- a mesma tela do Monitor usa uma câmera em toda a área de vídeo ou duas câmeras empilhadas no retrato e lado a lado na paisagem;
- a câmera principal continua responsável por IA, histórico, alertas, clipes e áudios; a segunda câmera usa uma visualização leve para preservar desempenho;
- a Central multicâmera e o menu do Monitor permitem abrir ou remover a segunda câmera sem criar uma tela paralela;
- velocidade do sensor Hall, temperatura, pressão dianteira/traseira, bateria dos sensores e distância ficam em uma faixa compacta no topo;
- o contrato de telemetria aceita dados ESP32 e envia esses sensores, junto da bateria do transmissor, pelo endpoint de status local;
- o Android deixa de pedir câmera antes da explicação: Acesso inicial → permissões → escolha de modo → modo escolhido;
- permissões obrigatórias removidas depois geram orientação curta, sem refazer o onboarding;
- o botão Voltar e o gesto Voltar do Modo Transmissão encerram a transmissão com confirmação e retornam à seleção de modo.
- o transmissor mostra se há receptor conectado e deixa explícito que envia imagem, bateria e telemetria, sem executar a IA do receptor.

### Evolução 1.0.77 — Recursos de áudio compilados

- os 78 áudios integrados usam um catálogo Android com referências diretas `R.raw`, sem reflexão nem busca dinâmica por nome;
- o erro `resource_id_zero` identificado no diagnóstico deixa de depender de resolução em tempo de execução;
- o diagnóstico informa quantos recursos integrados foram empacotados e lista qualquer ID inválido;
- o verificador compara os slots Dart, o catálogo Kotlin e os arquivos M4A antes da entrega;
- o fallback TTS permanece ativo para falhas reais de reprodução.

### Evolução 1.0.76 — Monitor explícito e fluxo entre celulares

- a seleção inicial agora mostra Modo Normal, Modo Monitor, Modo Bike e Modo Transmissão;
- Modo Normal explica que este celular usa a própria câmera e analisa localmente;
- Modo Transmissão explica que este celular envia imagem/status pela rede local;
- Modo Monitor abre um fluxo próprio para receber imagem de outro aparelho por QR, endereço/chave manual ou Central multicâmera;
- ao conectar no Modo Monitor, a fonte do Monitor vira `Celular remoto` e a IA, histórico, alertas e áudios ficam no receptor;
- Configurações > Monitoramento > Modo inicial permite trocar e salvar também o novo modo Monitor.

### Evolução 1.0.75 — Áudio diagnosticável e build corrigido

- remove o `!` desnecessário que fez o `flutter analyze` encerrar o workflow antes dos testes e do APK;
- negação de foco de áudio não é mais tratada como falha fatal: o player tenta reproduzir e registra o resultado;
- registra código nativo, etapa, fonte, arquivo, tamanho, volume, saída, foco e latências de cada tentativa;
- converte os códigos `MediaPlayer what/extra` para nomes úteis no relatório;
- falhas ficam persistidas na Central de Diagnóstico e são correlacionadas com o fallback para TTS;
- o teste manual em Configurações > Áudios e voz mostra o erro e a etapa encontrados;
- relatórios de desempenho usam o esquema 3 e incluem resumo legível mais o diagnóstico Android completo.

### Evolução 1.0.74 — Paisagem limpa e saída clara

- Monitor em paisagem não reserva AppBar fixa: os controles ficam sobre a transmissão em um HUD translúcido;
- tela cheia ganhou ação explícita para sair do monitoramento, além de sair da tela cheia;
- pressão, velocidade, status dos aparelhos, IA, detecções, voz e preenchimento ficam agrupados no topo em paisagem;
- o preview preenche automaticamente em paisagem/tela cheia para reduzir faixas pretas;
- Modo Câmera ganhou estado parado integrado ao visual do app, em vez do ícone isolado de câmera desligada;
- Modo Câmera usa barra superior translúcida com saída clara e botão Parar quando está transmitindo;
- em paisagem, o painel do Modo Câmera vira lateral para aproveitar melhor a imagem;
- permissões continuam aparecendo antes da seleção de modo, e a troca de modo segue acessível pelas configurações.

### Evolução 1.0.73 — Escolha inicial de modo

- após o acesso inicial/permissões, o app pergunta se este aparelho será usado em Modo normal, Modo Bike ou Modo transmissão;
- a escolha fica salva em `launch_mode.json` e define a primeira tela em próximas aberturas;
- Configurações > Monitoramento ganhou o item Modo inicial para trocar a decisão depois;
- Modo normal abre a Home, Modo Bike abre o painel Bike e Modo transmissão abre o Modo Câmera;
- o Modo transmissão segue leve e dedicado à câmera; mapa/GPS e futuras melhorias da Bike ficam no aparelho receptor/visualizador.

### Evolução 1.0.72 — Buildfix e direção do mini mapa

- remove o operador nulo desnecessário no status da câmera remota;
- remove import redundante no teste da câmera remota;
- mantém a mudança funcional da 1.0.71 sem alterar o protocolo de vídeo;
- define como decisão de produto que um futuro mini mapa/GPS deve ficar no aparelho receptor/visualizador; o transmissor deve continuar dedicado à câmera, enviando localização apenas como telemetria leve se esse recurso for implementado depois.

### Evolução 1.0.71 — Vídeo remoto e HUD

- consulta quadros remotos a cada 250–400 ms, independentemente do intervalo da análise;
- usa sequência, timestamp UTC e respostas sem cache para descartar quadros repetidos antes da decodificação e da IA;
- mostra uma faixa permanente e tocável para receptor e transmissor, com bateria, carregamento, conexão e latência disponível, inclusive no perfil econômico;
- adapta a mesma faixa ao retrato, paisagem e tela inteira, preservando a câmera como conteúdo principal;
- resolve o recurso de áudio pelo identificador Android compilado e amplia o diagnóstico de falha dos áudios integrados.

### Evolução 1.0.70 — Empacotamento seguro

- inclui o `.gitignore` no ZIP final;
- bloqueia `*.jks`, `*.keystore` e `android/key.properties`;
- mantém a checagem que impede qualquer keystore de ser incluída no projeto;
- não altera o comportamento funcional da IA, áudio, alertas ou tela inteira.

### Evolução 1.0.69 — Buildfix do serviço de fala

- corrige o lint `use_null_aware_elements` em `speech_service.dart`;
- usa elemento de mapa null-aware para incluir `error` somente quando houver valor;
- preserva o comportamento funcional de TTS, áudio, detecção, alertas e tela inteira;
- mantém a `1.0.68` no histórico como a correção dos erros de compilação anteriores.

### Evolução 1.0.68 — Correção de build da IA

- corrige null-safety no worker de detecção durante a troca automática de modelo;
- corrige a janela de observação das Regras Inteligentes;
- remove avisos do analisador encontrados na entrega anterior;
- preserva integralmente as melhorias funcionais da 1.0.67.

### Evolução 1.0.67 — Detecção, áudio e tela inteira

- conversão YUV/BGRA gera RGB já girado/espelhado, sem criar e girar uma imagem intermediária;
- resize, letterbox e normalização escrevem em um tensor plano reutilizável; saídas do detector também são reutilizadas;
- XNNPACK é solicitado com duas threads e há fallback CPU na inicialização; após o aquecimento, três execuções seguidas acima de 1.200 ms solicitam SSD MobileNet V1 na próxima análise;
- confirmação e permanência acompanham a cadência observada. Evidências fortes passam direto pela confirmação genérica, mantendo regras de movimento, área e permanência;
- todas as inferências auxiliares respeitam o orçamento; sem cliente LAN, o JPEG de boas-vindas é atualizado a cada dois segundos;
- áudios usam **volume de mídia**, preparação assíncrona, foco de áudio, prioridade e fila curta. Falhas assíncronas chegam ao fallback de TTS;
- o botão **Tela inteira horizontal** aparece em Ao vivo. A imagem preenche a tela inicialmente; **Ajustar** mostra a imagem completa e **Preencher** corta proporcionalmente as bordas. Toque para revelar controles; **Voltar** sai da tela inteira;
- troca de orientação não reinicia a câmera. O preview é removido antes de descartar seu controller;
- em **Mais opções → Status da sessão**, confira os tempos. Em **Configurações → Diagnóstico**, exporte os relatórios com eventos de áudio, decisão das regras e modelo usado;
- quadros acima de 1,5 s não alimentam a aproximação urgente Bike; acima de 5 s não geram novos alertas falados e a tela informa o atraso.

Detalhes da entrega atual: [RELEASE-1.0.81.md](RELEASE-1.0.81.md). ESP32 e fontes: [RELEASE-1.0.80.md](RELEASE-1.0.80.md). Layout e sensores: [RELEASE-1.0.78.md](RELEASE-1.0.78.md) e [VALIDATION.md](VALIDATION.md).

### Evolução 1.0.66 — Buildfix dos testes

- `flutter analyze` passou sem problemas no Android-APK-34; a falha ficou restrita a um único teste de `SessionStatus`;
- o teste agora espera `Inferências auxiliares` como hotspot no cenário granular, pois `primaryInferenceMs` representa round-trip agregado e não entra na comparação de etapas locais;
- nenhuma lógica do pipeline, IA, telemetria, relatórios, onboarding ou interface foi alterada;
- verificadores passam a proteger a expectativa atual do hotspot granular.



### Evolução 1.0.65 — Buildfix do analyze

- removido o import redundante `dart:typed_data` de `NativePlatformService`;
- teste de exportação de diagnóstico passa a tratar explicitamente o retorno anulável antes de abrir o arquivo;
- nenhuma mudança funcional em telemetria, relatórios, Downloads, onboarding, IA ou layouts;
- verificadores passam a impedir a regressão dos dois problemas encontrados pelo Android-APK-33.


### Evolução 1.0.64 — Telemetria e interface adaptativa

- o pipeline registra conversão/decodificação da fonte, fila/transferência do isolate, materialização, criação da imagem, resize/letterbox, montagem do tensor, LiteRT/TFLite puro, pós-processamentos, total e fim a fim;
- o Diagnóstico oferece captura profunda de 30 ou 60 segundos e exporta `resumo.txt`, `telemetria.json` e `telemetria.csv` dentro de um ZIP;
- o relatório inclui percentis P50/P90/P95/P99, aparelho/Android, FPS, descartes, CPU, RAM, temperatura, bateria, rede e ocorrências importantes;
- diagnósticos usam `Downloads/Vigia IA` por padrão ou o seletor nativo quando `Perguntar sempre` é escolhido em Configurações;
- o acesso inicial deixa de ser a `home` permanente e passa a aparecer somente na primeira instalação, com revisão manual disponível em Configurações;
- os três chips do acesso inicial permanecem na mesma linha;
- paisagem/tablet recebe ações multicâmera em linha, Alertas e clipes em duas colunas, Histórico com filtros 2×2 e Status da sessão em painel lateral com detalhes no mesmo painel;
- o gargalo de IA deixa de tratar todo o round-trip como tempo do modelo: LiteRT e preparação são avaliados separadamente.


### Evolução 1.0.63 — Buildfix do analyze

- removidos 19 qualificadores `this.` desnecessários do `MonitorController`, reportados pelo `flutter analyze` do Android-APK-31;
- os métodos e getters continuam apontando para as mesmas implementações `*Impl` dos módulos internos;
- nenhuma regra de IA, Monitor, Bike, TTC, telemetria ou interface foi alterada;
- o verificador passa a impedir a reintrodução desses qualificadores nos wrappers internos.


### Evolução 1.0.62 — Buildfix do workflow

- `bootstrap_android.sh`, `fetch_model.sh` e `verify_project.sh` passam a ser chamados explicitamente via `bash` no GitHub Actions;
- o build deixa de depender da permissão executável preservada pelo ZIP ou pela importação no GitHub Manager;
- o erro `Permission denied` / exit code 126 do `Android-APK-30` é corrigido na origem;
- nenhuma API, tela, regra de IA, TTC, Bike, áudio ou monitoramento foi alterada.


### Evolução 1.0.61 — Buildfix pós-refatoração

- removidos `_refreshSessionTelemetry`, `_deliverAlert` e `_zonesDiagnosticContext` do arquivo principal porque nenhum chamador ainda usava essas fachadas;
- telemetria, alertas/TTC e diagnóstico de áreas continuam executados pelos métodos `*Impl` dos módulos internos;
- nenhuma API pública, fluxo do Monitor, Modo Bike, IA, áudio ou diagnóstico foi alterado;
- a correção responde diretamente aos três `unused_element` encontrados pelo Flutter 3.44.9 no workflow da 1.0.60.



### Evolução 1.0.60 — Refatoração estrutural, lote 4

- `session_status.dart`, `system_health_screen.dart` e `object_detection_service.dart` foram divididos em arquivos principais menores e módulos `part` internos.
- Status da sessão preserva modelos, enums, snapshots e getters públicos no arquivo principal; a análise de saúde fica isolada em `session_status_health_analyzer.dart`.
- Saúde do sistema preserva timer, coleta, atualização, persistência e ações na tela principal; componentes visuais ficam em `system_health_screen_components.dart`.
- Detector preserva `ObjectDetectionService`, sua API pública e o ciclo de vida do isolate; runtime do worker, transformações e inferência ficam em `object_detection_worker.dart`.
- Com este lote, os quatro grupos de três totalizam 12 arquivos refatorados preventivamente.
- Verificadores acompanham a nova estrutura e limitam o crescimento dos arquivos principais.
- Nenhuma métrica, diagnóstico, detector ou comportamento de IA foi removido.


### Evolução 1.0.59 — Refatoração estrutural, lote 3

- `session_status_panel.dart`, `error_center_screen.dart` e `events_screen.dart` foram divididos em arquivos principais menores e módulos `part` para componentes visuais.
- Status da sessão mantém os dois painéis públicos e move cards, métricas, badges e helpers visuais para `session_status_panel_components.dart`.
- Central de diagnóstico mantém carregamento, atualização, exportação, compartilhamento e filtros no arquivo principal; resumo, grid, chips e cards de erro ficam em `error_center_screen_components.dart`.
- Histórico mantém persistência, filtros, navegação e ações no arquivo principal; cards, thumbnails, estados vazios/erro e reprodução local ficam em `events_screen_components.dart`.
- Verificadores foram adaptados para procurar recursos na nova estrutura e ganharam limites preventivos para os três arquivos principais.
- Nenhuma função, filtro, reprodução, diagnóstico ou métrica de sessão foi removida.


### Evolução 1.0.58 — Refatoração estrutural, lote 2

- `multi_camera_screen.dart`, `app_info_screen.dart` e `bike_mode_screen.dart` foram divididos em arquivos principais focados em estado/navegação e módulos `part` para componentes visuais.
- A Central multicâmera preserva cadastro, edição, leitura QR, probe, atualização automática e navegação, mas seus cards/cabeçalho/métricas ficam isolados em `multi_camera_screen_components.dart`.
- A tela Informações mantém seleção de seção e ação de copiar PIX no arquivo principal; painéis Sobre/Mudanças/Doações e cards auxiliares ficam em `app_info_screen_components.dart`.
- O Modo Bike mantém carregamento, persistência, telemetria e navegação no arquivo principal; hero, telemetria e cards auxiliares ficam em `bike_mode_screen_components.dart`.
- Verificadores foram adaptados à nova estrutura e ganharam limites preventivos para evitar que os três arquivos principais voltem a crescer sem revisão.
- Nenhuma função, rota, texto, configuração do Bike ou comportamento da Central foi removido.

## Evolução 1.0.57

- primeiro lote da refatoração: `monitor_controller.dart`, `monitor_screen.dart` e `home_screen.dart`;
- telemetria/saúde, eventos/alertas/TTC e estado/diagnóstico agora vivem em módulos internos separados do `MonitorController`;
- componentes auxiliares do Monitor e da Home foram extraídos para arquivos próprios, mantendo a mesma interface e comportamento;
- os três arquivos principais caíram de 2.379/1.808/1.199 linhas para aproximadamente 1.744/1.332/800 linhas;
- o verificador preventivo reconhece a nova divisão e impede que os três arquivos voltem imediatamente aos tamanhos anteriores;
- esta é uma refatoração estrutural: detecção, TTC, Modo Bike, HUD, alertas, histórico, fontes e áudio continuam funcionando pelo mesmo contrato.

### Evolução 1.0.56

- novo `BikeApproachEstimator` acompanha automóveis pela posição e crescimento da caixa da inferência principal, sem fingir medir metros ou velocidade física;
- o caminho rápido roda imediatamente após a inferência principal e antes de detail scans, histórico, gravação e regras normais de alerta;
- o Modo Bike pode incluir automóveis apenas para essa proteção mesmo quando o filtro normal de objetos não os seleciona;
- o HUD sobre o vídeo mostra observação, aviso e aproximação crítica, com TTC aproximado e indicação explícita quando o dado é simulado;
- alertas fortes usam prioridade alta de voz/notificação e têm cooldown por veículo, permitindo escalada imediata de aviso para crítico sem repetir a cada frame;
- `BikeModeScreen` ganhou chave para ativar o alerta e ajuste de antecedência entre 2,5 e 7 segundos;
- o simulador ganhou o cenário `Veículo se aproximando`, permitindo testar HUD, TTC e áudio em casa sem ESP32;
- ESP32 e radar FMCW continuam fora desta etapa; o TTC atual é apenas estimativa visual da câmera.

### Evolução 1.0.55

- `AdaptiveMainScaffold` troca automaticamente a barra inferior por `NavigationRail` em celular paisagem e tablet, recuperando altura útil sem criar um modo manual.
- `HomeScreen` remove o botão flutuante que cobria conteúdo, integra a ação de iniciar ao fluxo da tela e usa duas colunas em largura suficiente.
- A seleção de fonte usa rótulos compactos `Local / RTSP / Remoto`, evitando quebra de `Dispositivo` em telas estreitas.
- `BikeModeScreen` organiza perfil/telemetria e celular traseiro/simulador em duas colunas quando há espaço; o HUD reduz altura automaticamente em paisagem baixa.
- `MonitorScreen` usa painel lateral recolhível em celular deitado e permanente apenas em tablets amplos.
- `Ajustar / Preencher` altera o vídeo e a geometria de `DetectionOverlay` e `MonitoringZoneOverlay` em conjunto, preservando alinhamento após crop.
- `SessionStatusPanel` usa duas colunas em telas largas e abre em diálogo amplo no Monitor quando o espaço permite.
- `EventsScreen` move filtros para uma coluna lateral em telas largas; `SettingsScreen` distribui categorias em duas colunas.
- Os dois `!` desnecessários apontados pelo Flutter 3.44.9 foram removidos do HUD do Monitor.

### Evolução 1.0.54

- HUD transparente no Monitor quando existe uma fonte de sensores disponível; o simulador pode ser testado sem ativar o perfil energético do celular traseiro;
- velocidade em destaque no topo, pressão do pneu dianteiro e traseiro nas laterais e bateria dos sensores em faixa discreta;
- avisos ganham destaque temporário para pressão baixa, bateria de sensores baixa/crítica e perda de conexão;
- novo simulador interno, ativável em `Bike → Teste do HUD sem ESP32`, sem exigir placa ou sensores físicos;
- cenários manuais: normal, pneu dianteiro baixo, pneu traseiro baixo, bateria dos sensores baixa e sensores desconectados;
- o HUD mostra `SIMULAÇÃO` enquanto estiver usando dados falsos, evitando confusão com telemetria real;
- a camada `BikeSensorService` foi separada da UI para permitir substituir o simulador por uma fonte ESP32 futura sem redesenhar o HUD;
- corrigido o lint `use_null_aware_elements` em `session_status_panel.dart` apontado pelo workflow Android-APK-25;
- a integração real com ESP32 ainda não foi implementada.


### Evolução 1.0.53

- corrigida a falha “Não foi possível reproduzir este áudio” ao ouvir áudios padrão em aparelhos onde o `MediaPlayer` não conseguia preparar o M4A por URI `android.resource://`;
- o recurso padrão é lido diretamente de `res/raw`, copiado para o cache privado do Vigia IA e reproduzido por caminho de arquivo local;
- a cópia usa arquivo temporário e substituição controlada para não reutilizar cache parcial/corrompido;
- a prioridade continua `áudio personalizado → áudio padrão`; se um override personalizado estiver inválido, o padrão ainda é tentado;
- os 78 M4A padrão permanecem com os mesmos IDs e conteúdo, sem nova recompressão;
- Monitor, Status da sessão, pipeline da IA, Bike imersivo e ESP32 permanecem sem alterações funcionais.


### Evolução 1.0.52

- o painel detalhado passa a medir pré-processamento, inferência principal, inferências auxiliares, pós-processamento, processamento total e latência estimada da captura até o resultado;
- o Status da sessão mostra uso do orçamento de análise, folga restante e a etapa local que mais consumiu tempo no último frame analisado;
- o Monitor registra quantas execuções do detector foram necessárias no frame e quantas foram inferências auxiliares;
- a varredura opcional de detalhe agora consulta um orçamento antes de rodar e é pulada quando a projeção indica risco de ultrapassar o intervalo configurado;
- a inferência principal continua obrigatória para todo frame elegível; a proteção de orçamento atua somente no trabalho extra de detalhe;
- o painel contabiliza quantas varreduras opcionais foram evitadas pelo orçamento durante a sessão;
- a saúde da sessão passa a sinalizar quando o processamento completo se aproxima ou ultrapassa o intervalo disponível;
- fluxo imersivo do Bike e integração ESP32 continuam sem alterações.


### Evolução 1.0.51

- o Status da sessão passa a classificar a operação como `Saudável`, `Atenção`, `Instável` ou `Desconectado`;
- a análise considera idade do último frame, atraso ponta a ponta, latência de rede, FPS recebido em relação ao intervalo configurado, tempo de inferência e perdas por IA ocupada;
- o painel sugere o gargalo provável entre rede, captura de vídeo, processamento da IA e recursos do aparelho;
- frames descartados porque a IA ainda estava ocupada foram separados dos frames pulados intencionalmente pelo filtro de movimento, evitando falso diagnóstico de desempenho;
- o painel mantém as últimas ocorrências de saúde da sessão e registra a normalização quando o problema desaparece;
- o detalhe de vídeo mostra idade atual da imagem, meta aproximada de FPS, perdas reais por processamento e otimizações intencionais separadamente;
- os limites de atraso são adaptados ao intervalo efetivo configurado para a fonte, evitando exigir FPS incompatível com o próprio perfil da sessão;
- fluxo imersivo do Bike e integração ESP32 continuam sem alterações.

### Evolução 1.0.50

- removidas chaves desnecessárias em três interpolações de `lib/models/session_status.dart`;
- a correção elimina os avisos `unnecessary_brace_in_string_interps` que bloquearam o workflow da 1.0.49;
- painel Status da sessão, telemetria local/remota, Monitor e preparação para o Modo Bike permanecem inalterados funcionalmente;
- fluxo imersivo do Bike e integração ESP32 continuam sem alterações.

### Evolução 1.0.49

- novo painel reutilizável `Status da sessão`, acessível pelo Monitor normal e estruturado para ser reaproveitado futuramente pelo Modo Bike;
- resumo compacto de vídeo mostra o essencial e abre um painel próprio com fonte da imagem, aparelho que executa a IA, FPS recebido/analisado, resolução recebida/analisada, tempo de inferência, atraso do frame, latência de rede e frames descartados;
- métricas do aparelho são separadas em `Este celular` e `Celular remoto`, incluindo bateria, carga, temperatura, brilho, CPU do Vigia IA, RAM, armazenamento e tipo de conexão;
- o Monitor passa a medir FPS de chegada independentemente do FPS efetivamente enviado à IA, além de contabilizar frames recebidos e descartados pelo pipeline;
- frames vindos do outro celular preservam o horário real de captura pelo cabeçalho `x-vigia-frame-captured-at`, permitindo calcular atraso ponta a ponta de forma útil;
- o Modo Câmera passa a disponibilizar telemetria do aparelho remoto também no Monitor normal, mantendo a política específica do Bike quando ele estiver ativo;
- Android informa o transporte de rede ativo (Wi-Fi, Ethernet, dados móveis, VPN ou Bluetooth) via telemetria;
- o fluxo imersivo do Modo Bike e qualquer integração ESP32 permanecem inalterados nesta versão.

### Evolução 1.0.48

- os 78 áudios padrão foram convertidos de WAV PCM para AAC/M4A mono em 24 kHz, formato mais consistente entre implementações Android do `MediaPlayer`;
- a reprodução nativa usa URI `android.resource://` e `AudioAttributes` voltados a alertas falados;
- áudios personalizados continuam aceitando WAV, MP3, OGG, M4A/AAC e MP4 de áudio;
- a tela Áudios e voz mantém `Ouvir`, `Trocar` e `Gravar` sempre na mesma linha, com botões responsivos;
- a restauração do áudio padrão fica no cabeçalho do item quando existir personalização, evitando um quarto botão na linha principal.

### Evolução 1.0.47

- release Android usa uma keystore permanente reconstruída somente durante o workflow;
- os Secrets esperados são `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` e `ANDROID_KEY_PASSWORD`;
- o workflow valida a keystore/alias com `keytool` e valida a APK pronta com `apksigner`;
- o Gradle recebe a assinatura por variáveis de ambiente e não contém senha, base64 ou arquivo de chave versionado;
- `.jks`, `.keystore` e `android/key.properties` ficam explicitamente ignorados pelo Git;
- após a migração inicial de assinatura, versões futuras com a mesma chave e `versionCode` maior podem atualizar o app sem desinstalação.

> Importante: uma instalação antiga assinada com a chave debug não é compatível com a nova chave permanente. Pode ser necessária uma última desinstalação na primeira migração; depois disso, preserve os Secrets permanentemente.

### Evolução 1.0.46

- buildfix após o workflow real da 1.0.45 apontar `Icons.person_voice_outlined` como símbolo inexistente no Flutter 3.44.9;
- o chip `Seu áudio` passa a usar `Icons.mic_rounded`, disponível no Material Icons atual;
- não há mudança funcional no catálogo: permanecem 78 slots, importação de arquivo, gravação, restauração e fallback TTS;
- a verificação preventiva passa a rejeitar a reintrodução do getter incompatível antes do ZIP final.

### Evolução 1.0.45

- biblioteca central com 78 slots de áudio: 14 usados pelo monitor atual e 64 preparados para Bike/ESP32;
- os 68 novos avisos enviados pelo usuário foram recortados e incorporados em WAV mono/24 kHz;
- nova tela `Configurações → Geral → Áudios e voz` permite ouvir, substituir por arquivo, gravar pelo microfone, restaurar individualmente ou restaurar todos;
- áudios personalizados ficam no armazenamento privado do app e têm prioridade sobre os arquivos padrão, sobrevivendo a atualizações normais do APK;
- TTS permanece como fallback de segurança quando um áudio não puder ser reproduzido;
- Android ganhou importação via seletor de arquivos e gravação AAC/M4A com permissão de microfone sob demanda;
- slots futuros de pressão/temperatura dos pneus, Hall/velocidade, ESP32, celular traseiro, faróis, freios, setas, bateria auxiliar e sistema já aparecem marcados como `Futuro`;
- catálogo, documentação, testes e verificadores passam a validar unicidade e presença dos 78 arquivos.

### Evolução 1.0.44

- Modo Bike adicionado como quinto destino da barra principal, com ícone de bicicleta e rótulo `Bike`;
- a própria tela Bike mantém a barra principal visível e seleciona o novo destino;
- Início, Histórico e Câmeras passam a navegar diretamente para Bike pelo mesmo fluxo principal;
- o atalho antigo em Configurações → Monitoramento foi removido para evitar que o modo operacional fique escondido ou duplicado;
- toda a lógica de economia, telemetria, transmissão e painel remoto permanece inalterada;
- teste de widget garante que o menu principal tenha cinco destinos e que Bike use o índice 4;
- versionamento, metadados, documentação, tela de mudanças, testes e verificadores sincronizados em `1.0.44+44`.

### Evolução 1.0.43

- removidos dois casts redundantes em `RemotePhoneStatus.fromJson` e `RemotePhoneCameraSource._pollStatus`;
- correção direcionada ao `flutter analyze` do Flutter 3.44, que tratava esses avisos como falha do workflow;
- nenhuma funcionalidade do painel remoto, telemetria ou transmissão do Modo Bike foi removida ou alterada;
- versionamento, metadados, documentação, tela de mudanças, testes e verificadores sincronizados em `1.0.43+43`.

### Evolução 1.0.42

- `RemotePhoneCameraSource` consulta também `/status` do aparelho traseiro, sem criar protocolo paralelo e sem interromper o vídeo caso a telemetria falhe;
- o celular da frente recebe bateria/carga, temperatura, brilho/tela, CPU, memória e estado do Modo Bike;
- o Modo Câmera passa a informar FPS aproximado da captura e o receptor mede a latência da consulta de telemetria;
- o monitor Ao vivo ganhou um atalho de bicicleta e um resumo compacto com bateria/temperatura do aparelho traseiro;
- painel remoto detalhado mostra energia, processamento, memória, FPS, latência e perfil energético;
- avisos visuais destacam bateria baixa, temperatura elevada, CPU alta, pouca RAM e telemetria desatualizada;
- o limite de bateria baixa configurado no aparelho traseiro é enviado ao receptor para que os dois celulares usem o mesmo critério;
- a telemetria continua sendo complementar: falha do endpoint `/status` não derruba a transmissão de imagem.

### Evolução 1.0.41

- Modo Bike passa a aplicar os perfis Normal, Economia e Economia extrema ao pipeline real de monitoramento e ao Modo Câmera;
- intervalo de captura/análise é limitado conforme o perfil, sem aumentar a frequência configurada pelo usuário;
- transmissão LAN recebe teto de FPS e compressão JPEG adaptativa, com menor resolução/qualidade nos perfis econômicos;
- brilho do Vigia IA no celular traseiro pode ser reduzido durante a operação e é restaurado ao finalizar;
- telemetria local passa a reunir bateria, estado/origem/corrente aproximada de carga, temperatura, brilho, CPU, núcleos e memória;
- a própria tela Modo Bike mostra essas condições em tempo real;
- Saúde do sistema e relatório de diagnóstico foram ampliados com as mesmas métricas;
- status LAN e status do Modo Câmera já podem carregar a telemetria quando a opção de envio estiver ativa, preparando a Etapa 3;
- bateria baixa gera aviso local durante a operação, sem repetir continuamente.

### Evolução 1.0.40

- novo item `Modo Bike` em Configurações → Monitoramento;
- ativação persistente para identificar o aparelho que ficará na traseira da bicicleta;
- perfis Normal, Economia e Economia extrema com metas de IA/transmissão;
- preferências para reduzir atividade da tela, manter telemetria remota e avisar bateria baixa;
- arquitetura preparada para a próxima etapa aplicar os perfis ao pipeline real e transmitir as condições do aparelho traseiro.

### Evolução 1.0.39

- nova tela inicial explica câmera, notificações e rede local/dispositivos próximos, com botões para permitir ou abrir os ajustes do Android;
- Monitor ao vivo passa a usar o título curto `Ao vivo`, e o chip `Status` foi substituído por `Painel`;
- textos longos da interface foram ajustados para reduzir sobreposição e melhorar clareza em telas estreitas;
- seleção de fonte foi redesenhada em cartões explicativos para câmera local, RTSP e outro celular;
- pareamento com outro celular pode ser preenchido pelo QR do Modo Câmera, além da entrada manual de endereço/chave;
- pista complementar de presença humana usa movimento + aparência de pele para tentar reconhecer mão/braço muito próximos quando o detector principal perde o corpo completo;
- memória visual do alerta reduz novas falas para o mesmo objeto após pequenas perdas/reidentificações;
- seleção visual da fonte não usa mais `Radio.groupValue/onChanged`, removendo os avisos que bloqueavam `flutter analyze` no Flutter 3.44.

### Evolução 1.0.38

- áudio único fornecido pelo usuário foi separado em dez arquivos WAV curtos e incluído em `custom_audio/`;
- slots específicos adicionados para `person_entered`, `person_exited`, `vehicle_entered`, `vehicle_exited`, `animal_entered` e `animal_exited`;
- detecção de pessoa/veículo/animal/objeto e alertas de câmera usam as gravações incluídas quando disponíveis;
- `animal_entered` e `animal_exited` continuam em fallback TTS porque essas duas frases não estavam presentes na gravação recebida;
- a cópia Android atual também recebe os WAVs em `res/raw`, enquanto o bootstrap continua reconstruindo esses recursos a partir de `custom_audio/`.

### Evolução 1.0.37

- o detector de movimento deixa de comparar apenas luminância e passa a considerar também distância RGB, capturando mudanças de cor que poderiam ter brilho semelhante;
- cada detecção confirmada recebe uma assinatura visual leve de cor extraída do próprio `RgbFrame`;
- pessoas usam pistas aproximadas de cor no tronco e nas pernas, enquanto veículos/animais usam histograma de cor do recorte interno;
- `ObjectTracker` combina IoU, distância, tamanho, previsão de movimento, família semântica e semelhança de aparência;
- a identidade pode permanecer em memória por até 12 s após uma perda do detector, sem manter o objeto como visível, permitindo reaquisicao do mesmo ID;
- alertas normais passam a usar a família + ID estável (`person/vehicle/animal`) em vez do rótulo bruto, evitando nova fala quando `car` oscila para `truck` ou `cat` para `dog`;
- falas de entrada/saída do mesmo ID/área recebem uma janela curta antichatter de 5 s; os eventos continuam sendo registrados;
- áudios próprios podem substituir o TTS por arquivo opcional em `custom_audio/`; se o arquivo não existir, o TTS continua sendo usado automaticamente;
- testes novos cobrem movimento por diferença de cor, extração de aparência e reaquisicao visual do mesmo objeto.

### Áudios personalizados

A biblioteca padrão contém 78 avisos e pode ser gerenciada dentro do próprio app em `Configurações → Geral → Áudios e voz`. Cada slot pode ser ouvido, substituído por um arquivo do aparelho, gravado pelo microfone e restaurado ao padrão. Personalizações ficam no armazenamento privado e têm prioridade sobre `custom_audio/`; o TTS continua como fallback de segurança. O diretório `custom_audio/` permanece como fonte versionada dos áudios padrão usados pelo build. Consulte `custom_audio/README.md` para detalhes.

### Evolução 1.0.36

- classes monitoradas são filtradas dentro do detector antes do limite de resultados; objetos irrelevantes do COCO não consomem mais as vagas reservadas à saída útil;
- confiança adaptativa considera também o tamanho da caixa: objetos pequenos podem entrar com score menor, mas precisam de mais confirmação temporal;
- movimento separado gera focos separados, preservando o zoom da segunda passagem;
- uma varredura multiescala controlada alterna dois tiles sobrepostos ou tenta um recorte de reaquisicao do objeto recém-perdido;
- a passagem extra é limitada e espaçada (~1,6 s) para equilibrar alcance e consumo;
- duplicatas fortemente sobrepostas da mesma família são consolidadas, reduzindo troca `car/truck` ou `cat/dog` sobre o mesmo objeto;
- novos testes cobrem os planejadores e políticas da detecção 1.0.36.

### Evolução 1.0.35

- removido o import redundante de `dart:typed_data` em `SharedLocalCameraService`;
- mantido integralmente o pipeline de detecção aprimorado da 1.0.34;
- `tool/verify_project.sh` passa a bloquear a reintrodução desse import redundante;
- versão, metadados e tela de mudanças sincronizados em `1.0.35+35`.

### Evolução 1.0.34

- `EfficientDet-Lite0` passa a ser o detector principal; `SSD MobileNet V1` permanece como fallback automático quando o modelo principal não estiver disponível ou não for compatível com o runtime do aparelho;
- o pré-processamento passa a usar **letterbox**, preservando a proporção do frame em vez de esticar 720×480 para um tensor quadrado; as caixas são remapeadas de volta para o frame original;
- a confiança configurada pelo usuário continua sendo a referência, mas Pessoa, Automóvel e principalmente Animal recebem uma pequena margem de candidatura; detecções abaixo do limiar principal só avançam depois de confirmação temporal em frames coerentes;
- detecções fortes continuam entrando imediatamente, evitando acrescentar atraso artificial quando a IA está segura;
- o modo **Somente movimento** deixa de apagar objetos apenas porque ficaram parados: a presença é revalidada periodicamente e o movimento passa a controlar principalmente economia e elegibilidade de alerta;
- quando existe movimento localizado e a primeira inferência não encontra objeto útil, o Vigia IA recorta e amplia somente aquela região para uma segunda tentativa, reduzindo o custo em comparação com duas inferências permanentes;
- resultados da passagem normal e ampliada são mesclados com supressão de duplicatas;
- tempos padrão das Regras Inteligentes foram reduzidos para 600 ms em veículos, 800 ms em animais e 1,2 s em outros objetos; Pessoa continua sem espera adicional; perfis personalizados são preservados;
- novos testes cobrem letterbox/remapeamento, limiares adaptativos, confirmação temporal, mesclagem de passagens e região de foco do movimento.

### Evolução 1.0.33

- um único pipeline `SharedLocalCameraService` atende Monitor e Modo Câmera, evitando múltiplos `CameraController` e o erro CameraX de combinação de superfícies;
- visualizador web abre pelo endereço limpo e autentica com chave separada; link automático usa fragmento `#key`, cria sessão por cookie e limpa a barra do navegador;
- página web não depende mais de MJPEG: consulta estado real e carrega `/frame.jpg` somente quando a sequência muda;
- status web diferencia servidor ativo de frames ativos e mostra FPS/clientes reais;
- Diagnóstico e Saúde do sistema também separam servidor LAN ativo de frames LAN recentes, evitando indicar transmissão funcional quando a página abre sem imagem;
- reação padrão da câmera local passa a 400 ms e saída de rastreamento a 1 s, com migração apenas dos antigos valores padrão;
- TTS descarta mensagens antigas, prioriza o alerta mais recente e protege transições/alertas de câmera contra falas genéricas; alertas são emitidos antes da gravação do Histórico;
- watchdog verifica o fluxo a cada 3 s e reinicia o pipeline compartilhado se a câmera congelar;
- Foreground Service recebe heartbeat do Flutter e sinaliza quando o serviço Android ficou vivo sem o monitor Dart;
- segundo plano operacional exige serviço + heartbeat + frames reais;
- Monitor ao vivo e Modo Câmera usam tela imersiva; demais telas permanecem edge-to-edge;
- Monitor e Modo Câmera usam leases do Foreground Service; desligar um deles não derruba o serviço ainda necessário pelo outro.
- voz, som/vibração e notificação são disparados em paralelo, sem esperar a fala terminar.

### Evolução 1.0.32

- corrigida a precedência da expressão Kotlin em `localNetworkPermissionStatus()`, envolvendo o valor booleano de `canRequest` entre parênteses antes de associá-lo à chave do `mapOf`;
- `android/.../MainActivity.kt` e `tool/android/MainActivity.kt` permanecem sincronizados, evitando que o bootstrap do workflow restaure a versão incorreta;
- verificação preventiva agora exige a forma segura da expressão nativa;
- metadados sincronizados com `1.0.32+32`.

### Evolução 1.0.31

- chave da URL LAN usa percent-encoding canônico, com espaços como `%20` em vez de `+`;
- o mesmo formato é usado no endereço compartilhado e no stream MJPEG interno;
- a validação da chave no servidor permanece equivalente, pois os parâmetros são decodificados antes da comparação;
- verificações preventivas e metadados sincronizados com `1.0.31+31`.

### Evolução 1.0.30

- corrigido o import do modelo `CameraHealthState` no `MonitorController`;
- corrigida a inferência `num`/`double` no `StorageSizeFormatter`;
- metadados, testes de versão e verificações preventivas sincronizados com `1.0.30+30`.

### Evolução 1.0.29

- Diagnóstico passa a usar um snapshot único do estado e dos registros técnicos; tela, TXT exportado, cópia e compartilhamento usam a mesma captura;
- botão **Exportar** gera `vigiaia_diagnostico_*.txt` e o compartilhamento usa a folha nativa do Android;
- Saúde do sistema separa serviço Android, câmera, frames, monitoramento IA, transmissão LAN, clientes, permissões e segundo plano;
- serviço Android ativo sem frames não é considerado monitoramento funcionando;
- frames congelados expiram por heartbeat, derrubando corretamente câmera/IA e a transmissão LAN operacional;
- memória e armazenamento usam formatação única em B/KB/MB/GB/TB;
- Armazenamento e backup também usa os valores formatados;
- telas técnicas receberam ajuda curta pelo botão **?**;
- testes novos cobrem formatação, estados da Saúde, expiração de frames, diagnóstico e exportação.

### Evolução 1.0.28

- pacote Dart renomeado para `vigiaia`;
- namespace/applicationId Android migrados para `com.vigiaia.app`;
- canais nativos e alias interno atualizados para a identidade `vigiaia`;
- protocolo de pareamento atualizado para `vigiaia://pair`, sem hífen;
- artifact e empacotamento de fonte usam a identidade técnica `vigiaia`;
- corrigido o lint `use_null_aware_elements` em `BackgroundMonitorService`;
- removido import redundante de `dart:typed_data` em `MonitorLanStreamService`;
- testes e verificação preventiva atualizados para a nova identidade e versão.

### Evolução 1.0.27

- monitor ativo abre automaticamente um servidor HTTP somente na interface de rede local, na porta `8766`;
- outro celular na mesma rede pode assistir no navegador usando o endereço exibido no botão **Rede local** do monitor;
- a transmissão usa MJPEG e reaproveita os mesmos `RgbFrame` do pipeline existente, sem instanciar outra câmera;
- endereço inclui chave aleatória por sessão e endpoints de quadro/status também exigem a chave;
- contador de visualizadores aparece no monitor;
- servidor LAN acompanha o ciclo de vida da fonte: encerra quando o monitor para, sai do horário ou troca/reinicia a fonte;
- Android 16/17 recebe declaração e bridge de permissão de rede local/dispositivos próximos, com pedido em runtime quando exigido ou quando um socket é bloqueado;
- falha ou recusa da permissão LAN não impede o monitoramento local/IA de continuar.

### Evolução 1.0.26

- câmera solicitada na primeira abertura e revalidada antes de iniciar monitoramento local;
- concessão da permissão no botão Iniciar prossegue automaticamente no mesmo fluxo;
- foreground service usa tipo `camera` para câmera local e `specialUse` para fontes sem câmera;
- serviço é iniciado antes da câmera local quando Segundo plano está habilitado;
- notificação permanente acompanha o estado real do fluxo e avisa quando frames deixam de chegar;
- tela bloqueada/minimização mantêm CPU e câmera em execução dentro das permissões do Android;
- watchdog tenta recuperar a câmera se frames pararem;
- `START_NOT_STICKY` evita notificação órfã após morte do processo;
- Modo Câmera também usa foreground service durante transmissão local.

### Evolução 1.0.25

- nome público alterado para **Vigia IA** em metadados, interface, notificações nativas, Manifest e documentação;
- versão atualizada para `1.0.25+25`;
- tema padrão de novas instalações alterado de Sistema para **Escuro**;
- preferências já salvas continuam sendo respeitadas;
- `applicationId` e namespace Android foram mantidos nesta etapa para não transformar a atualização em um aplicativo separado nem perder os dados locais;
- verificação preventiva ampliada para validar identidade, versão e tema padrão.

### Evolução 1.0.24

- seleção de objetos reduzida a três grupos: **Pessoas**, **Automóveis** e **Animais**;
- Automóveis agrupam carro, moto, ônibus e caminhão; Animais usam apenas classes úteis do modelo;
- classes antigas continuam compatíveis internamente, mas não aparecem na interface, alertas ou Histórico;
- migração automática das seleções antigas para os novos grupos;
- navegação principal simplificada para **Início | Histórico | Monitor | Câmeras**;
- Configurações e Diagnóstico saem da barra inferior e ficam centralizados na engrenagem;
- Configurações reorganizadas em Monitoramento, Alertas, Aparência, Armazenamento, Sistema, Diagnóstico, Sobre e uma seção Avançado separada;
- Histórico responde “quem ou o que passou na frente da câmera?”, com filtros por grupo e câmera;
- eventos técnicos de obstrução, deslocamento, conexão e erros ficam fora do Histórico e permanecem no Diagnóstico;
- tema **Sistema / Claro / Escuro** e cores **Turquesa / Azul / Roxo / Laranja**, persistidos localmente;
- Central multicâmera deixa explícito que adicionar câmeras não ativa contador;
- arquitetura possui apenas uma flag futura, desativada por padrão, para eventual contagem individual por câmera;
- textos de rastreamento, áreas, entrada/saída, confiança, intervalo da IA e repetição de alertas foram simplificados;
- corrigido o lint `use_build_context_synchronously` que bloqueava o workflow Android APK 22.

### Evolução 1.0.23

- QR Code no **Modo Câmera** com endereço local e chave temporária da sessão;
- botão **Escanear QR do celular** na Central multicâmera;
- QR versionado com esquema próprio `vigiaia://pair`, sem aceitar links genéricos;
- validação do endereço e da chave antes do pareamento;
- teste real do endpoint `/status` antes de permitir salvar a câmera;
- se o mesmo endereço já existir, a chave é atualizada sem duplicar o cadastro;
- leitura manual por endereço + chave continua disponível;
- seleção de IP local prioriza faixas IPv4 privadas para reduzir erros em aparelhos com múltiplas interfaces;
- `mobile_scanner` usa o mecanismo de leitura embarcado no APK para manter o fluxo de QR utilizável offline.

### Evolução 1.0.22

- Central multicâmera em grade responsiva para retrato e paisagem;
- atualização automática de disponibilidade a cada 15 segundos;
- probes de conexão em paralelo para não bloquear a lista câmera por câmera;
- estado online/offline/desativado, latência e último evento por câmera;
- editar, renomear, ativar/desativar e remover RTSP/celulares remotos;
- `cameraId` persistido nos eventos para manter a origem correta após renomear;
- reconexão contínua do celular remoto após perdas transitórias;
- workflow com cobertura de testes salva como artifact.

### Correção 1.0.20

- corrige a troca de IDs observada quando dois objetos iniciam um cruzamento em sentidos opostos;
- a primeira velocidade realmente observada deixa de ser amortecida contra uma velocidade zero fictícia;
- a suavização continua sendo aplicada nas atualizações seguintes, preservando estabilidade contra jitter;
- mantém intacto o teste de regressão que detectou a falha: a correção foi feita no algoritmo, não no teste;
- não remove nem simplifica nenhuma função existente.

### Correção 1.0.19

- corrige os erros de `flutter analyze` encontrados no workflow Android APK 18;
- mantém valores de integridade da câmera tipados como `double`;
- usa `VideoSourceState.streaming` para a câmera remota online;
- remove uso depreciado do `RadioListTile` na tela de presets;
- não remove nem simplifica nenhuma função existente.

### Fontes de vídeo

- câmera local do dispositivo;
- câmera IP/Wi‑Fi por RTSP;
- outro celular Android em **Modo Câmera**, pela mesma rede Wi‑Fi ou hotspot;
- troca de fonte durante a sessão de monitoramento;
- Central multicâmera com status online/offline e acesso rápido.

O modo de celular remoto usa HTTP apenas dentro da rede local configurada pelo usuário. Não existe servidor de nuvem intermediário.

## IA e monitoramento

- SSD MobileNet V1 local com LiteRT/TensorFlow Lite;
- confiança e frequência de análise configuráveis;
- filtro de movimento antes da IA;
- proteção contra movimento causado pela própria câmera;
- filtro visual por Pessoas, Automóveis e Animais;
- Regras Inteligentes por Pessoa, Automóvel e Animal;
- até 6 áreas de monitoramento editáveis sobre o vídeo;
- rastreamento individual com IDs;
- detecção de entrada e saída por área;
- caixas de detecção com nome, confiança e ID;
- anti-repetição considerando o `trackId` quando disponível;
- detecção de câmera obstruída ou deslocada;
- agenda semanal;
- Foreground Service opcional.

### Rastreamento 1.0.18

O `ObjectTracker` deixou de usar associação simples por primeira correspondência e passou a ordenar pares globalmente usando:

- classe;
- IoU;
- distância entre centros;
- tamanho da caixa;
- posição prevista;
- velocidade suavizada;
- tempo desde o último frame.

Isso reduz trocas de ID em cruzamentos, pequenas oclusões e objetos próximos. Continua sendo rastreamento heurístico: não é reconhecimento facial, biometria nem identificação permanente de pessoas.

## Alertas configuráveis

Cada perfil pode combinar independentemente:

- voz/TTS;
- som;
- vibração;
- notificação Android.

Também é possível personalizar frases para:

- pessoa;
- automóvel;
- animal;
- entrada em área;
- saída de área;
- câmera obstruída;
- câmera deslocada;
- grupo + área específica.

As regras específicas usam seletores em português e as áreas já cadastradas. Os marcadores `{objeto}` e `{area}` podem ser usados nas mensagens.

## Clipes reais

`ClipRecorderService` mantém um buffer dos frames já analisados. Quando um evento confirmado dispara a gravação:

1. reúne contexto anterior e posterior;
2. tenta gerar MP4/H.264 no Android via `MediaCodec` + `MediaMuxer`;
3. associa o arquivo ao mesmo evento do Histórico;
4. se o encoder nativo não estiver disponível ou falhar, usa GIF como fallback quando configurado.

A duração é configurável entre **3 e 20 segundos**. O Histórico continua aceitando os GIFs das versões anteriores e também reproduz MP4.

## Modo Câmera e Central multicâmera

### Modo Câmera

Um celular pode publicar sua câmera apenas na rede local. O app mostra:

- endereço local;
- chave de sessão;
- preview;
- estado da transmissão.

No aparelho Central, o fluxo recomendado é **Configurações → Monitoramento → Multicâmera → Escanear QR do celular**. O cadastro manual por endereço + chave permanece disponível como alternativa.

### Central multicâmera

Gerencia:

- câmera deste aparelho;
- câmeras RTSP;
- celulares remotos.

Cada entrada mostra estado online/offline/desativado, latência, último evento conhecido e atalho para monitorar. A Central atualiza os estados automaticamente a cada 15 segundos, permite renomear/editar e usa um `cameraId` estável para manter os eventos associados mesmo depois de uma mudança de nome. As fontes continuam usando o mesmo pipeline de IA, regras, eventos e clipes.

## Histórico e estatísticas

O Histórico persiste localmente:

- data/hora;
- categoria (Pessoa, Automóvel ou Animal) e confiança;
- fonte/câmera;
- bounding box;
- foto do frame;
- clipe GIF ou MP4;
- área;
- `trackId`;
- tipo de evento de passagem: alerta, entrada ou saída.

Obstrução, deslocamento, conexão e erros técnicos ficam no **Diagnóstico**, fora deste Histórico.

A tela Estatísticas calcula, sem nuvem:

- total por período;
- eventos do dia;
- eventos por categoria;
- eventos por área;
- eventos por câmera;
- movimento por hora;
- horário de maior movimento.

## Armazenamento, backup e exportação

A política de armazenamento permite definir:

- limpeza automática;
- retenção por dias;
- limite máximo de espaço para fotos e vídeos;
- limpeza manual.

O backup portátil salva regras, áreas, agenda, presets e preferências, mas **não exporta credenciais sensíveis**. A exportação de eventos cria um `eventos.json` acompanhado das fotos e clipes existentes.

## Segurança das credenciais RTSP

Na persistência Android, a URL RTSP com credenciais e outros segredos de câmera são protegidos com **AES-GCM usando uma chave armazenada no Android Keystore**.

O arquivo JSON de configurações não grava a URL RTSP sensível em texto puro. Se o Keystore falhar no Android, o app não degrada a credencial para Base64 como substituto de criptografia.

Backups portáteis removem credenciais. Ao restaurar um backup no mesmo aparelho, credenciais já existentes só são reaproveitadas quando o endpoint continua compatível.

## Segundo plano e recuperação

O Foreground Service continua opt-in e usa notificação persistente + `PARTIAL_WAKE_LOCK`. Ele usa o tipo `camera` quando algum recurso ativo precisa da câmera local e `specialUse` quando somente fontes sem câmera permanecem. Monitor e Modo Câmera mantêm leases independentes para que um recurso não encerre o serviço necessário pelo outro.

Na 1.0.33 o serviço usa `START_STICKY`, mas um heartbeat do Flutter impede que a simples existência do serviço seja confundida com monitoramento funcional. Se o processo Dart deixar de responder ou os frames congelarem, a notificação informa a falha e solicita reabertura quando a recuperação automática não conseguir restabelecer a câmera. Um serviço nativo órfão sem heartbeat por 1 minuto se encerra para não manter wake lock indefinidamente.

O estado do monitoramento e da agenda é registrado para recuperação. Após reinício do aparelho, atualização do pacote ou encerramento da tarefa, o app avalia se o perfil/horário permitem retomada.

**Limitação do Android:** versões modernas podem impedir que um aplicativo reabra câmera silenciosamente a partir do boot/background. Nesses casos, o `MonitorRecoveryReceiver` mostra uma notificação de retomada. Ao tocar, a Home consome o pedido e inicia o monitoramento. O aplicativo não tenta contornar restrições do sistema.

## Saúde do Sistema

O painel mostra, quando disponível:

- fonte/câmera;
- estado da IA;
- FPS de análise;
- bateria;
- temperatura da bateria;
- armazenamento livre/total;
- memória usada pelo processo;
- Foreground Service;
- erros/avisos recentes;
- estado da integridade da câmera.

Nenhum valor é inventado: métricas indisponíveis aparecem como **Indisponível**.

## Presets

- **Casa:** alertas moderados para rotina normal;
- **Ausente:** maior sensibilidade, segundo plano e integridade da câmera;
- **Noite:** menos ruído sonoro e repetição mais espaçada;
- **Personalizado:** preserva ajustes manuais.

Aplicar um preset não remove áreas, grupos selecionados nem a fonte de vídeo.

## Interface

A identidade visual continua compacta, agora com a organização da 1.0.24:

- dashboard compacto;
- navegação **Início, Histórico, Monitor e Câmeras**;
- uma única engrenagem para Configurações;
- Diagnóstico dentro de Configurações, separado do Histórico;
- vídeo dominante no monitor;
- detecções recolhíveis;
- retrato e paisagem;
- tema Sistema/Claro/Escuro e cor principal persistente;
- estados de cor semânticos e funções técnicas agrupadas em Avançado.

Sobre, Mudanças e Doações continuam disponíveis. A chave PIX exibida é `adriedson@outlook.com` e possui botão de cópia.

## Identidade do aplicativo

O nome público definitivo nesta etapa é **Vigia IA**. `app_identity.json` registra a identidade exibida e também documenta os identificadores técnicos Android mantidos por compatibilidade.

O `applicationId` e o namespace atuais foram preservados intencionalmente para permitir atualização sobre instalações existentes e manter os dados locais. Alterá-los exigiria uma migração separada, pois o Android passaria a tratar o pacote como outro aplicativo.

## Estrutura principal

```text
lib/
  controllers/        pipeline e estado do monitoramento
  core/               metadados, fonte e estados comuns
  models/             configurações, eventos, zonas, presets e saúde
  screens/            dashboard, monitor, eventos e módulos de ajustes
  services/           IA, regras, rastreamento, clipes, backup, saúde etc.
  sources/            câmera local, RTSP e celular remoto
  widgets/            overlays e navegação reutilizável

tool/
  android/             código nativo preservado pelo bootstrap
  bootstrap_android.sh recria a plataforma Android sem perder integrações
  fetch_model.sh       obtém o modelo quando o pacote usa placeholder
  verify_project.sh    verificações preventivas
  package_source.sh    gera o ZIP do projeto-fonte

.github/workflows/android-apk.yml
app_identity.json
```

## Requisitos

- Flutter 3.44 ou superior;
- Android 10 / API 29 ou superior;
- Java 17 no build;
- voz pt-BR instalada para TTS;
- permissão de câmera;
- permissão de notificação quando o usuário quiser notificações no Android 13+;
- acesso à rede local para RTSP/celular remoto.

## Build e validação

```bash
flutter pub get
bash ./tool/verify_project.sh
flutter analyze
flutter test
flutter build apk --release
```

O workflow `.github/workflows/android-apk.yml` mantém as mesmas validações, mas no release usa `setup-gradle@v6` + Gradle 9.1.0 para gerar universal e três ABIs em uma única `assembleRelease`; depois publica os APKs diretamente na GitHub Release e guarda apenas os relatórios técnicos como artifact separado. Para instalação em celulares atuais, o arquivo recomendado é o `arm64-v8a`; o `universal` mantém todas as arquiteturas.

O projeto-fonte pode ser empacotado com:

```bash
bash ./tool/package_source.sh
```

O empacotador preserva `.github/workflows/android-apk.yml`, `.gitignore`, scripts e demais arquivos necessários ao CI.

## Privacidade

- a IA roda localmente;
- não existe envio automático de vídeo para nuvem;
- o modo celular remoto usa a rede local definida pelo usuário;
- fotos, clipes, eventos, configurações e estatísticas ficam no aparelho;
- credenciais RTSP persistidas no Android são protegidas pelo Keystore;
- backups portáteis não incluem credenciais sensíveis.
