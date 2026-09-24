# Arquitetura — Vigia IA 1.0.110+110

## 1. Princípios

## Evolução 1.0.110 — ação fixa de mapa e integridade do pacote-fonte

- `_buildPortraitActionRow()` agora distribui cinco ações com espaçamento reduzido e `FittedBox` já existente para evitar corte dos rótulos em telas estreitas.
- O botão **Mapa** reutiliza `_setMonitorMapVisibilityQuick()`: quando visível envia `hidden`; quando oculto envia `always`. Não existe um segundo estado concorrente.
- O estado ativo é refletido por ícone e `accent`, mantendo a leitura visual consistente com os demais controles do monitor.
- O Android-APK-78 não chegou a `flutter analyze`: `verify_project.sh` falhou porque `.gitignore` não estava no ZIP submetido. O arquivo foi restaurado e o empacotamento oficial `tool/package_source.sh` permanece responsável por incluir e validar arquivos ocultos obrigatórios.

## Evolução 1.0.109 — atalho global do mapa no monitor

- A política de visibilidade do mini mapa já existia em `MapRouteService` (`automatic`, `always`, `hidden`), mas estava acessível apenas pelo painel do monitor.
- `_monitorMenu()` passou a expor essa política diretamente no menu dos três pontinhos com um toggle rápido **Mostrar mapa / Ocultar mapa**.
- Quando a visibilidade está forçada (`always` ou `hidden`), o menu também oferece **Mapa automático** para restaurar a decisão contextual baseada em bike conectada, rota ativa ou movimento recente.
- Como a preferência continua sendo salva em `MapRouteService`, o novo atalho não cria estado paralelo e se aplica de forma consistente aos layouts retrato, paisagem, multicâmera e tela inteira.

## Correção 1.0.108 — recursos Android do Android-APK-76

- O Manifest depende explicitamente de `@mipmap/ic_launcher`, `@style/LaunchTheme` e `@style/NormalTheme`; esses recursos agora fazem parte do projeto Android versionado em vez de depender implicitamente do `flutter create`.
- `values/styles.xml` e `values-night/styles.xml` definem os temas de inicialização/normal; `drawable/launch_background.xml` fornece o fundo de lançamento.
- O launcher possui recurso base e versão adaptativa `anydpi-v26`, compatível com o `minSdk 29`.
- A etapa **Preparar projeto Android** considera a árvore pronta apenas quando Gradle/wrapper e os recursos-base existem. Isso preserva builds rápidos sem aceitar um Android parcial.
- `verify_project.sh` valida os recursos e as referências do Manifest antes de `flutter analyze`, evitando descobrir a regressão apenas após vários minutos de Gradle.

## Correção 1.0.107 — compatibilidade Gradle/Kotlin do Android-APK-75

- `android/app/build.gradle.kts` segue o formato emitido pelo Flutter 3.44.9 para AGP 9.0.1: o app não declara mais `kotlin-android` diretamente.
- A configuração de JVM do Kotlin fica no bloco de nível superior `kotlin { compilerOptions { jvmTarget = ... } }`, evitando o `kotlinOptions.jvmTarget` legado que virou erro de compilação do script no Android-APK-75.
- `android.newDsl=false` e `android.builtInKotlin=false` permanecem como compatibilidade transitória do Flutter 3.44 para plugins ainda baseados no KGP; a aplicação do plugin é administrada pelo Flutter Gradle Plugin.
- A estratégia de build da 1.0.106 permanece: uma única `assembleRelease` produz universal + três ABIs e usa cache/paralelismo.

## Otimização 1.0.106 — pipeline Android de uma passagem

O workflow de release deixa de chamar o Flutter duas vezes para gerar APK universal e splits. No CI, `VIGIAIA_CI_MULTI_APK=1` habilita `splits.abi` no módulo Android somente durante a compilação release, com universal + `armeabi-v7a` + `arm64-v8a` + `x86_64`. Uma única execução `gradle :app:assembleRelease` alimenta todos os artefatos.

A etapa de empacotamento lê `output-metadata.json` do Android Gradle Plugin para identificar a saída universal e o filtro ABI de cada APK. Isso desacopla o workflow de nomes internos e faz o job falhar caso uma arquitetura esperada não seja produzida.

`org.gradle.caching=true` e `org.gradle.parallel=true` permitem reaproveitar tarefas elegíveis e executar módulos independentes em paralelo. `setup-gradle@v6` instala Gradle 9.1.0 (igual ao wrapper declarado) e administra o Gradle User Home; a limpeza final foi desativada neste workflow para priorizar tempo de execução. O diretório `android/` versionado é preservado entre as etapas do job e `bootstrap_android.sh` só é chamado se a estrutura Android estiver incompleta.


## Correção 1.0.105 — buildfix do Android-APK-73

- `MapMonitoringScreen` continua usando os tipos binários já expostos por `package:flutter/foundation.dart`, portanto o import direto de `dart:typed_data` foi removido para satisfazer `unnecessary_import`.
- `LocalCameraSource` acessa o controlador compartilhado sem referenciar símbolos diretamente de `package:camera/camera.dart`; o import não utilizado foi removido para satisfazer `unused_import`.
- A correção não altera o pipeline de vídeo, a adaptação de proporção dos PiPs, o mapa, a IA ou a persistência; é uma limpeza estática para liberar novamente o workflow.
- `tool/verify_project.sh` contém guardas preventivas para esses dois padrões enquanto eles permanecerem desnecessários.

## Evolução 1.0.104 — painel de fonte e mapa com PiPs adaptativos

- `OfflineMapService` expõe somente sob ação explícita do usuário a chave descriptografada em memória para **Ver/Copiar** e adiciona um teste de credencial por requisição mínima; a persistência continua protegida pelo Android Keystore.
- `OfflineMapManagerSheet` concentra estado, edição, teste e orçamento de créditos da fonte Stadia em um único painel, sem preencher automaticamente o campo de edição com o segredo salvo.
- `OfflineAreaSelectionScreen` separa os gestos de mover o mapa e ajustar o retângulo de seleção e oferece controle explícito do zoom pela barra inferior.
- `MapMonitoringScreen` usa uma faixa horizontal de telemetria sobre o mapa e reserva a região inferior somente para a ação principal da rota.
- O mapa recebe builders/listenables independentes da câmera principal e da segunda câmera; cada PiP mantém offset próprio e recalcula dimensões com base no aspect ratio corrente.
- A proporção da câmera principal é lida dinamicamente de `MonitorController`; a segunda câmera expõe proporção para câmera local/frontal e stream remoto quando disponível.
- Ações secundárias da rota permanecem acessíveis pelo menu do AppBar, reduzindo a área ocupada sobre o trajeto.

## Evolução 1.0.103 — orçamento local de créditos para mapas

- `OfflineMapDownloadEstimate` deriva créditos diretamente da quantidade de tiles raster planejados; a regra atual centralizada é 1 crédito por tile padrão.
- `OfflineMapService` mantém `stadiaCreditsUsedThisMonth`, `stadiaMonthlyCreditLimit` e a chave do mês no mesmo manifesto dos mapas offline.
- A janela mensal é reiniciada localmente quando o mês muda; o padrão de limite é 150 mil créditos e pode ser ajustado pelo usuário conforme o plano da própria conta.
- Antes de baixar, o serviço compara créditos estimados com o saldo local e bloqueia operações que ultrapassariam o orçamento configurado.
- O consumo é incrementado após lotes de tiles efetivamente obtidos e persistido durante/finalmente no download para reduzir perda do contador em falhas.
- `OfflineMapManagerSheet` exibe orçamento mensal, saldo, créditos estimados, alerta de 80% e explica que a medição é local e não lê o consumo global da Stadia.
- A correção do Android-APK-71 remove o `!` desnecessário no cálculo de zoom para `baseBounds`, mantendo a mesma lógica funcional.

## Evolução 1.0.102 — onboarding da API de mapas offline

- `OfflineMapManagerSheet` centraliza os links oficiais da Stadia Maps e oferece ajuda contextual antes de salvar a API key.
- A ajuda descreve o fluxo de obtenção da chave no client dashboard e mantém o campo de credencial separado do conteúdo explicativo para reduzir erro de configuração.
- `NativePlatformService.openExternalUrl()` aceita apenas `http`/`https` e delega a abertura ao Android.
- `MainActivity` trata `openExternalUrl` com `Intent.ACTION_VIEW`; o template em `tool/android/MainActivity.kt` permanece byte a byte sincronizado.
- Se não houver navegador disponível ou a abertura falhar, a camada Flutter copia o endereço oficial para o clipboard e informa o usuário.

## Evolução 1.0.101 — limite offline inteligente e navegação

- `OfflineMapManagerSheet` calcula o maior raio/margem que cabe no cache seguro e reduz automaticamente área ou zoom quando o usuário aumenta o outro eixo.
- O teto técnico continua em 100 MB, mas o planejador usa 95 MB como limite seguro para reservar margem contra variação do tamanho real dos tiles.
- `OfflineAreaSelectionScreen` mantém um retângulo normalizado independente da viewport; o usuário move/redimensiona o quadro e a tela converte a seleção para `LatLngBounds`, interpolando latitude em WebMercator.
- `MapMonitoringScreen` continua usando a sessão persistente única de rota e amplia o painel de navegação com altitude, rumo, precisão e estado de acompanhamento do mapa.
- O marcador atual usa `headingDegrees` para indicar visualmente o sentido de deslocamento quando o GPS fornece rumo válido.

## Evolução 1.0.100 — buildfix Android-APK-68

- A correção é estritamente de análise estática e não altera o desenho funcional introduzido na 1.0.99.
- A extension `monitor_screen_offline_map.dart` delega atualizações visuais para `_MonitorScreenState._refresh()`, mantendo `setState` dentro de um membro válido de `State`.
- `MapRouteService` usa atribuição condicional ao criar a assinatura do stream de GPS e preserva uma única subscription ativa.
- `OfflineMapService` mantém a mesma regra de expiração de tiles sem operador de não-nulo redundante.

## Evolução 1.0.99 — download offline direto e GPX

- `OfflineMapService` passa a gerar MBTiles raster no próprio aparelho a partir de tiles de uma fonte explicitamente configurada e autorizada, além de manter importação e download de MBTiles prontos.
- A integração inicial usa **Stadia Maps Alidade Smooth** com API key fornecida pelo usuário; `NativePlatformService.protectSecret/unprotectSecret` protege a credencial pelo Android Keystore.
- Downloads por região usam bounds/níveis de zoom; downloads por trajeto calculam um corredor em espaço de tiles ao redor dos segmentos registrados.
- `sqlite3` cria `metadata`/`tiles` no padrão MBTiles e converte XYZ para TMS ao gravar `tile_row`; o arquivo é validado antes de virar pacote ativo.
- O serviço mantém estado de progresso, bytes/tiles, pausa, retomada e cancelamento, e impede que o cache do provedor ultrapasse o limite configurado.
- `OfflineMapPackage` passa a guardar provedor, bounds, min/max zoom, atualização e expiração estimada; o mapa usa os bounds para alertar quando a posição saiu da cobertura local.
- `OfflineAreaSelectionScreen` permite escolher a área visível no mapa para preparar o download, enquanto Região atual e Trajeto reutilizam a mesma estimativa centralizada.
- `MapRouteService` schema 2 persiste pausa, duração pausada e inícios de segmento. `routeSegments` impede linhas/distâncias artificiais entre uma pausa e sua retomada.
- `buildGpx()` gera GPX 1.1 com um `<trkseg>` por segmento; `MapMonitoringScreen` salva o arquivo pelo seletor nativo e expõe Pausar/Continuar na mesma sessão compartilhada.

## Evolução 1.0.98 — mapa adaptativo e sessão única de trajeto

- `MapRouteService` centraliza posição atual, stream do GPS, início/fim, distância, cronômetro e pontos do trajeto; Monitor e `MapMonitoringScreen` deixam de manter listas de rota independentes.
- O estado é persistido em `map_route_state.json` no diretório de suporte do app, incluindo a política do mini-mapa, rota ativa/concluída e telemetria necessária para restauração após reinício.
- `MonitorMapVisibilityMode` define **automatic**, **always** e **hidden**. No automático, Bike conectada, rota em andamento ou movimento recente >= 4 km/h com precisão GPS aceitável tornam o mini-mapa visível; fora dessas condições o layout vertical ganha espaço para a câmera.
- `OfflineMapService` continua responsável por MBTiles e agora também aceita importação de arquivo local validado; `NativePlatformService`/`MainActivity` expõem o seletor Android para `.mbtiles`.
- `OfflineMapManagerSheet` recebe contexto do mapa atual para planejar região em torno da posição, viewport visível ou corredor do trajeto, estimando tiles, armazenamento e espaço livre sem fazer prefetch do servidor público do OpenStreetMap.
- O mapa completo continua usando MBTiles como camada local, camada online opcional e PiP da câmera principal arrastável; o indicador resume a fonte como Online, Offline ou Mapa local.

## Evolução 1.0.97 — sincronização de versão protegida pelo verificador

- A correção não altera a arquitetura funcional da aplicação; mantém a base da 1.0.96.
- `test/app_metadata_test.dart` foi sincronizado com a versão corrente.
- `tool/check_version_sync.py` agora inclui o teste de metadados na checagem obrigatória, fechando a lacuna que permitiu ao verificador local passar com o teste desatualizado.

## Evolução 1.0.96 — mapas offline e câmera no mapa completo

- `OfflineMapService` gerencia pacotes raster `.mbtiles` no armazenamento interno, com manifesto persistente, download HTTP/HTTPS, validação SQLite, seleção, exclusão e progresso.
- `flutter_map_mbtiles` integra o pacote local ao `FlutterMap` existente sem trocar o renderer do mapa.
- O mapa completo oferece modos **Automático**, **Online** e **Offline**. No automático, o MBTiles ativo fica como camada base e os tiles online são desenhados por cima quando disponíveis.
- O download em massa do servidor público `tile.openstreetmap.org` não é usado; o gerenciador recebe um link direto para um pacote MBTiles de uma fonte/servidor que permita uso offline.
- `MapMonitoringScreen` recebe opcionalmente a prévia da câmera principal do `MonitorController`; quando aberto pelo Monitor, mostra essa fonte em PiP flutuante e arrastável por toda a área útil do mapa.
- O mapa continua acessível pelo modo Bike sem exigir uma câmera; nesse fluxo o PiP simplesmente não é criado.

## Evolução 1.0.95 — densidade, navegação e hub de câmeras

- `_DashboardMetricCard` passa a usar largura intrínseca limitada e dimensões menores, reduzindo vazios horizontais nos dados ESP32/Bike.
- `monitor_screen_portrait.dart` aumenta o mini-mapa para `25,5%` da altura útil, remove a ação fixa **Abrir mapa**, adiciona **Câmera** e abre `MapMonitoringScreen` ao tocar diretamente no mapa.
- `_DashboardActionButton` define cores explícitas para ações não destacadas, evitando que **Áudio**, **Painel** e **Ajustes** pareçam desabilitados no tema escuro.
- `_buildControlDock(compact: true)` distribui os seis atalhos em uma única linha a partir de largura suficiente e degrada para grade em telas menores.
- `_showCameraHub` centraliza seleção da câmera principal, modo uma/duas câmeras, frontal de teste, ESP32 e endpoints cadastrados; o menu de três pontos deixa de duplicar câmeras e Status da sessão.
- `_portraitPipOffset` mantém a posição do PiP e `onPanUpdate` limita o arraste à área do vídeo, impedindo que a segunda câmera cubra mapa ou ações inferiores.
- O monitor vertical envolve a área de vídeo com duplo toque para `_toggleFullscreen`, preservando o botão superior como alternativa.
- `_CameraPaneLabel` aceita detalhe opcional e usa dimensões menores; a fonte local embutida é identificada apenas como **Local**.
- O `DetectionOverlay` permanece inalterado funcionalmente: caixas verdes são decorativas e podem ser desacopladas da detecção em etapa futura.

## Evolução 1.0.94 — Monitor vertical refinado e PiP frontal

- `monitor_screen_portrait.dart` aumenta a altura útil do mini-mapa e mantém os quatro atalhos inferiores em um `Row` de quatro células, removendo a necessidade de rolagem lateral para **Ajustes**.
- A distância percorrida permanece na telemetria Bike; o overlay inferior esquerdo do mapa passa a consumir `MapRoutePoint.altitudeMeters`, evitando rotular distância como altitude e removendo o texto sem função **Bike**.
- `_DashboardMetricCard` usa dimensões e paddings menores para densificar a telemetria ESP32/Bike sem remover métricas.
- O Monitor vertical mantém mapa e ações mesmo com uma segunda fonte ativa; a segunda câmera passa a ser apresentada em Picture-in-Picture sobre a principal no modo retrato embutido.
- `FrontCameraPreviewSource` abre temporariamente a câmera frontal em `ResolutionPreset.low`, sem áudio e sem frames de IA. A principal continua sendo a única fonte analisada.
- `VideoSourceConfig.isFrontCameraTest` identifica a fonte temporária sem alterar os tipos públicos de fonte já persistidos.
- `SecondaryCameraController` libera a fonte após falha de inicialização, permitindo nova tentativa e isolando erros de câmera concorrente da câmera principal.
- Em aparelhos sem suporte a duas câmeras locais simultâneas, o PiP informa indisponibilidade; a compatibilidade real depende do hardware/CameraX e deve ser validada em dispositivo.

## Evolução 1.0.93 — composição vertical compacta

- `monitor_screen_portrait.dart` deixa de manter a lista completa de detecções como bloco fixo; a tela principal renderiza apenas `_buildPortraitDetectionSummary`.
- `_showPortraitDetections` usa `DraggableScrollableSheet` e compartilha o `ScrollController` com `_buildDetectionPanel`, mantendo a lista completa sob demanda.
- `_buildDetectionPanel` aceita `ScrollController?` opcional sem alterar os demais usos no Monitor.
- O mini-mapa vertical reduz altura, textos e controles, com localização/zoom alinhados em uma única linha.
- A telemetria da bike permanece no topo, mas com faixa mais baixa para reduzir rolagem e preservar a câmera.

## Evolução 1.0.92 — política de orientação

- `AppOrientationService` passa a ser a fonte única da política de rotação: retrato para o aplicativo normal e rotação automática apenas para Transmissão.
- `main.dart` inicia o app em retrato, evitando que Home, Histórico, Diagnóstico, Bike, Mapas, Configurações e Monitor entrem em paisagem.
- `CameraModeScreen` libera as quatro orientações ao entrar e restaura retrato ao sair; a interface já possui layout adaptativo para retrato/paisagem.
- `MonitorScreen` e sua tela inteira não liberam nem forçam paisagem. O modo imersivo permanece independente da orientação.
- `SharedLocalCameraService` continua usando `sensorOrientation` + `deviceOrientation`, então um transmissor fisicamente deitado envia o frame com a rotação correspondente sem exigir paisagem forçada.

## Evolução 1.0.91 — buildfix do Monitor vertical

- `monitor_screen_portrait.dart` mantém a mesma composição da 1.0.90 e corrige apenas a assinatura do `separatorBuilder` para o padrão aceito pelo analisador Dart atual.
- A correção é deliberadamente isolada: nenhuma política de orientação, transmissão, mapa, câmera ou pipeline de IA foi modificada.
- `tool/verify_project.sh` passa a bloquear a reintrodução do placeholder duplo que causou o Android-APK-59.

## Evolução 1.0.90 — monitor vertical com mapa

- `monitor_screen_portrait.dart` deixa o layout antigo baseado em faixa fixa + dock permanente e passa a usar uma composição com câmera maior, mini-mapa, faixa de ações e painel avançado sob demanda.
- A altura da câmera em retrato agora considera a proporção real da prévia (`previewAspectRatio`), melhorando o comportamento quando a câmera remota estiver em horizontal.
- O mini-mapa do monitor foi reutilizado no retrato com os mesmos serviços de GPS/rota do dashboard em paisagem.

## Evolução 1.0.89 — correção de estado do dashboard

- O arquivo extraído `monitor_screen_landscape_dashboard.dart` continua como extensão para manter `monitor_screen.dart` abaixo do limite preventivo.
- A extensão não acessa mais diretamente o membro protegido `State.setState`; atualizações visuais passam por `_updateMulticameraState`, método pertencente à própria `_MonitorScreenState`.
- Essa separação mantém a refatoração estrutural e elimina os quatro avisos que faziam o `flutter analyze` retornar código 1.

## Evolução 1.0.88 — dashboard ao vivo em paisagem

- `MonitorScreen` ganha um dashboard dedicado para câmera única em paisagem, com cabeçalho, área principal de vídeo, mini-mapa e ações rápidas sem esconder a câmera atrás do painel lateral.
- `LocationTrackingService.ensureAvailable` passa a aceitar leitura passiva (`requestPermission: false`), permitindo sondar disponibilidade do mapa sem pedir localização de forma agressiva.
- O mini-mapa reaproveita `flutter_map`, `MapRoutePoint` e `LocationTrackingService` para acompanhar posição e rota diretamente dentro do monitor.
- Detecções continuam usando o mesmo pipeline (`MonitorController`, overlays e zonas), mas agora são abertas em painel dedicado sob demanda no layout novo.

## Evolução 1.0.86 — mapa e rastreamento GPS

- `MapMonitoringScreen` concentra a UI cartográfica do Modo Bike e permanece desacoplada do pipeline de câmera/IA.
- `LocationTrackingService` encapsula permissões, disponibilidade do GPS, leitura atual e stream de posições via `geolocator`.
- `MapRoutePoint` é o modelo mínimo da posição capturada, incluindo precisão, velocidade, altitude e direção quando disponíveis.
- `flutter_map` renderiza tiles do OpenStreetMap, posição atual, linha da rota e marcadores de início/fim.
- A rota é mantida somente em memória nesta etapa; persistência, eventos da IA e pacotes offline são evoluções posteriores.
- Não há `ACCESS_BACKGROUND_LOCATION`; o rastreamento desta primeira etapa existe enquanto a tela de mapa está ativa.

## Evolução 1.0.85 — telemetria compacta e diagnóstico em linha

- `BikeRideHud` deixa de usar grade 2x3 no retrato e passa a renderizar mini-cards horizontais dentro de uma faixa rolável, preservando todos os dados na mesma linha sempre que possível.
- A faixa compacta remove o `IgnorePointer`, permitindo rolagem lateral direta quando houver mais métricas que a largura disponível.
- `_CurrentStateGrid` do Diagnóstico deixa de quebrar em várias linhas e vira uma sequência horizontal de chips de estado.
- `_PerformanceTelemetryCard` agrupa `Diagnóstico 30 s`, `Diagnóstico 60 s` e `Exportar` em uma única fileira horizontal rolável.

## Evolução 1.0.84 — correção de compilação

- Rótulos que dependem do `LayoutBuilder` são widgets não constantes, evitando `invalid_constant`.
- `_CategoryCard` mantém expansão inicial fechada sem expor parâmetro interno nunca utilizado.

## Evolução 1.0.83 — fontes e navegação de modo

- `CameraRegistryService` lê a telemetria já fornecida por `/status` do celular transmissor, sem transformar uma falha de detalhes em falha de conexão.
- O transmissor informa a resolução JPEG efetiva, além de FPS, nome e condições do aparelho; a Central exibe apenas os dados que a fonte realmente disponibiliza.
- A seleção de modo continua persistida por `AppLaunchModeService`, mas passa a ser alcançável a partir de cada modo sem limpar dados nem reiniciar a configuração.
- A tela Sobre mostra uma versão enxuta das cinco últimas mudanças; o histórico completo permanece preservado na documentação e no componente de consulta interno.

## Evolução 1.0.82 — distribuição Android por ABI

- O workflow mantém o APK universal e gera APKs separados para `arm64-v8a`, `armeabi-v7a` e `x86_64` com `flutter build apk --split-per-abi`.
- Todos recebem nome com produto, versão e arquitetura; o `+build` permanece no nome para identificar exatamente o código instalado.
- Os APKs são assets da GitHub Release, portanto o download entrega `.apk` diretamente. Os relatórios de auditoria continuam em artifact independente, que o GitHub compacta como ZIP por natureza.

## Evolução 1.0.81 — composição fixa do Monitor

- `monitor_screen_portrait.dart` concentra somente a composição visual vertical e mantém o arquivo principal responsável pelo ciclo de vida e pelas ações.
- O retrato usa uma coluna estável: telemetria, atalhos de estado, cartão de câmera, comandos e painel de detecções com rolagem interna.
- O estágio adaptativo recebe `portraitEmbedded` para ocultar HUDs sobrepostos apenas no retrato; paisagem e tela cheia mantêm os controles translúcidos existentes.
- A faixa de dispositivos distingue papel de receptor e fonte. A bateria da fonte só é exibida para transmissor remoto ou ESP32, evitando repetir a mesma bateria quando a câmera é local.
- A câmera secundária continua em preview leve e a IA permanece exclusiva da fonte principal.

## Evolução 1.0.80 — ESP32, fontes e artefato Android

- `CameraEndpoint` passa a representar também ESP32 e persiste câmera disponível, sensores habilitados, calibração Hall, limites e intervalo de telemetria junto do cadastro protegido de endereço/chave.
- `Esp32SettingsScreen` centraliza conexão, teste, edição e aplicação do contrato em `POST /config`; `GET /status` continua sendo a verificação de disponibilidade.
- `VideoSourceType.esp32` reutiliza o transporte JPEG local (`/frame.jpg`) e a telemetria (`/status`), mas identifica corretamente o módulo em mensagens, status e histórico.
- Home, Monitor e Central de Câmeras consultam o mesmo `CameraRegistryService`. Somente ESP32 com `esp32CameraEnabled` pode entrar na composição visual.
- `MonitorController` continua exclusivo da fonte principal. `SecondaryCameraController` abre Local, RTSP, Celular remoto ou ESP32 com `emitFrames: false`, sem segundo pipeline de IA.
- Histórico exporta a mídia pelo mecanismo nativo já existente e mantém exclusão de índice, snapshot e clipe sob confirmação explícita.
- O workflow copia o APK assinado para o nome versionado e analisa o ZIP interno. O relatório mede bibliotecas por ABI, modelos, recursos e demais entradas antes de qualquer decisão de redução.
- Cache de Gradle e dos modelos reduz downloads repetidos; `compression-level: 0` evita tentar recomprimir um APK que já é compactado.

## Evolução 1.0.79 — Buildfix dos módulos e navegação

- extensões em arquivos `part` não chamam mais diretamente o membro protegido `State.setState`; `_MonitorScreenState` e `_MultiCameraScreenState` oferecem atualizadores privados usados pelos módulos;
- o intervalo estático da Central multicâmera é referenciado por `_MultiCameraScreenState._automaticRefreshInterval`, como exige o Dart 3.12;
- `_mainDestinations` volta a representar apenas as quatro áreas recorrentes: Início, Histórico, Monitor e Câmeras;
- `BikeModeScreen` não participa mais do índice compartilhado da navegação, evitando um destino sem ação útil;
- o Modo Bike continua sendo um modo operacional persistido por `AppLaunchModeService` e fica acessível pela seleção inicial ou por Configurações > Monitoramento.

## Evolução 1.0.78 — Monitor adaptativo e telemetria Bike

- `MonitorScreen` recebe opcionalmente uma segunda `VideoSourceConfig`; `monitor_screen_multicamera.dart` mantém uma única composição que escolhe área integral, empilhamento ou lado a lado conforme quantidade, orientação e largura.
- `SecondaryCameraController` mantém preview e estado da segunda fonte com `emitFrames: false`. Assim, somente a fonte principal alimenta o `MonitorController` e o pipeline de IA.
- `CameraRegistryService` continua sendo a origem dos cadastros. A Central multicâmera e o seletor do Monitor apenas compõem duas fontes já existentes.
- `BikeSensorSnapshot.fromEsp32Json` é o contrato de normalização para Hall, temperatura, pressões, bateria e distância; `BikeSensorService.applyEsp32Telemetry` é o ponto de entrada para a futura ponte física.
- `RemoteCameraServerService` inclui `bikeSensors` em `/status`; `RemotePhoneStatus` converte o payload e o receptor escolhe a telemetria conectada disponível.
- O guia inicial usa o marcador nativo `access_guide_completed_v2`. O Android não solicita mais a câmera em `onPostResume`, preservando explicação antes do pedido.
- `_PermissionReminderHost` detecta câmera ou rede local obrigatória removida após o onboarding e oferece revisão pontual, sem apagar o modo salvo.
- `CameraModeScreen` intercepta retorno superior e do sistema; se estiver transmitindo, confirma a parada e volta para `LaunchModeScreen`.

## Evolução 1.0.77 — Catálogo compilado de áudio

- `AudioResourceCatalog` mantém os 78 pares `slot -> R.raw.*` como referências Android compiladas.
- `MainActivity` não usa mais reflexão nem `Resources.getIdentifier`; o catálogo é injetado em `AlertAudioPlayer`.
- O player resolve o recurso pelo mapa recebido e distingue `slot_not_mapped` de `resource_id_zero` na telemetria.
- O diagnóstico publica `bundledResourceCount` e `bundledMissingSlots` para confirmar a cobertura no APK instalado.
- `verify_audio_resource_catalog.py` exige igualdade entre os slots Dart, as referências Kotlin e os M4A em `res/raw`.
- `bootstrap_android.sh` copia o catálogo junto com as demais fontes nativas ao recriar o projeto Android.

## Evolução 1.0.76 — Monitor explícito entre celulares

- `AppLaunchMode` adiciona `monitor`, mantendo compatibilidade com os valores anteriores.
- `_StartupGate` e `LaunchModeScreen` passam a abrir `MonitorConnectScreen` quando o modo salvo é Monitor.
- `MonitorConnectScreen` centraliza o papel do receptor: ler QR, preencher endereço/chave manualmente ou abrir a Central multicâmera.
- Ao iniciar o monitoramento por esse fluxo, a fonte é persistida como `VideoSourceType.remotePhone` e o `MonitorScreen` recebe essa origem diretamente.
- O contrato permanece o mesmo: o transmissor usa `CameraModeScreen` e envia imagem/status; o receptor executa IA, histórico, alertas, clipes e áudios.
- Modo Bike continua próprio, mas quando usar câmera remota segue a mesma decisão arquitetural do receptor.

## Evolução 1.0.75 — Falhas reais de áudio na telemetria

- `AlertAudioPlayer` mantém reprodução assíncrona e fila curta, mas o foco transitório passa a ser uma otimização: negação ou exceção é registrada e não impede a tentativa do `MediaPlayer`.
- Cada solicitação recebe um identificador local e gera eventos com slot, prioridade, tentativa, origem integrada/personalizada, fase, nome e tamanho do arquivo, volume, rota e latências. Caminhos privados completos não são exportados.
- `OnErrorListener` preserva os inteiros `what/extra` e também publica nomes estáveis para IO, conteúdo malformado, codec não suportado, timeout e erro de sistema.
- `NativePlatformService` persiste falhas na `ErrorLogService`; `AlertVoiceService` anexa o snapshot nativo ao evento que decide usar TTS.
- `DiagnosticReportService` e `PerformanceTelemetryService` incluem resumo humano e payload técnico. O JSON de desempenho usa `schemaVersion: 3`.
- A biblioteca integrada continua em AAC-LC/M4A mono 24 kHz. Um override inválido tenta o recurso integrado antes de devolver falha para o fallback TTS.

## Evolução 1.0.74 — Layout de transmissão e monitoramento

- Em paisagem, `MonitorScreen` remove a AppBar fixa e usa `extendBodyBehindAppBar`, mantendo controles em `_CompactMonitorTopHud`.
- `_CompactMonitorTopHud` concentra saída, tela cheia, voz, menu, estado da fonte, IA, detecções, preenchimento, telemetria dos aparelhos e HUD Bike no topo.
- A tela cheia ganhou saída explícita do monitoramento, separada da ação de sair apenas da tela cheia.
- `_buildPreviewLayer` força preenchimento em paisagem e tela cheia para reduzir faixas pretas e priorizar a câmera.
- `CameraModeScreen` passa a desenhar preview/estado parado em fundo integral, com barra superior translúcida e painel inferior/lateral conforme orientação.
- `_CameraStandbyPanel` substitui o ícone isolado de câmera desligada por um estado visual integrado ao aplicativo.
- O fluxo `AccessGuideScreen` → `LaunchModeScreen` continua obrigatório antes da Home/Monitor/Bike/Transmissão em instalações novas.

## Evolução 1.0.73 — Escolha inicial de modo

- `_StartupGate` continua respeitando o guia inicial de permissões antes de liberar o app.
- Depois do onboarding, `LaunchModeScreen` solicita a escolha entre Normal, Monitor, Bike e Transmissão quando ainda não há modo salvo.
- `AppLaunchModeService` persiste a escolha em `launch_mode.json`, no diretório de suporte do app.
- Em aberturas futuras, Normal leva à Home, Monitor leva ao fluxo receptor, Bike leva ao painel Bike e Transmissão leva ao Modo Câmera.
- Configurações > Monitoramento permite reabrir a seleção sem repetir o onboarding.
- A arquitetura mantém o transmissor dedicado à câmera; mapa/GPS e identificação futura de contexto Bike devem ser trabalhados no receptor.

## Evolução 1.0.72 — Buildfix e mini mapa futuro

- A entrega corrige apenas avisos do analisador encontrados no Android-APK-40, sem mudar o transporte de imagem.
- O status da câmera remota serializa telemetria não nula diretamente, mantendo o contrato de `/status`.
- O teste da câmera remota remove import redundante e preserva a regressão da consulta rápida.
- Se o mini mapa/GPS for implementado, a superfície principal deve existir no receptor/visualizador. O transmissor permanece dedicado à captura de câmera e pode enviar localização apenas como telemetria leve, separada dos quadros.

## Evolução 1.0.71 — Transporte remoto e estado operacional

- `RemoteCameraServerService` numera JPEGs, publica o timestamp em UTC, proíbe cache e responde `204` quando o receptor já possui o quadro mais recente.
- `RemotePhoneCameraSource` consulta a imagem em ciclo próprio de 250–400 ms; somente quadros novos são decodificados e publicados como `RgbFrame`, mantendo a cadência de recepção separada da IA.
- `_DeviceStatusStrip` permanece sobre o Monitor no retrato, paisagem e tela inteira. O receptor usa a telemetria local e o transmissor usa `/status` quando a fonte é outro celular; bateria e estado continuam disponíveis mesmo no perfil econômico.
- O toque na faixa abre `SessionStatusPanel`, onde continuam os detalhes de CPU, memória, temperatura, FPS, rede e histórico de saúde.
- O Android resolve os áudios padrão por `R.raw` antes do fallback dinâmico e expõe o identificador/erro de abertura no diagnóstico.

## Evolução 1.0.70 — Empacotamento e assinatura

- O pacote-fonte deve preservar arquivos ocultos necessários ao projeto, especialmente `.gitignore`.
- `.gitignore` protege `*.jks`, `*.keystore` e `android/key.properties`; a chave de assinatura permanece apenas nos Secrets do workflow.
- `verify_project.sh` continua rejeitando qualquer keystore incluída no código-fonte.

## Evolução 1.0.69 — Lint null-aware no serviço de fala

- `SpeechService._trace` usa entrada de mapa null-aware para o campo opcional de erro.
- O campo `error` continua ausente quando não há falha; não é serializado como `null` nem como texto vazio.
- A mudança atende `use_null_aware_elements` sem alterar a semântica da telemetria ou do áudio.


A 1.0.57 inicia a refatoração estrutural preventiva do projeto em lotes de três arquivos. O primeiro lote reduz a concentração no Monitor sem trocar contratos públicos: o controller mantém a orquestração enquanto responsabilidades internas e componentes de UI passam para módulos menores.


## Evolução 1.0.68 — Estabilidade de compilação

- o worker mantém uma referência não nula ao detector ativo após a inicialização e durante a troca de modelo;
- a janela de observação das regras usa `absenceReset` como base sem auto-referência;
- ajustes de lint mantêm o `flutter analyze` limpo sem mudar o comportamento funcional.

## Evolução 1.0.67 — Latência e ciclo de reprodução

- `DetectorInputBuffer` funde resize bilinear, letterbox e normalização em `ByteBuffer`; `FrameConverter` funde conversão, rotação e espelhamento. Coordenadas continuam sendo remapeadas por `DetectorImageTransform`.
- `object_detection_runtime.dart` gerencia interpreter/delegate/options e libera recursos na ordem correta. XNNPACK é uma solicitação de aceleração; operadores não delegados continuam na CPU. A escolha efetiva por operador não é medida.
- `DetectorRuntimePolicy` desconsidera a primeira execução e solicita o modelo leve depois de três execuções consecutivas >1.200 ms. Troca única por worker do detector; falha no modelo substituto mantém o anterior.
- `liteRtMs` mede apenas `invoke` via `lastInferenceDurationMicroseconds`. `tensorTransferMs` mede o restante da chamada `runForMultipleInputs`: cópias de entrada/saída e preparação interna da API. A nova semântica é identificada por `schemaVersion: 2`.
- `DetectionCadencePolicy` observa timestamps de captura dos frames analisados; janela = `clamp(2 × intervalo observado + 250 ms, 1.500 ms, 30.000 ms)`. Filtro, tracker, permanência e guarda compartilham a janela. A retenção visual de objetos ausentes permanece curta; a janela maior não inventa novas observações.
- Evidência forte dispensa apenas a confirmação genérica adicional; limiares, áreas, movimento e permanência continuam aplicados. Frames antigos não consomem a guarda de repetição de um futuro alerta recente.
- `AlertVoiceService` coordena arquivos e TTS, protege alta prioridade, mantém somente a próxima mensagem normal e invalida solicitações ao desligar voz. `AlertAudioPlayer` usa MediaPlayer assíncrono, USAGE_MEDIA, foco transitório, timeout e cache por atualização do APK.
- Retorno nativo `true` significa tratado: reproduzido, cancelado ou suprimido intencionalmente; `false` significa falha e permite TTS. Eventos nativos distinguem início, conclusão, erro e supressão. Não significa confirmação de que o usuário ouviu.
- `MonitorSystemUi` controla Insets/barras nativamente; `monitor_screen_fullscreen.dart` controla orientação, controles e Voltar. SafeArea protege controles, sem reduzir o vídeo em tela inteira.
- Troca/encerramento de fonte limpa candidatas, cadência e guarda. Resultados de gerações anteriores não entram na nova telemetria; o atraso de entrada corresponde ao próprio frame analisado.
- `SharedLocalCameraService` notifica a remoção do controller antes do dispose, aguarda a árvore se atualizar com timeout e descarta frames convertidos de gerações anteriores.
- Histórico de telemetria normal e captura profunda se sobrepõem. O relatório identifica o subconjunto escolhido, sem somar os dois conjuntos. Áudio mantém até 60 eventos nativos e 100 eventos de coordenação/TTS.


## Evolução 1.0.66 — Buildfix dos testes

- O `pipelineHotspot` continua comparando apenas as etapas locais granulares disponíveis em `SessionStatusData`.
- `primaryInferenceMs` permanece como métrica agregada/round-trip para compatibilidade e não é tratada como etapa local do hotspot.
- O teste do orçamento do pipeline foi alinhado a essa arquitetura e agora espera `Inferências auxiliares` no cenário fornecido.
- Não houve mudança de contrato nem de comportamento do pipeline nesta versão.



## Evolução 1.0.65 — Buildfix do analyze

- `NativePlatformService` remove dependência/import redundante de `dart:typed_data`, mantendo `Uint8List` via Flutter services.
- O teste de exportação reconhece que `DiagnosticReportService.export` retorna `String?`, pois o seletor nativo pode ser cancelado.
- O caminho com `directory` continua sendo obrigatório no teste e é validado antes de construir `File`.
- Não há alteração de contratos, pipeline de IA ou comportamento de exportação nesta versão.


## Evolução 1.0.64 — Telemetria de desempenho e superfícies adaptativas

- `RgbFrame` carrega tempo de conversão/decodificação da fonte e, quando disponível, transporte da origem remota.
- `ObjectDetectionService.detectMeasured` preserva a API `detect`, mas expõe métricas do round-trip; o worker mede materialização, criação da imagem, resize/letterbox, tensor, LiteRT puro e pós-processamento.
- `PerformanceTelemetryService` mantém uma janela de amostras da sessão, suporta diagnóstico profundo temporário e gera ZIP STORE com resumo humano, JSON e CSV sem incluir imagens.
- `SessionHealthAnalyzer` diferencia lentidão de captura/conversão, preparação do detector, LiteRT e orçamento total em vez de chamar todo o detector de “inferência”.
- exportações Android usam `MediaStore.Downloads` em `Downloads/Vigia IA` ou `ACTION_CREATE_DOCUMENT`; `ExportPreferencesService` persiste `Downloads` ou `Perguntar sempre`.
- `_StartupGate` consulta um marcador em `noBackupFilesDir`; atualização de uma instalação existente não reabre onboarding, enquanto instalação nova mostra o guia até a conclusão.
- `SessionStatusPanel` troca internamente entre resumo e detalhes para evitar bottom sheets empilhados; em paisagem o Monitor o apresenta em painel lateral.
- Central multicâmera, Histórico e Alertas/Clipes receberam densidade e composição específicas para largura ampla/baixa altura sem alterar regras funcionais.

## Evolução 1.0.63 — Limpeza pós-refatoração

- O `MonitorController` remove qualificadores `this.` redundantes nas fachadas que delegam para módulos `part`.
- A alteração atende ao lint `unnecessary_this` do Flutter 3.44.9 sem mudar resolução de métodos, estado ou contratos.
- O verificador passa a rejeitar novas ocorrências de `this._` no arquivo principal.

## Evolução 1.0.62 — Robustez do workflow Android

- O GitHub Actions invoca scripts de projeto com `bash ./tool/...` em vez de depender do bit executável Unix.
- A mudança cobre bootstrap Android, download do modelo TensorFlow Lite e verificação preventiva.
- Isso torna o pipeline compatível com ZIPs/importações que preservam conteúdo mas não metadados de permissão.
- O verificador passa a exigir essas invocações robustas para evitar regressão.

## Evolução 1.0.61 — Buildfix pós-refatoração

- O `MonitorController` não mantém mais as fachadas privadas `_refreshSessionTelemetry`, `_deliverAlert` e `_zonesDiagnosticContext`, pois a refatoração já direciona os chamadores para os métodos `*Impl` nos módulos `part`.
- A remoção elimina três `unused_element` sem deslocar estado nem alterar contratos públicos.
- `monitor_controller_session_support.dart`, `monitor_controller_event_support.dart` e `monitor_controller_state_support.dart` continuam sendo as implementações ativas dessas responsabilidades.

## Evolução 1.0.60 — Refatoração estrutural, lote 4

- `session_status.dart` permanece como contrato público de `SessionStatusData`, `SessionHealthSnapshot`, incidentes, issues e enums; `session_status_health_analyzer.dart` concentra as regras internas de classificação de saúde e gargalo.
- `system_health_screen.dart` mantém o ciclo de vida da tela, coleta periódica, persistência e ações; `system_health_screen_components.dart` concentra `_SummaryCard`, `_HealthTile` e componentes visuais relacionados.
- `object_detection_service.dart` mantém a fronteira pública assíncrona com isolate, carregamento de assets, fila e descarte; `object_detection_worker.dart` concentra inicialização do interpreter, inspeção do modelo, letterbox, inferência e conversão dos resultados.
- A divisão usa `part` para preservar membros privados e reduzir risco de alteração de contrato durante a refatoração.
- Os quatro lotes preventivos passam a cobrir 12 arquivos, mantendo cada entrega pequena e validável.

## Evolução 1.0.59 — Refatoração estrutural, lote 3

O terceiro lote aplica a mesma estratégia de modularização ao Status da sessão, à Central de diagnóstico e ao Histórico. Os arquivos principais continuam responsáveis por estado, ciclo de vida, filtros, ações e composição de alto nível; componentes visuais privados passam a módulos `part`, preservando acesso privado e contratos existentes.

- `session_status_panel_components.dart` concentra cards de vídeo, dispositivo, saúde, métricas, badges e helpers de apresentação;
- `error_center_screen_components.dart` concentra resumo operacional, grid de estado, chips e cards de registros;
- `events_screen_components.dart` concentra cards do histórico, thumbnails, estados vazio/erro e reprodução local de mídia;
- verificadores agora validam recursos distribuídos entre arquivo principal e módulo extraído, além de impor limites preventivos de tamanho.

A refatoração não altera persistência, filtros, TTC, alertas, diagnóstico, reprodução MP4 ou coleta de telemetria.


## Evolução 1.0.58 — Refatoração estrutural, lote 2

O segundo lote reduz três telas de crescimento rápido sem alterar seus contratos. `multi_camera_screen.dart`, `app_info_screen.dart` e `bike_mode_screen.dart` conservam estado, ações e navegação; componentes visuais privados passam a módulos `part` da mesma biblioteca, preservando acesso privado e reduzindo risco de regressão. Os novos módulos são `multi_camera_screen_components.dart`, `app_info_screen_components.dart` e `bike_mode_screen_components.dart`.

A estratégia mantém a mesma adotada no lote 1: arquivos de entrada menores, responsabilidades visuais isoladas e verificadores de tamanho para sinalizar crescimento futuro antes de voltar a concentrar centenas de linhas em uma única tela.

## Evolução 1.0.57

- `MonitorController` continua sendo a fachada/orquestrador, mas delega detalhes internos para `monitor_controller_session_support.dart`, `monitor_controller_event_support.dart` e `monitor_controller_state_support.dart`;
- os módulos são `part` da mesma biblioteca para preservar acesso aos membros privados e evitar duplicação de estado durante esta primeira etapa de extração;
- `MonitorScreen` mantém ciclo de vida e composição principal, enquanto widgets auxiliares ficam em `monitor_screen_components.dart`;
- `HomeScreen` mantém carregamento/persistência/navegação e move widgets auxiliares para `home_screen_components.dart`;
- wrappers curtos no controller preservam nomes e contratos internos usados pelo pipeline, reduzindo risco de regressão durante a refatoração;
- limites preventivos de linhas foram adicionados ao verificador para os três arquivos-alvo do lote 1;
- próximos lotes continuam em grupos de três arquivos, conforme a lista priorizada definida para o projeto.

## Evolução 1.0.56

- `BikeApproachEstimator` mantém rastreamento leve próprio para automóveis da inferência principal e calcula a derivada de `log(sqrt(area))`; para aproximação aproximadamente constante, o inverso dessa taxa fornece um TTC visual aproximado.
- O estimador exige associação espacial, crescimento mínimo, área mínima e confiança combinada antes de elevar o estado para aviso/crítico, reduzindo falsos positivos de uma única caixa ruidosa.
- `MonitorController` cria um conjunto de labels da inferência principal com os automóveis necessários ao Bike, mas continua passando apenas `_alertLabels` ao pipeline normal; assim segurança Bike e preferências comuns não se contaminam.
- O caminho rápido é executado antes das varreduras por movimento/detalhe. `BikeApproachBanner` pode ser notificado durante o restante do processamento e `_deliverAlert` é acionado imediatamente quando o risco cruza o limiar.
- O alerta usa cooldown por track e permite escalada imediata para crítico. A informação exibida é TTC aproximado; não são apresentados metros nem velocidade relativa física.
- `BikeModeConfig` persiste ativação e limiar de TTC; `BikeModeScreen` expõe controles e informa que radar FMCW permanece upgrade futuro.
- O cenário `vehicleApproaching` reutiliza o simulador atual de sensores e gera um TTC sintético no controller para validar o HUD e a saída de áudio sem hardware externo.
- Troca de fonte, reset de regras/sessão e mudança relevante do Bike limpam o estado temporal de aproximação para não carregar risco antigo.

## Evolução 1.0.55

- `AdaptiveMainScaffold` centraliza a decisão `NavigationBar` vs `NavigationRail`; `AdaptiveLayout` mantém os breakpoints em um único ponto.
- Home, Bike, Histórico e Multicâmera reutilizam o mesmo shell principal, evitando divergência de navegação entre orientações.
- `MonitorScreen` diferencia celular paisagem de tablet grande: o primeiro usa painel lateral sobreposto/recolhível; o segundo reserva uma coluna permanente.
- O preenchimento do vídeo é aplicado por escala sobre o preview existente; `DetectionOverlay` e `MonitoringZoneOverlay` calculam o retângulo visível com a mesma regra de cover/contain.
- `SessionStatusPanel` permanece um componente reutilizável, mas reorganiza saúde/vídeo e os dois dispositivos em duas colunas quando a largura permite.
- `BikeRideHud` reduz altura, tipografia e métricas quando a altura da janela é inferior a 500 dp.
- `SettingsScreen` mantém as mesmas rotas e serviços, apenas distribuindo as categorias em duas listas independentes em telas largas.
- Nenhum contrato de ESP32/BLE/Wi-Fi foi introduzido nesta etapa.

## Evolução 1.0.54

- `BikeSensorSnapshot` concentra velocidade, pressões, bateria, distância, temperatura opcional, conexão, origem e classificação de saúde dos sensores;
- `BikeSensorService` é a fonte única do HUD e hoje fornece apenas dados simulados; a UI não conhece detalhes de ESP32;
- `BikeModeConfig` persiste a ativação do simulador e o cenário escolhido;
- `BikeModeScreen` oferece controle explícito de teste sem hardware e atalho para abrir o Monitor;
- `BikeRideHud` é desenhado sobre o vídeo com fundos translúcidos, velocidade central, pneus nas laterais e alerta temporário quando necessário;
- `MonitorScreen` exibe o HUD quando existe snapshot de sensores disponível; o fluxo imersivo e a fonte de vídeo não foram alterados;
- a indicação `SIMULAÇÃO` impede que telemetria sintética seja interpretada como leitura real;
- `SessionStatusPanel` usa elemento de coleção null-aware para atender ao lint `use_null_aware_elements` do Flutter 3.44.9;
- nenhuma comunicação BLE/Wi-Fi com ESP32 foi implementada nesta versão.


## Evolução 1.0.53

- `AudioSettingsScreen` continua chamando o mesmo contrato `playCustomAlertAudio(slot)`, evitando impacto na UI e nos eventos existentes;
- `MainActivity.playCustomAlertAudio` mantém a prioridade `override → padrão`;
- o caminho padrão deixou de usar `setDataSource(context, android.resource://...)`, que falhava em alguns aparelhos ao preparar M4A;
- `copyBundledAlertToCache` lê `resources.openRawResource(resourceId)`, cria uma cópia privada íntegra e a entrega ao mesmo fluxo `setDataSource(caminho) + prepare()` já usado para overrides;
- a cópia temporária reduz risco de cache parcial e é refeita quando o áudio é solicitado, portanto atualizações do APK não ficam presas a uma cópia antiga;
- `tool/android/MainActivity.kt` e a árvore Android gerada permanecem idênticos para que `bootstrap_android.sh` não reintroduza a implementação antiga;
- os 78 M4A e seus IDs não foram modificados.


## Evolução 1.0.52

- `MonitorController` mede separadamente o custo síncrono anterior ao detector, a inferência principal, inferências auxiliares, o pós-processamento e o tempo total do frame;
- `SessionStatusData` expõe essas medidas, calcula uso/folga do orçamento e identifica a etapa local de maior custo sem depender da UI;
- `AnalysisBudgetPolicy` recebe intervalo efetivo, tempo já gasto e estimativa da próxima inferência e decide apenas se uma varredura opcional de detalhe cabe no orçamento;
- foco por movimento e inferência principal continuam funcionando como antes; o guard de orçamento atua no detail scan periódico para evitar que um refinamento secundário atrase a próxima análise;
- `SessionHealthAnalyzer` usa o tempo total do pipeline para indicar aproximação/estouro do orçamento além das métricas já existentes de inferência e frames perdidos;
- `VideoSessionDetailsPanel` concentra as novas métricas, preservando o card de vídeo compacto na superfície principal;
- contadores/timings são reiniciados junto com as demais métricas da sessão;
- fluxo imersivo do Bike e qualquer contrato com ESP32 continuam fora desta etapa.


## Evolução 1.0.51

- `SessionHealthAnalyzer` interpreta `SessionStatusData` sem depender da UI e produz `SessionHealthSnapshot`, permitindo reutilização futura no Modo Bike;
- os limites de frame antigo/congelado usam `expectedFrameIntervalMs`, derivado do intervalo efetivo da fonte, para manter o diagnóstico coerente com perfis de energia e análise;
- `MonitorController` separa `_framesDroppedProcessing` de `_framesSkippedOptimization`; apenas o primeiro participa do cálculo de saturação da IA;
- o controller mantém até oito `SessionHealthIncident` em memória por sessão e reinicia o histórico junto com as métricas ao trocar/reiniciar a fonte;
- `SessionStatusPanel` mostra estado, resumo, gargalo provável e ocorrências recentes; `VideoSessionDetailsPanel` continua concentrando os números de vídeo;
- temperatura, RAM e CPU podem sinalizar pressão de recursos, mas a análise de rede/captura/IA continua baseada em métricas diretamente observadas;
- o fluxo imersivo do Bike e qualquer contrato com ESP32 continuam fora desta etapa.

## Evolução 1.0.50

- `SessionStatusData` mantém o mesmo contrato e comportamento, mas suas strings de resolução e atraso usam interpolação Dart sem chaves redundantes;
- a alteração remove os avisos `unnecessary_brace_in_string_interps` vistos no Flutter 3.44.9;
- nenhum fluxo do Modo Bike, endpoint remoto, telemetria ou integração futura com ESP32 foi alterado.

## Evolução 1.0.49

- `SessionStatusData` é um modelo de apresentação independente da tela, permitindo reutilizar o mesmo contrato no Monitor atual e em uma futura superfície do Modo Bike;
- `SessionStatusPanel` recebe apenas esse modelo, separa `Este celular` de `Celular remoto` e mantém os detalhes de vídeo em `VideoSessionDetailsPanel`;
- `MonitorController` mede FPS recebido e FPS efetivamente inferido separadamente, resolução, contadores de frames, tempo de inferência e atraso entre captura e recebimento;
- a telemetria local é atualizada periodicamente durante a sessão sem depender da ativação do Bike;
- `RemoteCameraServerService` coleta telemetria também no uso normal do Modo Câmera e envia o timestamp do JPEG em `x-vigia-frame-captured-at`;
- `RemotePhoneCameraSource` preserva esse timestamp no `RgbFrame` e mede a latência da requisição de frame;
- `DeviceTelemetrySnapshot` ganha `connectionType`, preenchido no Android com `ConnectivityManager`/`NetworkCapabilities`;
- a política do Bike continua respeitando `keepRemoteTelemetry` quando o Bike estiver ativo e nenhuma integração ESP32 foi introduzida.

## Evolução 1.0.48

- `custom_audio/` passa a armazenar a biblioteca padrão em AAC/M4A mono 24 kHz, preservando os mesmos 78 IDs do `AudioSlotCatalog`;
- `bootstrap_android.sh` continua sendo a origem de reconstrução de `res/raw` e copia os M4A sem alterar o contrato dos slots;
- `MainActivity.playCustomAlertAudio` mantém prioridade `override → padrão`, mas o padrão é aberto por URI `android.resource://` com `AudioAttributes` de sonificação/fala;
- importações personalizadas continuam independentes do formato da biblioteca padrão e usam o armazenamento privado do aplicativo;
- `AudioSettingsScreen` usa uma única `Row` para Ouvir/Trocar/Gravar; os três botões dividem a largura e reduzem internamente sem quebrar rótulos;
- a restauração de override deixa a linha principal e passa ao cabeçalho do card, mantendo o layout estável em retrato.

## Evolução 1.0.47

- `.github/workflows/android-apk.yml` reconstrói a keystore em `$RUNNER_TEMP` a partir de `ANDROID_KEYSTORE_BASE64` e valida store/alias com `keytool`;
- o build release recebe `ANDROID_KEYSTORE_PATH`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` e `ANDROID_KEY_PASSWORD` apenas no passo de compilação;
- `bootstrap_android.sh`, que recria a pasta `android/`, injeta `signingConfigs.release` no Gradle recém-gerado e impede o fallback para `debug`;
- nenhuma credencial ou keystore é persistida no código-fonte; `.gitignore` cobre extensões de chave e `android/key.properties`;
- o workflow executa `apksigner verify --verbose --print-certs` na APK antes do upload;
- a identidade Android continua `com.vigiaia.app`; a mudança é somente da assinatura criptográfica usada em release.

## Evolução 1.0.46

- `AudioSettingsScreen` substitui `Icons.person_voice_outlined` por `Icons.mic_rounded`, removendo o bloqueio do `flutter analyze`;
- nenhum contrato de `AudioSlotCatalog`, ponte Android, armazenamento de overrides ou reprodução foi alterado;
- a verificação preventiva registra a incompatibilidade para evitar regressão em futuras entregas.

## Evolução 1.0.45

- `AudioSlotCatalog` é a fonte única dos 78 IDs, títulos, frases, grupos e marcação de recursos futuros;
- `MonitorController` usa `AudioSlotIds` para os 14 eventos atuais, reduzindo strings duplicadas e preparando novos módulos para reutilizar a mesma API;
- `MainActivity` procura primeiro um override em `filesDir/audio_overrides`, depois o recurso `res/raw` do slot; falha no override não impede o fallback padrão;
- importação usa `ACTION_OPEN_DOCUMENT` e copia o áudio para o armazenamento privado, sem pedir acesso amplo a arquivos;
- gravação usa `MediaRecorder` AAC/M4A e solicita `RECORD_AUDIO` apenas quando o usuário toca em Gravar;
- `AudioSettingsScreen` concentra prévia, importação, gravação, restauração individual e restauração total, com busca e grupos;
- `custom_audio/` permanece como origem estável do build e passa a conter os 78 WAVs padrão;
- os 64 slots Bike/ESP32 são apenas reservados nesta versão: não são disparados até a integração real de sensores/atuadores.

## Evolução 1.0.44

- `MainNavigationBar` ganha um quinto destino `Bike`, mantendo o mesmo componente compartilhado por Início, Histórico e Câmeras;
- `BikeModeScreen` passa a usar a própria barra principal com `currentIndex: 4`;
- os manipuladores de navegação das telas principais reconhecem o índice Bike e abrem `BikeModeScreen`;
- o antigo tile em `SettingsScreen` é removido para não esconder nem duplicar a entrada do modo operacional;
- a mudança é apenas de navegação/exposição: `BikeModeService`, perfis de energia, telemetria e painel remoto permanecem com o mesmo contrato.

## Evolução 1.0.43

- `RemotePhoneStatus.fromJson` usa diretamente o `Map` já promovido pelo teste de tipo, sem cast redundante;
- `RemotePhoneCameraSource._pollStatus` faz o mesmo após validar o JSON decodificado;
- não há mudança de contrato no `/status`, no frame JPEG, nos avisos do Modo Bike ou na persistência;
- o buildfix existe para manter o workflow limpo sob `flutter analyze` no Flutter 3.44.9.

## Evolução 1.0.42

- `RemoteCameraServerService` acrescenta FPS aproximado, limite/estado do alerta de bateria e telemetria ao `/status` autenticado já existente;
- `RemotePhoneCameraSource` mantém polling independente de frame e status; indisponibilidade de telemetria é não fatal para o vídeo;
- `RemotePhoneStatus` normaliza o estado recebido e concentra critérios de aviso para bateria, temperatura, CPU, RAM e atualização atrasada;
- `DeviceTelemetrySnapshot.fromJson` preserva `capturedAt`, permitindo diferenciar o instante da coleta no traseiro do instante em que o receptor recebeu o status;
- `MonitorController` observa a telemetria da fonte remota e propaga mudanças ao mesmo `ChangeNotifier` usado pelo monitor;
- `RemoteBikeStatusPanel` apresenta energia, brilho, CPU, memória, FPS, latência, perfil e alertas no celular da frente;
- `MonitorScreen` exibe resumo compacto e badge de avisos, mantendo os detalhes sob demanda para não ocupar permanentemente a imagem.

## Evolução 1.0.41

- `BikeModeConfig` passa a calcular intervalo efetivo, teto de FPS, frequência de telemetria, brilho e política JPEG por perfil;
- `MonitorController` carrega a política do Modo Bike, reinicia a fonte somente quando o intervalo efetivo muda e mantém o mesmo pipeline de IA/detecção;
- `MonitorLanStreamService` limita codificações por FPS e recebe largura/qualidade JPEG adaptativas;
- `RemoteCameraServerService` usa a mesma política no Modo Câmera, incluindo intervalo, compressão, brilho e telemetria;
- `DeviceTelemetrySnapshot` normaliza a coleta nativa de bateria/carga, temperatura, brilho, CPU e memória;
- `NativePlatformService` mantém a ponte Android para telemetria e brilho do app sem alterar o brilho global do sistema;
- `MainActivity` calcula CPU do processo entre amostras, memória disponível/total, corrente aproximada de bateria e estado de tela;
- endpoints `/status` locais carregam `device`, `bikeMode` e `bikeProfile` quando aplicável, sem mudar o contrato do frame JPEG;
- alerta de bateria baixa é avaliado de forma periódica e possui histerese simples para não repetir até a carga subir alguns pontos.

## Evolução 1.0.40

- `BikeModeConfig` concentra ativação, perfil energético e preferências do aparelho traseiro;
- `BikeModeService` persiste a configuração separadamente no armazenamento privado, sem quebrar perfis antigos do monitor;
- `BikeModeScreen` é a entrada dedicada em Configurações → Monitoramento e foi construída com layout rolável/responsivo;
- os perfis expõem metas de intervalo de análise e FPS, mas a 1.0.40 ainda não altera o pipeline em execução; essa integração fica isolada para a próxima etapa;
- telemetria remota está configurável nesta etapa, mas coleta/transmissão dos dados do aparelho será conectada na próxima evolução.

## Evolução 1.0.39

- `AccessGuideScreen` concentra a explicação inicial das permissões e consulta os estados reais via `NativePlatformService`;
- `HomeScreen` e `MonitorScreen` reutilizam `PhonePairingScannerScreen` + `RemoteCameraPairingService` para preencher endereço/chave do outro celular por QR;
- `PartialPersonDetectionService` é uma heurística auxiliar, nunca substitui o detector TFLite principal e só atua quando não existe pessoa já detectada;
- `MonitorController` mantém memória visual curta de alertas por família, caixa, aparência e ID para suprimir fala duplicada após reidentificações pequenas;
- seleção visual da fonte usa ícone de seleção em vez de propriedades `Radio` obsoletas, garantindo compatibilidade com Flutter 3.44.

Princípios mantidos:

- processamento local sempre que possível;
- uma única origem de verdade para configurações persistidas;
- nenhum pipeline paralelo de IA por recurso;
- compatibilidade com dados antigos;
- falha segura para credenciais;
- Android como plataforma inicial;
- UI simples em retrato e paisagem;
- documentação e verificação preventiva por versão.

## 2. Camadas

### `lib/sources`

Implementa `VideoSource`:

- `LocalCameraSource` — cliente da câmera compartilhada do aparelho;
- `RtspCameraSource` — stream RTSP;
- `RemotePhoneCameraSource` — JPEGs do Modo Câmera na rede local.

Todas entregam `RgbFrame` e `VideoSourceStatus` ao mesmo controlador.

### `lib/controllers`

`MonitorController` coordena:

1. fonte de vídeo;
2. buffer de clipe;
3. integridade da câmera;
4. movimento;
5. recorte/união das áreas;
6. inferência LiteRT;
7. filtro de objetos;
8. remapeamento das caixas;
9. rastreamento;
10. transições por área;
11. Regras Inteligentes;
12. anti-repetição;
13. Histórico;
14. alertas;
15. clipe associado;
16. persistência do estado de runtime.

### `lib/services`

Serviços principais:

- `ObjectDetectionService` — inferência local com EfficientDet-Lite0 e fallback SSD;
- `DetectorImageTransform` — letterbox e remapeamento de caixas;
- `DetectionConfidencePolicy` — limiares de candidatura por grupo;
- `TemporalDetectionFilter` — confirmação temporal/hold curto;
- `DetectionMerger` — união sem duplicatas da passagem normal e focada;
- `MotionDetectionService` — movimento por luminância + diferença RGB e regiões de foco;
- `ObjectAppearanceService` — assinatura visual leve de cor para reidentificação;
- `MonitoringZoneService` — áreas e recortes;
- `ObjectTracker` — IDs e entrada/saída;
- `SmartAlertRuleEngine` — permanência e regras por grupo;
- `AlertRepeatGuard` — confirmação e anti-repetição;
- `ClipRecorderService` — buffer + MP4/GIF;
- `EventHistoryService` — persistência de eventos/mídias;
- `AlertDeliveryService`/`SpeechService`/`NativePlatformService` — canais de alerta;
- `AppSettingsService` — perfil persistente e migração;
- `SharedLocalCameraService` — único proprietário do `CameraController`, com múltiplos clientes e reinício coordenado;
- `RemoteCameraServerService` — servidor do Modo Câmera, reutilizando a câmera compartilhada;
- `MonitorLanStreamService` — servidor web do monitor ativo com sessão temporária, status real e quadros JPEG na mesma rede;
- a Saúde/Diagnóstico tratam servidor HTTP, frame LAN recente e transmissão operacional como estados diferentes;
- `CameraRegistryService` — Central multicâmera;
- `BackgroundMonitorService` — bridge do Foreground Service/recuperação e heartbeat Flutter;
- `SystemUiService` — edge-to-edge global e modo imersivo nas telas de câmera;
- `StorageManagementService` — uso e limpeza;
- `BackupExportService` — backup/restauração/exportação;
- `StatisticsService` — agregações locais;
- `CameraIntegrityService` — obstrução/mudança brusca de cena;
- `RuntimeHealthService` — métricas de runtime;
- `MonitoringPresetService` — aplicação de presets.

## 3. Pipeline

```text
LocalCameraSource ---------\
RtspCameraSource -----------+--> RgbFrame
RemotePhoneCameraSource ----/       |
                                   +--> ClipRecorderService (buffer)
                                   |
                                   +--> CameraIntegrityService
                                   |
                                   v
                          MotionDetectionService
                           /               \
                          v                 v
                 união das áreas       região de foco
                          |                 |
                          v                 |
                ObjectDetectionService <---+ (2ª passagem só se necessária)
                          |
                          v
           letterbox/remapeamento + DetectionMerger
                          |
                          v
              DetectionConfidencePolicy
                          |
                          v
                TemporalDetectionFilter
                          |
                          v
              remapeamento + filtro por zonas
                          |
                          v
                  ObjectFilterPolicy
                              /          \
                             v            v
                       ObjectTracker   SmartAlertRuleEngine
                             |            |
                   entrada/saída          v
                             |      AlertRepeatGuard
                             \            /
                              v          v
                            EventHistoryService
                                   |
                      Alert/TTS/Notification
                                   |
                            ClipRecorderService
                                   |
                              MP4 ou GIF
```

## 4. Clipes MP4

`ClipRecorderService` não cria uma segunda captura de câmera. Ele reaproveita frames de análise já recebidos.

No Android:

- frames RGB são reduzidos para um tamanho seguro;
- `NativePlatformService.encodeMp4` envia os frames pelo MethodChannel;
- `MainActivity` converte RGB para YUV420;
- `MediaCodec` codifica AVC/H.264;
- `MediaMuxer` finaliza o MP4;
- somente depois do `muxer.stop()/release()` o arquivo é validado;
- falha no encoder retorna ao GIF quando permitido.

O Histórico persiste apenas o caminho do clipe associado e aceita arquivos antigos em GIF.

## 5. Alertas

`MonitorSettings.alertOutputs` substitui o antigo comportamento binário de voz por saídas independentes:

- voz;
- som;
- vibração;
- notificação Android.

`AlertMessages` resolve mensagens gerais e específicas. A chave de override usa:

```text
<label>|<nome da área>
<label>|*
```

A UI traduz as classes para português e não exige que o usuário conheça os labels do modelo.

## 6. Rastreamento e anti-repetição

O `ObjectTracker` calcula candidatos entre tracks e detecções da mesma classe. A pontuação combina:

- IoU com caixa prevista;
- distância entre centros;
- mudança de tamanho;
- idade do track.

A caixa prevista usa velocidade estimada. Na primeira observação válida de movimento, o vetor é inicializado diretamente com a velocidade medida; somente as medições seguintes recebem suavização exponencial. Isso evita atrasar artificialmente a direção inicial e reduz trocas de ID quando dois objetos começam a se cruzar. Os candidatos são ordenados globalmente e cada track/detecção só pode ser usado uma vez por frame.

Quando existe track, a chave enviada ao `AlertRepeatGuard` é:

```text
classe#trackId
```

Sem rastreamento disponível, o comportamento legado por classe é mantido.

## 7. Modo Câmera e Central multicâmera

### Modo Câmera

`RemoteCameraServerService`:

- abre `LocalCameraSource`;
- converte frames para JPEG;
- publica `/status` e `/frame.jpg` em `InternetAddress.anyIPv4`;
- exige chave aleatória por sessão;
- não possui descoberta/cloud obrigatória.

### Central

`CameraRegistryService` mantém endpoints localmente. RTSP/endereço/chave persistidos passam por `NativePlatformService.protectSecret` no Android.

`RemotePhoneCameraSource` busca `/frame.jpg`, converte JPEG para RGB e entrega o mesmo `RgbFrame` usado pelas demais fontes.

## 8. Persistência e migração

`AppSettingsService` usa um único `PersistedMonitorProfile`.

Schema atual: `version: 7`.

Compatibilidade:

- ausência de campos novos usa defaults;
- `voiceEnabled` antigo é aceito como fallback de migração;
- GIFs antigos continuam válidos;
- perfil sem preset vira `custom`;
- perfil sem política de armazenamento recebe valores padrão;
- seleções antigas de classes são normalizadas para Pessoas, Automóveis e Animais.

### Credenciais

Ao persistir no Android:

- `source.rtspUrl` sensível é removido do JSON normal;
- a informação é cifrada como `rtspSecret`;
- a chave AES pertence ao `AndroidKeyStore`;
- modo usado: AES/GCM/NoPadding;
- falha do Keystore não salva Base64 como substituto.

Backups portáteis usam `exportPortableProfile()` e removem credenciais.

## 9. Segundo plano e recuperação

`MonitoringForegroundService` representa a sessão nativa de segundo plano e retorna `START_STICKY`. A presença do serviço, porém, não é considerada prova de monitoramento: um heartbeat vindo do Flutter expira após 15 s e a Saúde ainda exige frames recentes. Se o processo Dart deixar de responder, a notificação passa para estado de atenção e aciona recuperação assistida; após 1 minuto sem heartbeat, o serviço órfão usa `stopSelf()` e libera o wake lock.

`BackgroundMonitorService` mantém leases em memória para Monitor e Modo Câmera. O serviço só é encerrado quando nenhum consumidor precisa dele; o tipo efetivo é `FOREGROUND_SERVICE_TYPE_CAMERA` enquanto houver ao menos um consumidor de câmera e `FOREGROUND_SERVICE_TYPE_SPECIAL_USE` quando restarem apenas fontes sem câmera. Isso evita que uma tela derrube o foreground service pertencente à outra.

`AppSettingsService.saveProfile()` sincroniza `backgroundMonitoringEnabled` e a agenda com a camada nativa.

`MonitorRecoveryReceiver` recebe:

- `BOOT_COMPLETED`;
- `MY_PACKAGE_REPLACED`;
- pedido explícito disparado pelo serviço quando a tarefa é removida.

Se a agenda permitir, o receiver cria uma notificação de recuperação. O toque abre `MainActivity` com `resume_monitor=true`. `HomeScreen` consome a solicitação por `BackgroundMonitorService.consumeResumeRequest()` e inicia o fluxo normal.

Essa arquitetura respeita a limitação de Android moderno: não promete abrir câmera silenciosamente quando o sistema exige interação do usuário.

## 10. Armazenamento e backup

`StoragePolicy` contém:

- `autoCleanup`;
- `retentionDays`;
- `maxStorageMb`.

`EventHistoryService.applyStoragePolicy()` remove primeiro eventos expirados e, se necessário, os mais antigos até ficar dentro do limite. Clipes compartilhados só são removidos quando deixam de ser referenciados.

`BackupExportService`:

- cria backup JSON portátil das configurações;
- restaura perfil portátil;
- exporta `eventos.json`;
- copia fotos e clipes associados para a pasta de exportação.

## 11. Saúde e integridade

`RuntimeHealthService` mantém dados de sessão: fonte, IA, FPS, segundo plano e estado da câmera.

`NativePlatformService.systemHealth` obtém do Android:

- bateria;
- temperatura da bateria;
- memória PSS;
- armazenamento livre/total.

`CameraIntegrityService` cria uma grade de luminância reduzida e acompanha:

- escuridão persistente → possível obstrução;
- diferença brusca da cena base → possível deslocamento.

Existe cooldown para impedir repetição excessiva. Os eventos são gravados no Histórico e usam as mesmas saídas de alerta configuradas pelo usuário.

## 12. Estatísticas e presets

`StatisticsService` agrega o Histórico em memória por período, objeto, área, câmera e hora.

`MonitoringPresetService` altera somente parâmetros definidos pelo preset. Fonte, áreas e objetos escolhidos permanecem preservados.

## 13. Interface

A arquitetura visual 1.0.17 permanece:

- Home/dashboard;
- Eventos;
- Monitor;
- Diagnóstico;
- Ajustes.

Novas funções são expostas em Ajustes por cartões diretos:

- Alertas e clipes;
- Modo Câmera;
- Central multicâmera;
- Presets;
- Estatísticas;
- Armazenamento e backup;
- Saúde do Sistema;
- Sobre/Mudanças/Doações.

O monitor ao vivo continua removendo a navegação inferior para priorizar vídeo e possui layout próprio em paisagem.

## 14. Identidade futura

`app_identity.json` é o ponto de referência para a futura troca de nome/identidade. Ele registra:

- `displayName`;
- `projectName`;
- `applicationId`;
- `namespace`.

Nesta versão esses valores continuam os atuais. A troca definitiva só deve acontecer quando o novo nome for escolhido e deverá ser feita de forma sincronizada em Flutter, Android, workflow e documentação.

## 15. Android nativo preservável

A pasta `tool/android/` contém as versões canônicas de:

- `MainActivity.kt`;
- `MonitoringForegroundService.kt`;
- `MonitorRecoveryReceiver.kt`.

`tool/AndroidManifest.xml` é a fonte canônica do Manifest.

`tool/bootstrap_android.sh` recria a plataforma com o template do Flutter e reaplica esses arquivos somente como recuperação quando a estrutura Android versionada estiver incompleta. No caminho normal do CI, `android/` é reutilizado para não invalidar trabalho e caches desnecessariamente.

## 16. Verificação e CI

`tool/verify_project.sh` valida regressões estruturais, a presença das funções 1.0.18, as correções de build 1.0.19 e a inicialização de velocidade do rastreador corrigida na 1.0.20.

O workflow `.github/workflows/android-apk.yml` executa:

1. setup de Java, Flutter e Gradle 9.1.0 com cache;
2. reutilização do projeto Android versionado, chamando o bootstrap apenas se a estrutura estiver incompleta;
3. obtenção do modelo quando necessário e `flutter pub get`;
4. `tool/verify_project.sh`, `flutter analyze` e `flutter test --coverage`;
5. uma única `gradle :app:assembleRelease --build-cache --parallel` com `VIGIAIA_CI_MULTI_APK=1`;
6. leitura de `output-metadata.json`, validação/nomeação do universal e das três ABIs;
7. verificação de assinatura e publicação dos APKs na GitHub Release.

Testes não devem ser alterados apenas para esconder falhas.



### Identidade técnica e correção de build 1.0.28

- pacote Flutter/Dart: `vigiaia`;
- namespace/applicationId Android: `com.vigiaia.app`;
- package Kotlin: `com.vigiaia.app`;
- MethodChannels: `vigiaia/background` e `vigiaia/native`;
- protocolo de pareamento: `vigiaia://pair`;
- identificadores e artifacts usam a forma técnica `vigiaia`;
- lint do `BackgroundMonitorService` corrigido sem depender de sintaxe experimental;
- import redundante do stream LAN removido.

### Transmissão LAN do monitor 1.0.27

- `MonitorController` cria uma única instância de `MonitorLanStreamService` por sessão de monitoramento.
- Após a fonte iniciar, o servidor seleciona um IPv4 local/privado de Wi-Fi/Ethernet e escuta diretamente nesse endereço na porta `8766`, evitando anunciar ou vincular a transmissão a uma interface celular/VPN.
- `_onFrame` envia o mesmo `RgbFrame` para o encoder JPEG do servidor antes da inferência; se o encoder ainda estiver ocupado, o quadro de rede é descartado em vez de criar fila e prejudicar a IA.
- `/stream.mjpg` entrega MJPEG; `/frame.jpg`, `/status` e a página `/` usam a mesma chave aleatória de sessão.
- O navegador remoto não recebe credenciais RTSP nem configurações do app, apenas o JPEG já produzido para transmissão.
- `_stopSourceUnlocked` encerra o servidor LAN, portanto o link expira ao parar/trocar a fonte ou sair do horário.
- A falha do servidor LAN é isolada do pipeline principal: câmera, detecção e alertas continuam funcionando.
- Android 17 usa `ACCESS_LOCAL_NETWORK` quando o app estiver sujeito à exigência; Android 16 pode solicitar `NEARBY_WIFI_DEVICES` quando a proteção de rede local bloquear sockets.

### Permissões e segundo plano 1.0.26

- `MainActivity` solicita `CAMERA` uma vez na primeira abertura e expõe revalidação pelo MethodChannel.
- `HomeScreen`, `MultiCameraScreen` e `CameraModeScreen` revalidam a permissão antes de abrir câmera local.
- `POST_NOTIFICATIONS` é solicitado quando o usuário ativa um fluxo que depende da notificação persistente; negar não mascara a condição.
- `MonitorController` inicia o foreground service antes da câmera quando Segundo plano está habilitado, mantém heartbeat de frames e tenta recuperar uma câmera local que ficou sem frames.
- Ao minimizar/bloquear, o monitor não descarta a fonte quando Segundo plano está ativo. Ao retornar, serviço e frames são revalidados.
- `PARTIAL_WAKE_LOCK` mantém CPU disponível sem manter a tela ligada.
- `MonitorRecoveryReceiver` continua sendo recuperação assistida; não abre câmera silenciosamente após boot.


## Detecção multiescala e reaquisicao 1.0.36

O caminho principal continua sendo uma única inferência sobre o frame preservado por letterbox. A 1.0.36 acrescenta três camadas de recuperação:

1. **Filtro de classes no worker** — `ObjectDetectionService.detect(... allowedLabels)` remove classes não monitoradas antes de `maxResults`, evitando que cadeiras, mochilas ou outros objetos COCO escondam classes úteis no ranking.
2. **Foco por componentes de movimento** — `MotionDetectionResult.focusRegions()` separa blobs distantes. Se a passagem principal falhar, até duas regiões podem ser testadas, interrompendo assim que uma detecção útil reaparece.
3. **Varredura detalhada espaçada** — `DetectionScanPlanner` roda no máximo um recorte adicional a cada ~1,6 s quando não houve passagem focada. Primeiro tenta reaquirir uma detecção recentemente perdida; sem alvo anterior, alterna dois tiles sobrepostos de paisagem/retrato para aumentar a resolução efetiva de objetos pequenos.

`DetectionConfidencePolicy` usa classe + área da caixa. Quanto menor a caixa, maior a margem permitida abaixo do limiar principal, mas candidatos muito pequenos exigem três observações coerentes. `TemporalDetectionFilter` usa retenção adaptativa curta para oclusões e `DetectionMerger` consolida duplicatas da mesma família somente com sobreposição alta.

A estratégia evita simplesmente trocar para um modelo pesado ou executar mosaico completo em todos os frames, preservando a operação offline e o consumo de um aparelho móvel.

## Detecção adaptativa 1.0.34

`ObjectDetectionService` tenta carregar `efficientdet_lite0.tflite` primeiro e só recorre a `ssd_mobilenet_v1.tflite` se o modelo principal não puder ser usado. Ambos precisam expor entrada RGB `[1,H,W,3]` e as quatro saídas de `DetectionPostProcess` (caixas, classes, scores e quantidade). O diagnóstico registra qual modelo foi realmente inicializado.

Antes da inferência, `DetectorImageTransform` redimensiona preservando proporção e centraliza o conteúdo no tensor do modelo. As caixas retornadas são convertidas de volta ao espaço normalizado do frame original; detecções que caiam apenas no padding são descartadas.

O limiar configurado pelo usuário continua sendo o nível de confiança forte. `DetectionConfidencePolicy` permite candidatas ligeiramente abaixo dele por grupo, e `TemporalDetectionFilter` exige recorrência espacial antes de promovê-las. Assim, o ganho de sensibilidade não equivale a aceitar diretamente qualquer score baixo.

Quando **Somente movimento** está ativo, uma cena sem movimento não zera mais as detecções. O controller faz uma inferência de presença a cada 800 ms e preserva brevemente uma detecção confirmada entre falhas transitórias. Movimento recente continua sendo necessário para gerar alertas nesse modo.

Se houver movimento localizado e a passagem principal não encontrar candidato útil, `focusRegion()` produz um recorte limitado da cena. Esse recorte é ampliado para uma segunda inferência e depois remapeado/mesclado, favorecendo objetos pequenos ou distantes sem dobrar permanentemente o custo de CPU.

O schema 7 reduz apenas os antigos tempos padrão das Regras Inteligentes (veículo 600 ms, animal 800 ms e outros 1,2 s). Valores personalizados salvos pelo usuário não são substituídos.

## Identidade e aparência 1.0.25

- `AppMetadata.name`, `MaterialApp.title`, `android:label` e textos nativos usam **Vigia IA**.
- `app_identity.json` registra o nome público definitivo e documenta a preservação dos identificadores Android legados.
- `AppearanceSettingsService` usa `AppThemePreference.dark` como valor inicial e como fallback quando o arquivo de preferência estiver inválido.
- Usuários que já escolheram Sistema, Claro ou Escuro continuam com a configuração persistida; a mudança de padrão vale para instalações sem preferência anterior.
- A identidade pública foi introduzida em `1.0.25+25`; a identidade técnica foi concluída em `1.0.28+28`.

## Interface e domínio de detecção 1.0.24

`ObjectFilterCatalog` define a fronteira entre as classes internas dos detectores COCO (EfficientDet-Lite0 principal e SSD MobileNet fallback) e o domínio exposto ao usuário:

- `person` → **Pessoa**;
- `car`, `motorcycle`, `bus`, `truck` → **Automóvel**;
- `bird`, `cat`, `dog`, `horse`, `sheep`, `cow` → **Animal**.

As demais classes podem permanecer no `labelmap.txt` e na saída bruta do modelo, mas são descartadas por `ObjectFilterPolicy` antes de alertas, rastreamento visual e novos eventos. A leitura de configurações antigas chama `normalizeSelection`, expandindo uma seleção legada para o grupo atual correspondente.

### Histórico versus Diagnóstico

`EventsScreen` é o Histórico de passagem e aceita somente eventos cujo `label` pertence aos três grupos. Obstrução, deslocamento e falhas técnicas não são adicionados ao Histórico pelo `MonitorController`; os avisos técnicos continuam no `ErrorLogService`/Diagnóstico. `StatisticsService` usa a mesma fronteira e agrega por categoria visual.

### Multicâmera versus contagem

`CameraRegistryService` continua apenas cadastrando e verificando fontes. Adicionar câmera não cria contagem. `CameraEndpoint.countingEnabled` existe somente como campo de compatibilidade futura, padrão `false`, sem consumidor no pipeline atual. Entrada/saída continua sendo uma transição de rastreamento por área, não um contador acumulado.

### Aparência

`AppearanceSettingsService` persiste `ThemeMode` e cor principal em arquivo local separado. `VigiaIaApp` observa esse serviço e aplica o tema ao aplicativo inteiro. As opções visuais são Sistema/Claro/Escuro e Turquesa/Azul/Roxo/Laranja.

### Navegação e configurações

A barra principal contém somente **Início, Histórico, Monitor e Câmeras**. A engrenagem abre `SettingsScreen`, que organiza recursos existentes nas categorias Monitoramento, Alertas, Aparência, Armazenamento, Sistema, Diagnóstico e Sobre; parâmetros técnicos ficam em `AdvancedSettingsScreen`.

## Pareamento por QR 1.0.23

- `RemoteCameraPairingService` concentra serialização e validação do payload `vigiaia://pair`.
- O payload atual usa `v=1`, `type=phone`, endereço HTTP/HTTPS, chave de sessão e nome sugerido.
- `CameraModeScreen` renderiza o QR somente enquanto o servidor remoto está ativo e possui endereço local válido.
- `PhonePairingScannerScreen` aceita apenas QR e valida o payload antes de devolvê-lo à Central.
- `MultiCameraScreen` faz `CameraRegistryService.probe()` antes do cadastro; somente um endpoint que responde ao `/status` com a chave correta pode ser confirmado pelo fluxo de QR.
- Endereço já cadastrado reutiliza o mesmo `CameraEndpoint.id`, atualizando a chave sem romper o vínculo de histórico por `cameraId`.
- Entrada manual continua ativa e usa o mesmo modelo `CameraEndpoint`.
- O QR contém segredo temporário da sessão, portanto deve ser mostrado apenas para o aparelho que será pareado. Uma nova sessão do Modo Câmera gera nova chave.
- O scanner usa ML Kit embarcado pelo `mobile_scanner`; não foi habilitado o modo unbundled porque o projeto prioriza funcionamento offline.

## Seleção de endereço local 1.0.23

`RemoteCameraServerService` continua escutando em `InternetAddress.anyIPv4`, mas a URL exibida agora prioriza endereços RFC1918 (10/8, 172.16/12 e 192.168/16). Isso reduz a chance de escolher primeiro uma interface irrelevante em aparelhos com Wi-Fi, hotspot, VPN ou outras interfaces simultâneas. Se não houver IPv4 privado, o primeiro IPv4 não-loopback continua sendo usado como fallback.

## Central multicâmera 1.0.22

- `CameraRegistryService` persiste os endpoints e protege endereço/chave sensíveis com a bridge nativa já existente.
- `probeAll()` verifica endpoints em paralelo e devolve estado, horário da checagem e latência.
- `MultiCameraScreen` atualiza os estados a cada 15 segundos e adapta a grade a retrato, paisagem e telas maiores.
- RTSP e celulares remotos podem ser renomeados e desativados sem apagar o cadastro ou o histórico.
- `MonitorEvent.cameraId` é opcional para manter compatibilidade com eventos antigos; novos eventos recebem o ID do `VideoSourceConfig` quando disponível.
- `RemotePhoneCameraSource` mantém polling após falhas e publica `reconnecting` antes de elevar uma indisponibilidade persistente para `error`.
- RTSP continua usando a reconexão já existente em `RtspCameraSource`.

## Estabilidade e CI 1.0.22

- O workflow mantém a sequência verificação preventiva → `flutter analyze` → `flutter test` → APK release.
- Testes agora usam reporter expandido e cobertura LCOV, salva como artifact quando gerada.
- O verificador preventivo valida explicitamente os novos vínculos multicâmera sem substituir os testes Dart.

## Diagnóstico e saúde real 1.0.29

A ETAPA 4 separa coleta, avaliação, apresentação e exportação do estado do aplicativo:

- `RuntimeHealthService` mantém apenas sinais do runtime que vêm do pipeline real: fonte, câmera, último frame, FPS, IA e LAN.
- `SystemHealthService` combina esses sinais com foreground service, permissões e métricas nativas do Android.
- `SystemHealthSnapshot` é imutável e representa a captura usada pela interface. O estado geral só é `healthy` quando monitoramento, câmera, frames e IA estão realmente ativos.
- Serviço Android ativo sem frames fica `idle` ou `attention`, nunca `healthy`.
- `DiagnosticReportService` captura `SystemHealthSnapshot` + registros técnicos e reutiliza o mesmo objeto para tela, TXT, cópia e compartilhamento.
- O relatório não abre nova câmera nem executa uma segunda IA; usa apenas estado já publicado pelo pipeline existente.
- `StorageSizeFormatter` centraliza a apresentação de memória/armazenamento em B/KB/MB/GB/TB. Métricas Android agora chegam em bytes, evitando valores crus como `74930`.
- `HelpButton` fornece explicações curtas nas telas técnicas sem duplicar diálogos extensos.

### Regras de validade do estado

- **Câmera ativa:** exige fonte ativa e frame recente.
- **Frames chegando:** o último frame deve estar dentro da janela de heartbeat; frame congelado expira.
- **IA ativa:** exige modelo pronto, monitoramento ativo e frame recente.
- **LAN ativa:** exige servidor LAN sem erro e frames recentes; servidor escutando sozinho não equivale a vídeo sendo transmitido.
- **Segundo plano operacional:** exige opção habilitada, serviço Android ativo, monitoramento ativo e frames recentes.

### Exportação

O TXT é criado em `documents/exports/diagnostico` com nome `vigiaia_diagnostico_<timestamp>.txt`. O compartilhamento usa `Intent.ACTION_SEND` com o mesmo texto do snapshot exibido.


## Reidentificação visual e áudio personalizado 1.0.37

### Movimento por cor

`MotionDetectionService` mantém a comparação de luminância e acrescenta distância RGB no grid reduzido. Isso evita perder deslocamentos em que a cor muda muito, mas o brilho médio permanece parecido. Mudanças globais continuam passando pela heurística de movimento da câmera para não transformar alteração de iluminação/enquadramento em objeto local.

### Assinatura de aparência

`ObjectAppearanceService` amostra apenas o interior da caixa detectada e produz um histograma normalizado numa paleta pequena. Para `person`, também calcula cores aproximadas do tronco e das pernas; para `vehicle`, privilegia a região central do corpo para reduzir influência do fundo. A aparência não decide a classe do objeto e não é reconhecimento biométrico/facial.

`ObjectTracker` usa essa assinatura como mais uma variável na associação global. Tracks deixam de exigir rótulo COCO exatamente igual quando pertencem à mesma família monitorada e podem ser reaquiridos durante uma retenção de identidade de 12 s. A saída de uma área continua sendo emitida pelo limite curto de ausência; somente a identidade fica guardada para evitar criar um novo objeto em uma falha temporária do detector.

### Anti-repetição de fala

Alertas de detecção usam `grupo#trackId`, não `label#trackId`. Assim, oscilações `car/truck` ou `cat/dog` não criam uma chave de fala nova. Transições de entrada/saída têm uma proteção de 5 s por `trackId+zoneId` contra chatter de perda/reaquisicao, sem descartar o registro técnico/histórico.

### Áudio próprio

A pasta `custom_audio/` é a fonte estável, fora de `android/`, porque o workflow recria o projeto Android. `tool/bootstrap_android.sh` valida e copia os arquivos para `android/app/src/main/res/raw/`. `NativePlatformService.playCustomAlertAudio()` chama o método Android homônimo; `MainActivity` procura o recurso dinamicamente e usa `MediaPlayer`. Na ausência do slot, `_deliverAlert()` cai para `SpeechService`/TTS.


## Pacote de voz personalizado 1.0.38

O WAV único fornecido pelo usuário é armazenado apenas como fonte externa ao repositório de build; a aplicação usa os recortes individuais em `custom_audio/`. O bootstrap copia esses recursos para `res/raw`, e a árvore Android atual também contém os mesmos arquivos para permitir build direto sem recriação.

`MonitorController` escolhe o slot de transição pela família semântica do objeto: pessoa usa `person_entered/person_exited`, veículo usa `vehicle_entered/vehicle_exited`, animal usa `animal_entered/animal_exited` e outras classes usam `object_entered/object_exited`. `NativePlatformService`/`MainActivity` continuam retornando `false` quando o recurso não existe; `_deliverAlert()` então usa TTS sem alterar o restante do alerta.

A gravação recebida contém dez falas. As duas falas de entrada/saída de animal não estão presentes e, por isso, esses dois slots ficam intencionalmente sem arquivo até nova gravação.
