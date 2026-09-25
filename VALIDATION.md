# Validação Vigia IA 1.0.147+147

## 1.0.147+147 — buildfix Android-APK-110

- Confirmar que `lib/services/map_navigation_voice_policy.dart` não captura mais `threshold` anulável dentro do filtro após a checagem de nulo.
- Confirmar que `map_monitoring_offline_support.dart` não chama `setState` diretamente e continua atualizando conectividade, fallback e recuperação de rota pelo `State` proprietário.
- Confirmar ausência da asserção `offlineProvider!` redundante e preservação do mesmo provider MBTiles.
- Executar `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh`.
- Executar `flutter analyze`; o Android-APK-110 falhou com 1 erro e 5 avisos relevantes a esta correção.
- Executar `flutter test` e build Android no workflow para confirmar regressão zero.
- Resultado local: `python3 tool/check_version_sync.py` **aprovado** e `bash tool/verify_project.sh` **aprovado**.
- `.github/workflows` permanece byte a byte igual ao da 1.0.146; nenhum APK/AAB está presente no fonte.
- Limitação local: Flutter/Dart não estão instalados neste ambiente, portanto `flutter analyze`, `flutter test` e build Android precisam ser reconfirmados no workflow.



## 1.0.146+146 — offline aprimorado + revisão visual do mapa

- Iniciar uma navegação com rota viária carregada, cortar a internet e confirmar que a geometria atual permanece no mapa, com indicação `Offline automático`/`Sem internet` e sem apagar o destino.
- Sair do trajeto ainda sem rede e confirmar que o app não entra em recálculo contínuo nem substitui a rota por uma linha tratada como rota viária; o banner deve informar que mantém a última rota conhecida.
- Iniciar navegação já offline e sem rota carregada e confirmar mensagem explícita de direção ao destino, sem fingir possuir instruções viárias.
- Com pacote MBTiles ativo, confirmar fallback visual automático ao perder a internet mesmo se o usuário estava no modo Online; durante navegação a rota e o destino devem permanecer visíveis e, fora da área do pacote, manter o aviso de cobertura.
- Com pacote de POIs salvo, cortar a rede e confirmar seleção automática da região mais adequada, recálculo local de distância e continuidade dos alertas configurados.
- Restaurar internet e confirmar atualização automática dos POIs e nova tentativa de rota; a navegação não deve precisar ser encerrada/reaberta.
- Em retrato e paisagem, revisar controles de voltar/camadas/GPS, telemetria, atalhos Perto/Região/Rota, zoom, opções, card de POI, banner de navegação e PiPs sem sobreposição importante.
- Confirmar que PiPs grandes reduzem temporariamente mais durante navegação e retornam ao tamanho salvo ao encerrar.
- Executar `test/map_connectivity_service_test.dart`, `test/map_offline_navigation_policy_test.dart` e `test/map_ux_policy_test.dart`, além da suíte completa quando Flutter estiver disponível.
- Executar `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh`.
- Reconfirmar `flutter analyze`, `flutter test` e build Android no workflow quando o SDK Flutter estiver disponível.
- Resultado local desta entrega: `python3 tool/check_version_sync.py` **aprovado** e `bash tool/verify_project.sh` **aprovado**.
- `.github/workflows/android-apk.yml` permanece byte a byte igual ao da 1.0.145; nenhum APK/AAB está presente no fonte.
- Limitação local: Flutter/Dart não estão instalados neste ambiente; `flutter analyze`, `flutter test` e build Android não puderam ser executados localmente.


## 1.0.145+145 — avisos de POIs + navegação por voz

- Com alertas ativos, confirmar mensagens de posto/água/camping/oficina usando a distância configurada e somente categorias selecionadas.
- Confirmar que resultados de pacote offline geram os mesmos avisos sem depender de internet.
- Colocar vários POIs próximos e validar no máximo um novo aviso por minuto; se um local for descoberto já dentro de 1 km, não deve surgir depois um aviso atrasado de 3/5/10 km para o mesmo POI.
- Desmarcar uma categoria mantendo resultados antigos carregados e confirmar que ela deixa de gerar alerta imediatamente.
- Iniciar navegação e validar fala da próxima manobra em marcos de aproximadamente 1 km, 500 m, 200 m e 80 m, sem repetir o mesmo marco a cada atualização GPS.
- Confirmar que 80 m pode ter prioridade mesmo após um aviso recente, preservando a manobra iminente.
- Sair da rota por duas amostras válidas e confirmar “Você saiu da rota. Recalculando o caminho.”; após sucesso confirmar “Rota recalculada.”.
- Chegar ao destino e confirmar anúncio único de chegada.
- Desativar a voz global ou o TTS dinâmico nas preferências de áudio e confirmar que instruções variáveis não são faladas; notificações de POI seguem a preferência própria.
- Executar `test/route_explorer_alert_policy_test.dart` e `test/map_navigation_voice_policy_test.dart`, além da suíte completa quando Flutter estiver disponível.
- Executar `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh`.
- Reconfirmar `flutter analyze`, `flutter test` e build Android no workflow quando o SDK Flutter estiver disponível.
- Resultado local desta entrega: `python3 tool/check_version_sync.py` **aprovado** e `bash tool/verify_project.sh` **aprovado**.
- `.github/workflows/android-apk.yml` permanece byte a byte igual ao da 1.0.144; nenhum APK/AAB está presente no fonte.
- Limitação local: Flutter/Dart não estão instalados neste ambiente; `flutter analyze`, `flutter test` e build Android não foram executados localmente.


## 1.0.144+144 — estados da IA nos PiPs

- Confirmar `IA ativa` com fonte recebendo frames recentes e detector pronto.
- Confirmar `Analisando` apenas durante processamento real e nunca quando a IA estiver desligada.
- Confirmar `Aguardando frames` na conexão/inicialização antes do primeiro quadro e `Sem frames` após expirar a janela de 4–8 segundos.
- Forçar falha da câmera local e validar `Câmera indisponível`; em RTSP/celular remoto/ESP32 validar `Conexão perdida` durante erro/reconexão.
- Confirmar `Possível erro da IA` quando o detector falhar sem uma falha de fonte mais específica.
- Abrir câmera apenas pelo mapa/segunda câmera e confirmar `IA desligada`, sem criar outro pipeline de análise.
- Com aproximação de veículo ativa, confirmar que status de IA e TTC/risco continuam legíveis dentro do PiP sem cobrir HUD ou navegação.
- Executar `test/monitor_ai_status_resolver_test.dart` e `test/map_ai_status_overlay_test.dart`, além da suíte completa quando Flutter estiver disponível.
- Executar `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh`.
- Reconfirmar `flutter analyze`, `flutter test` e build Android no workflow quando o SDK Flutter estiver disponível.
- Resultado local desta entrega: `python3 tool/check_version_sync.py` **aprovado** e `bash tool/verify_project.sh` **aprovado**.
- Limitação local: Flutter/Dart não estão instalados neste ambiente; `flutter analyze`, `flutter test` e build Android não foram executados localmente.


## 1.0.143+143 — aproximação de veículos + novidades da atualização

- Confirmar que o mapa aberto pelo Monitor mostra o estado de aproximação somente no PiP da câmera principal analisada e nunca nas câmeras abertas apenas para visualização pelo mapa.
- Validar veículo sem aproximação como `sem risco`, aproximação em observação, risco alto/crítico e TTC quando calculável.
- Confirmar que o overlay permanece dentro do PiP e não altera as reservas do HUD, banner de navegação ou card de POI.
- Executar `test/bike_approach_estimator_test.dart` e `test/map_bike_approach_overlay_test.dart`.
- Executar `test/update_news_service_test.dart`: primeira abertura mostra; segunda não; nova versão mostra novamente; salto de versão agrega releases; estado ausente/corrompido permanece seguro.
- Confirmar no Android que `appVersionInfo` retorna `versionName/versionCode` do pacote instalado e que `update_news_state.json` registra `1.0.143+143` após fechar o modal.
- Confirmar que fechar o modal por `Entendi`, toque externo ou voltar não bloqueia a inicialização e que falha de persistência também libera o app.
- Executar `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh`.
- Reconfirmar `flutter analyze`, `flutter test` e build Android no workflow quando o SDK Flutter estiver disponível.
- Resultado local desta entrega: `python3 tool/check_version_sync.py` **aprovado** e `bash tool/verify_project.sh` **aprovado**.
- Limitação local: o ambiente atual não possui os executáveis Flutter/Dart, portanto `flutter analyze`, `flutter test` e build Android não puderam ser executados aqui.


## 1.0.142+142 — buildfix Android-APK-107

- Confirmar que `flutter analyze` permanece sem avisos.
- Executar `test/map_poi_details_sheet_test.dart` e validar que `scrollUntilVisible` alcança `Água potável` mesmo quando o `DraggableScrollableSheet` primeiro precisa expandir.
- Confirmar que o teste ainda aciona `Ir até lá` e incrementa o callback de navegação.
- Executar a suíte completa; no build 107 os demais 249 testes passaram e a única falha estava nesse teste de widget.
- Executar `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh`.
- Reconfirmar build Android no GitHub Actions.


## 1.0.141+141 — buildfix Android-APK-106

- O log Android-APK-106 registrou `flutter analyze` com **No issues found**.
- A suíte chegou a 249 testes aprovados e falhou apenas em `map_poi_details_sheet_test.dart`, ao procurar `Água potável` antes de rolar o `ListView`.
- Confirmar que o teste executa uma rolagem antes da asserção da comodidade e continua acionando `Ir até lá`.
- Executar `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh`.
- Reconfirmar `flutter test` e build Android no GitHub Actions.

## PiPs de câmera sobre o mapa

- abrir o mapa com uma câmera configurada, ocultar todos os PiPs e confirmar que aparece o atalho **Mostrar câmera**;
- fechar/reabrir o mapa após desativar **Mostrar PiPs no mapa** e confirmar que a preferência global é restaurada;
- tocar em **Mostrar câmera** e confirmar que a câmera principal volta expandida e que uma fonte interna suspensa retoma os frames;
- iniciar uma navegação com PiP em tamanho grande e confirmar redução visual temporária sem alterar o tamanho escolhido no gerenciador;
- encerrar a navegação e confirmar que o PiP volta ao tamanho salvo;
- com duas câmeras, arrastar uma para o canto ocupado pela outra e confirmar separação vertical em retrato e lateral em paisagem;
- confirmar que PiPs continuam respeitando HUD superior, banner de navegação, card de POI e barra inferior;
- executar `flutter analyze`, `flutter test` e o build Android no workflow.

## Verificação local disponível

- `python3 tool/check_version_sync.py`: aprovado;
- `bash tool/verify_project.sh`: aprovado;
- Flutter/Dart não estão instalados neste ambiente, portanto analyze/test/build dependem do workflow.

---

## 1.0.138+138 — POIs enriquecidos + natureza/cicloviagem

- Confirmar categorias Camping, Mirantes, Cachoeiras e Mercados nas configurações e nos marcadores/listas quando houver dados na região.
- Confirmar filtros rápidos `Natureza` e `Bike/viagem` em Próximos pontos.
- Confirmar endereço/horário/telefone/site/comodidades quando as tags correspondentes existirem e ausência limpa desses campos quando não existirem.
- Salvar pacote offline, reiniciar e confirmar preservação dos metadados enriquecidos e das novas categorias.
- Atualizar a partir de estado antigo sem `poiCatalogVersion` e confirmar migração automática das quatro novas categorias; após o usuário desmarcá-las no catálogo v2, elas não devem reaparecer sozinhas.
- Confirmar que uma região densa ainda mantém alguma diversidade de categorias dentro do limite de resultados.
- Executar `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh`.
- Executar `test/route_explorer_poi_catalog_test.dart`, `test/offline_poi_package_test.dart` e a suíte completa quando Flutter estiver disponível.
- `flutter analyze`, `flutter test` e build Android dependem do SDK Flutter/Android e devem ser reconfirmados pelo workflow.

## 1.0.137+137 — rotas alternativas

- Confirmar rota principal + até duas alternativas distintas quando o servidor disponibilizar.
- Confirmar que a rota ativa fica destacada e alternativas permanecem visíveis em segundo plano.
- Confirmar seletor `Rota X/N` com distância e duração de cada opção.
- Confirmar que trocar a rota atualiza instruções/progresso sem encerrar a navegação.
- Confirmar que recálculo automático substitui o conjunto de alternativas sem índice inválido.
- Confirmar fallback de rota única/direção direta quando alternativas ou roteamento não estiverem disponíveis.

## 1.0.136+136 — navegação guiada + recálculo automático

Validação preventiva desta etapa dupla:

- iniciar navegação até um POI e confirmar que o banner mostra instrução atual, próxima manobra, distância até a próxima ação, distância/tempo restantes e progresso percentual;
- confirmar que a polyline permanece a mesma rota viária e que direção direta continua disponível quando o roteador falha;
- sair da rota e confirmar que uma leitura isolada não recalcula; duas posições GPS novas consecutivas fora da rota devem iniciar o recálculo;
- confirmar que recálculos seguintes respeitam cooldown de 45 segundos e que uma resposta antiga não substitui rota mais nova;
- fechar/reabrir o mapa durante navegação e confirmar que destino persistido recupera geometria e instruções a partir da posição atual;
- validar que PiPs, atribuição, POI selecionado e banner maior não se sobrepõem;
- executar `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh`;
- executar `test/map_navigation_guidance_test.dart` junto da suíte completa quando Flutter estiver disponível;
- `flutter analyze`, `flutter test` e build Android dependem do SDK Flutter/Android e devem ser reconfirmados pelo workflow.

## 1.0.133+133 — refinamento visual do mapa

Validação preventiva desta etapa:

- `MapPoiDisplayPolicy` e `test/map_poi_display_policy_test.dart` presentes;
- clustering preserva POI selecionado individual e reduz rios/pontes em visão regional;
- HUD permanente não mantém câmera/orientação como botões laterais separados; ambos continuam acessíveis em Opções;
- barra de percurso compacta mantém cronômetro isolado, distância e pausa/encerrar;
- mapa usa `AnnotatedRegion<SystemUiOverlayStyle>` com `SystemUiService.mapOverlayStyle` e scrims edge-to-edge;
- PiP minimizado usa 44×44, duplo toque alterna tamanho e há troca de slots internos;
- `MapUxPolicy` atualizado para as alturas menores dos overlays;
- `tool/check_version_sync.py` e `tool/verify_project.sh` devem passar também após extração do ZIP final;
- `flutter analyze`, `flutter test` e build Android dependem de SDK Flutter/Dart disponível no ambiente de validação.

## 1.0.132+132 — buildfix Android-APK-99

- Confirmar que `lib/screens/map_monitoring_screen.dart` importa `../models/offline_poi_package.dart`.
- Confirmar ausência de `package:flutter/foundation.dart` em `lib/services/map_route_service.dart`.
- Executar `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh`.
- O log Android-APK-99 registrou dois `undefined_class` para `OfflinePoiPackage` e um `unnecessary_import`; os três pontos foram corrigidos nesta versão.
- Flutter/Android SDK não estão instalados neste ambiente; `flutter analyze`, `flutter test` e build APK devem ser reconfirmados pelo workflow.

## 1.0.131+131 — UX final + revisão/regressão do mapa

- `python3 tool/check_version_sync.py`: deve confirmar `1.0.131+131` em pubspec, AppMetadata, identidade, Mudanças, README, CHANGELOG, ARCHITECTURE e RELEASE.
- `bash tool/verify_project.sh`: deve confirmar `MapUxPolicy`, cluster de zoom, menu compacto dos PiPs, restauração de layout, atualização online segura dos pacotes offline e ausência do ícone inválido do APK-95.
- Em retrato estreito e paisagem curta, validar HUD compacto: Perto/Região/Rota permanecem acessíveis, GPS/camada não se sobrepõem e a telemetria mantém velocidade, distância e rumo.
- Arrastar ambos os PiPs para os quatro cantos com e sem POI/destino ativo; confirmar que não cobrem Voltar/GPS/telemetria nem os cards inferiores. Fechar/reabrir e confirmar posição estável.
- Reduzir o PiP ao menor tamanho e confirmar que as ações ficam no menu único sem transbordar a janela; usar **Restaurar posição e tamanho dos PiPs** e confirmar retorno ao layout padrão.
- Selecionar POI em tela estreita, abrir detalhes tocando no texto, iniciar navegação e confirmar que card, banner, atribuição e barra de percurso permanecem separados.
- Desligar GPS/permissão e confirmar tela sem AppBar grande, com Voltar e Mapas offline flutuantes.
- Salvar um pacote de POIs, alterar a região e usar **Atualizar pela internet**; em sucesso, confirmar nova data/conteúdo. Em falha de rede, confirmar que o pacote anterior permanece intacto.
- Executar os testes `map_ux_policy_test.dart`, `map_camera_overlay_settings_test.dart`, `map_view_policy_test.dart`, `offline_poi_package_test.dart` e os demais testes quando Flutter estiver disponível.
- `flutter analyze`, `flutter test` e build Android dependem do Flutter/Android SDK deste ambiente e devem ser reconfirmados pelo workflow.

## 1.0.130+130 — câmeras no mapa + desempenho

- `python3 tool/check_version_sync.py`: deve confirmar `1.0.130+130` em pubspec, AppMetadata, identidade, Mudanças, README, CHANGELOG, ARCHITECTURE e RELEASE.
- `bash tool/verify_project.sh`: deve confirmar serviço persistente dos PiPs, seleção de fontes dentro do mapa, reutilização das câmeras do Monitor, suspensão de câmeras internas, GPS por consumidores, ausência do ticker global de 1 Hz e redução visual de rotas longas.
- Abrir **Mapa** diretamente pela Home e selecionar câmera traseira/local, frontal, RTSP/celular/ESP32 cadastrado; confirmar que não é necessário entrar primeiro no Monitor.
- Abrir o mapa pelo Monitor e confirmar que **Câmera atual do Monitor** pode ser reutilizada sem abrir outro pipeline de IA; trocar um PiP por outra fonte não deve mudar a fonte principal analisada pelo Monitor.
- Com dois PiPs, arrastar cada um e confirmar encaixe no canto mais próximo; alternar tamanho, minimizar e ocultar individualmente; fechar/reabrir o mapa e confirmar persistência do layout.
- Em PiP interno, minimizar/ocultar e confirmar suspensão da fonte; restaurar e confirmar retomada. Colocar o app em background sem gravação/navegação e confirmar liberação das fontes internas e do GPS passivo.
- Gravar percurso com o mapa aberto e confirmar que o tempo continua atualizando sem recentralização/rebuild global a cada segundo; percurso longo deve continuar exportando todos os pontos no GPX embora a polyline visual seja reduzida.
- `test/map_camera_overlay_settings_test.dart` cobre serialização, persistência lógica e clamp de posição/tamanho.
- `flutter analyze`, `flutter test` e build Android continuam condicionados à disponibilidade do Flutter/Android SDK no ambiente local e devem ser reconfirmados pelo workflow.

## 1.0.129+129 — camadas + pacotes offline de POIs

- `python3 tool/check_version_sync.py`: deve confirmar `1.0.129+129` em pubspec, AppMetadata, identidade, Mudanças, README, CHANGELOG, ARCHITECTURE e RELEASE.
- `bash tool/verify_project.sh`: cobre os cinco `MapStylePreset`, seletor de camadas, card compacto de POI, `OfflinePoiPackage`, migração de `offlinePackages`, atualização automática sem dependência de gravação e ausência do ícone inválido do Android-APK-95.
- Testes Dart adicionados: `test/map_style_preset_test.dart` e `test/offline_poi_package_test.dart`.
- `flutter analyze`, `flutter test` e build Android continuam condicionados à disponibilidade do Flutter/Android SDK no ambiente de validação.

## 1.0.128+128 — buildfix Android-APK-95

- `flutter analyze` do workflow com Flutter 3.44.9 apontou exatamente dois erros, ambos originados pela referência inexistente `Icons.offline_map_rounded` em `map_monitoring_screen.dart`.
- A referência foi substituída por `Icons.download_for_offline_outlined`.
- `tool/verify_project.sh` agora falha caso `Icons.offline_map_rounded` reapareça.
- Os validadores locais disponíveis devem ser executados novamente após a correção; `flutter analyze`, `flutter test` e o build Android dependem do SDK Flutter/Android quando ele não estiver instalado no ambiente local.

## 1.0.127+127 — visão à frente, orientação e enquadramentos rápidos

- Com GPS válido, abrir o mapa e confirmar que **Perto** segue a posição com o marcador abaixo do centro, deixando mais mapa visível à frente.
- Alternar para **Região** e confirmar zoom mais aberto sem perder o seguimento; usar +/− e confirmar que o zoom manual continua seguindo a posição.
- Selecionar **Norte fixo** e confirmar câmera em 0°; selecionar **Acompanhar direção**, mover-se acima de ~3 km/h e confirmar que o rumo passa a apontar para o topo sem oscilar continuamente parado.
- Girar o aparelho e validar que o offset diminui em paisagem curta e que controles/PiPs não encobrem os atalhos Perto/Região/Rota.
- Iniciar percurso e/ou navegar até um POI; tocar **Rota** e confirmar enquadramento de todo o conjunto. Tocar Perto/Região para retomar acompanhamento.
- Com mapa rotacionado, confirmar que POIs, início, fim e destino ficam retos e legíveis, enquanto a seta do usuário representa corretamente o rumo.
- Deixar percurso gravando sem deslocamento e confirmar que o ticker de tempo atualiza a telemetria sem recentralizações perceptíveis da câmera.
- Fechar/reabrir o mapa após selecionar orientação e preset e confirmar persistência.
- Executar `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh`.
- Flutter/Android SDK não estão instalados neste ambiente; `flutter analyze`, `flutter test` e build APK devem ser reconfirmados pelo workflow.

## 1.0.126+126 — GPS filtrado, percurso e navegação separados

- Com GPS bom (≤35 m), tocar **Gravar percurso**, caminhar/pedalar, pausar, retomar e encerrar; confirmar distância crescente sem saltos e exportação `VigiaIA-percurso-*.gpx`.
- Forçar/usar leituras com precisão entre 36–60 m e confirmar que a posição pode continuar utilizável no mapa, mas não entra no percurso gravado.
- Simular precisão >60 m, velocidade >70 m/s, timestamp fora de ordem e salto incompatível com o intervalo; confirmar que essas leituras não movem `current`.
- Simular jitter de poucos metros com precisão ruim/moderada e confirmar que não aumenta artificialmente a distância.
- Simular perda de GPS >30 s e retorno em outro ponto plausível; confirmar reinício da suavização e novo segmento quando o salto do percurso exceder 250 m.
- Encerrar com uma leitura atual não elegível à gravação e confirmar que o marcador **Fim** corresponde ao último ponto efetivamente gravado.
- Matar/recriar o processo com gravação ativa; confirmar que o intervalo sem coleta não conta como tempo ativo e que a retomada abre novo segmento.
- Abrir **Próximos pontos**, tocar em um local e escolher **Navegar até**; confirmar marcador de destino, distância/rumo direto e botão **Parar navegação**, sem iniciar/parar a gravação do percurso.
- Reiniciar o app durante uma navegação e confirmar restauração do destino pelo schema 3; estado legado com `tracking` deve continuar migrando.
- Executar `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh`.
- Flutter/Android SDK não estão instalados neste ambiente; `flutter analyze`, `flutter test` e build APK devem ser reconfirmados pelo workflow.

## 1.0.125+125 — mapa em tela cheia, pontos e percurso

- Abrir **Mapa** pela Home e confirmar ausência de AppBar/faixa preta; o mapa deve ocupar a tela e continuar visível atrás das áreas do sistema.
- Confirmar controles flutuantes para voltar, zoom +/−, seguir GPS, Próximos pontos, câmera, offline e configurações; girar para paisagem curta e conferir que os controles migram para faixa horizontal.
- Permitir GPS e confirmar posição, precisão, velocidade, distância, tempo, altitude/direção e alternância entre **Seguindo** e **Mapa livre**.
- Abrir **Próximos pontos**, testar filtros Todos/Postos/Comida/Saúde/Água/Outros, Atualizar e Salvar offline; confirmar marcadores correspondentes no mapa.
- Tocar em um marcador e confirmar detalhe/distância/origem Online ou Offline; tocar em um ponto da lista do Monitor e confirmar que o mapa abre centralizado nele.
- Iniciar rota, pausar/continuar, encerrar e exportar GPX. Simular um salto >250 m entre posições e confirmar novo segmento sem linha reta artificial e sem somar o salto.
- Durante rota ativa com **No caminho**, deslocar ~1,5 km (ou aguardar 5 min) e confirmar atualização automática dos pontos; sem rede, confirmar fallback da lista offline.
- Com uma câmera, confirmar PiP móvel; com duas, confirmar duas janelas e disposição inicial lado a lado em paisagem. Ocultar/mostrar pelo controle de câmera.
- Ativar mapa MBTiles/Stadia e confirmar alternância Online/Offline/Automático, aviso fora da área e atribuição compacta sem cobrir a rota.
- Executar `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh`.
- Flutter/Android SDK não estão instalados neste ambiente; `flutter analyze`, `flutter test` e build APK devem ser reconfirmados pelo workflow.

## 1.0.124+124 — refinamento dos sensores ESP32

- Com temperatura configurada e valor chegando, confirmar status **Lendo agora** e valor em °C na própria linha.
- Com mmWave configurado e anunciado em `capabilities`, mas sem payload de leitura, confirmar status **Detectado**.
- Com pneu configurado e módulo online sem leitura nem anúncio, confirmar **Aguardando leitura** sem gerar valor zero.
- Desligar o ESP32 e confirmar que sensores configurados passam para **Módulo offline** sem perder o último cadastro.
- Fazer o firmware anunciar ToF não marcado no wizard e confirmar **Detectado · não configurado** mais o botão de revisão.
- Testar firmware legado sem `capabilities`, enviando velocidade/pressão/temperatura/bateria, e confirmar inferência automática desses recursos.
- Confirmar que Wi‑Fi, endpoint, uptime, sequência e reconexão aparecem no bloco **Conexão**, sem duplicar velocidade/pressão/temperatura.
- Executar `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh`.
- Flutter/Android SDK não estão instalados neste ambiente; `flutter analyze`, `flutter test` e build APK devem ser reconfirmados pelo workflow.

## 1.0.123+123 — energia, bateria e solar no ESP32

- Criar módulo com capacidade **Energia**, alimentação **Power bank USB** e **Sem bateria monitorada**; confirmar que o wizard conclui sem exigir bateria física.
- Repetir com **Tomada / fonte USB** para validar uso em bancada.
- Configurar bateria **Chumbo-ácido 12 V / 7 Ah** com INA226 e entrada solar; salvar/reabrir e confirmar persistência.
- Configurar **LiFePO₄ 12,8 V** e confirmar que o perfil não usa a mesma química/limites sugeridos do chumbo.
- Confirmar que **Bateria do módulo** e **Energia** aparecem como capacidades distintas e que uma leitura da bateria principal não alimenta o alerta legado da bateria do ESP32.
- Injetar payload `power.battery` com percent/voltage/current/temperature e `power.solar` com V/A/W; confirmar exibição no card e exportação no diagnóstico.
- Confirmar compatibilidade com payload legado `power.batteryPercent`/`voltageV` sem `power.battery`.
- Confirmar que `/config` envia `energy.enabled`, `moduleSupply`, `monitor`, `battery` e `solar` apenas como extensão compatível.
- Executar `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh`.
- Flutter/Android SDK não estão instalados neste ambiente; `flutter analyze`, `flutter test` e build APK devem ser reconfirmados pelo workflow.

## 1.0.122+122 — wizard ESP32 e buildfix Android-APK-90

- Abrir **ESP32** sem módulos e confirmar que existe apenas um botão para iniciar o cadastro.
- Confirmar que o wizard mostra **Etapa 1 de 5** e segue por Conexão → Identificação → Capacidades → Configuração → Revisão.
- Testar busca automática com ESP32 em `192.168.4.1` ou `esp32.local` e confirmar fallback para endereço/chave manual quando offline.
- Confirmar que capacidades informadas pelo firmware aparecem como detectadas e que mmWave/térmico/ToF/ultrassom/ambiente/GPS/luz/atuadores podem ser cadastrados sem câmera.
- Selecionar apenas Hall e confirmar que a etapa seguinte não mostra pressão ou temperatura; repetir com sensores diferentes.
- Salvar um módulo offline e confirmar que o cadastro permanece disponível; salvar online e confirmar tentativa de aplicação da configuração.
- Salvar `capabilities: []`, reiniciar e confirmar que sensores padrão não reaparecem.
- Confirmar ausência de `package:flutter/foundation.dart` em `lib/services/esp32_telemetry_service.dart`, corrigindo o issue que encerrou o Android-APK-90.
- Executar `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh`.
- Flutter/Android SDK não estão instalados neste ambiente; `flutter analyze`, `flutter test` e build APK devem ser reconfirmados pelo workflow.

# Validação — Vigia IA 1.0.121+121

## 1.0.121+121 — telemetria contínua ESP32

- Com módulo online, confirmar descoberta de `/api/v1/telemetry` ou `/telemetry`; com firmware legado, confirmar fallback para `/api/v1/status`/`/status`.
- Confirmar atualização contínua de estado, latência, endpoint, RSSI, bateria/tensão, firmware e sensores no card do ESP32.
- Desligar a rede/módulo e confirmar estado **Conexão instável** durante a janela válida, depois **Offline**, com reconexão automática e backoff sem travar a UI.
- Conectar dois módulos com sensores diferentes e confirmar que o HUD combina os valores sem ficar alternando a fonte e sem gerar alerta por sensor inexistente.
- Confirmar que módulo com apenas Hall não gera pneu/bateria/temperatura críticos e que pressão dianteira sem traseira não gera alerta falso no pneu traseiro.
- Confirmar que o Diagnóstico exportado contém a seção **MÓDULOS ESP32** com runtime e última telemetria.
- Colocar o app em segundo plano e confirmar que o polling é suspenso; ao retornar, confirmar retomada imediata.
- Executar `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh`.
- Flutter/Android SDK não estão instalados neste ambiente; `flutter analyze`, `flutter test` e build APK devem ser reconfirmados pelo workflow.

## 1.0.120+120 — fundação modular ESP32

- Atualizar uma instalação com ESP32 já cadastrado e confirmar migração automática para `esp32_modules.json`, preservando nome, endereço/chave, sensores, calibração e câmera.
- Confirmar que um módulo sem câmera permanece em **ESP32** mas não aparece como fonte em **Ao vivo/Câmeras**.
- Confirmar que um módulo com **Câmera ESP32 instalada** continua aparecendo como fonte com o mesmo `id`, endereço e chave.
- Configurar posições diferentes (dianteiro/traseiro/personalizada) e confirmar persistência após reabrir a tela.
- Configurar telemetria em 5 s e confirmar que o timeout exibido é 15 s, evitando falso offline em 6 s.
- Validar pressão mínima e temperatura máxima customizadas nos testes do `BikeSensorSnapshot`.
- Confirmar que `/status` textual legado continua marcando o módulo online e que JSON novo pode informar protocolo, firmware e capacidades.
- Executar `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh`.
- Flutter/Android SDK não estão instalados neste ambiente; `flutter analyze`, `flutter test` e build APK devem ser reconfirmados pelo workflow.

## 1.0.119+119 — Home com assets, Histórico e Câmeras compactos

- Confirmar que os quatro cards da Home carregam `assets/images/modes/live.png`, `transmission.png`, `remote.png` e `esp32.png` com fundo transparente.
- Confirmar que os quatro filtros do Histórico permanecem na mesma linha em 320/360 px, com rótulos **Todos/Pessoas/Veículos/Animais** sem check duplicado ou overflow.
- Confirmar que **Monitorar** aparece ao lado direito do nome da câmera e que o card não mantém botão grande no rodapé.
- Confirmar que **Abrir com segunda câmera** continua acessível pelo menu quando houver outra câmera habilitada.
- Executar `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh`.
- Flutter/Android SDK não estão instalados neste ambiente; `flutter analyze`, `flutter test` e build APK devem ser reconfirmados pelo workflow.

## 1.0.118+118 — voz configurável e qualidade Bike

- Confirmar perfil Bike **Economia = 7 FPS / 960 px / JPEG 76** e **Economia extrema = 5 FPS / 800 px / JPEG 72**.
- Confirmar que **Áudios e voz** permite ligar/desligar cada fala, ativar todas e silenciar todas sem alterar notificações visuais.
- Confirmar que **TTS para mensagens sem áudio integrado** e **TTS se um áudio integrado falhar** são opções independentes.
- Confirmar que o fallback TTS inicia desativado em instalações/perfis sem configuração anterior.
- Confirmar que os slots Bike/ESP32 não aparecem mais como “Futuro”.
- No **ESP32 > engrenagem > Emulador de sensores**, alternar os cenários e confirmar reprodução dos áudios integrados correspondentes, respeitando slots silenciados.
- Confirmar que o alerta de aproximação não depende de TTS quando o áudio integrado de veículo está ativo.
- Executar `python3 tool/verify_audio_resource_catalog.py`, `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh`.
- Flutter/Android SDK não estão instalados neste ambiente; `flutter analyze`, `flutter test` e build APK devem ser reconfirmados pelo workflow.

## 1.0.117+117 — Home, Bike/ESP32 e Transmissão

- Confirmar Home 2x2 com **Ao vivo**, **Transmissão**, **Remoto** e **ESP32**, sem card Bike e sem overflow.
- Confirmar os cinco acessos rápidos na mesma linha em 320/360 px e rótulo Diagnóstico legível.
- Confirmar **Ajustes > Bike e economia** e ausência de Bike na seleção de modo inicial.
- Confirmar migração segura de `AppLaunchMode.bike` legado para `normal`, preservando `bike_mode.json`.
- Confirmar engrenagem do ESP32 abrindo **Emulador de sensores** e cenários existentes.
- Confirmar engrenagem na Transmissão abrindo Bike/economia sem encerrar a transmissão.
- Confirmar bateria local visível na Transmissão e atualização periódica.
- Confirmar frequência de transmissão padrão de 10 FPS e perfis Bike 10/6/3 FPS, independente do intervalo de análise da IA.
- Executar `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh`.
- Flutter/Android SDK não estão instalados neste ambiente; `flutter analyze`, `flutter test` e build APK devem ser reconfirmados pelo workflow.



## 1.0.116+116 — correção Android-APK-84

- Confirmar que `flutter analyze` continua sem issues.
- Confirmar que `modo compacto cabe em celula estreita da Home` passa sem `RenderFlex overflow`.
- Confirmar que `acao rapida Diagnostico cabe na grade responsiva` passa sem `RenderFlex overflow`.
- Confirmar que os cards compactos ainda exibem título, descrição e tags e que o acesso rápido ainda exibe **Diagnóstico**.
- Executar `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh`.
- Flutter/Android SDK não estão instalados neste ambiente; `flutter analyze`, `flutter test` e o build APK precisam ser reconfirmados pelo workflow.

## 1.0.115+115 — Home, mapa e ESP32 compactos

- Confirmar quatro cards principais na Home: **Monitor ao vivo**, **Modo transmissão**, **Modo Bike** e **ESP32**.
- Confirmar grade 2x2 dos modos em celular e quatro colunas em telas largas.
- Confirmar que o card **ESP32** abre `Esp32SettingsScreen` e que **Ajustes > Monitoramento** não mantém atalho duplicado para ESP32.
- Confirmar que **Acessos rápidos** usa grade responsiva e não corta **Diagnóstico** em largura estreita.
- Confirmar que **Configurações do mapa e percurso** usa controles compactos para raio, modo de busca, categorias, alertas, distância, offline e mini mapa.
- Confirmar que `RouteExplorerService` e `MapRouteService` seguem sendo reutilizados sem duplicação de lógica.
- Executar `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh`.
- Flutter/Android SDK não estão instalados neste ambiente; `flutter analyze`, `flutter test` e o build APK devem ser confirmados pelo workflow.

## 1.0.114+114 — correção Android-APK-82

- Confirmar ausência de `minSize:` em `lib/core/vigia_design.dart` e presença de `minimumSize:` nos temas de botão.
- Confirmar que `monitor_screen_multicamera.dart` mantém balanceados os delimitadores das listas do seletor de câmera e do `Stack` do monitor.
- Confirmar que `home_screen_redesign.dart` não chama `setState` diretamente pela extension.
- Confirmar remoção dos elementos privados sem uso reportados no log: `_MetricChip`, `_LiveDot` e `_showLandscapeQuickActions`.
- Executar `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh`.
- O próximo workflow deve reconfirmar `flutter analyze`, `flutter test` e o build APK, pois o ambiente local não possui Flutter/Android SDK.

## 1.0.113+113 — fundação visual, Home e navegação

- Confirmar que a Home mostra os três cards principais: **Monitor ao vivo**, **Modo transmissão** e **Modo Bike**.
- Confirmar os cinco acessos rápidos: **Câmeras**, **Mapa**, **Histórico**, **Diagnóstico** e **Ajustes**.
- Confirmar que **Preparar monitoramento** mantém fonte, filtros de objetos, regras, áreas, agenda e automações existentes.
- Confirmar que a navegação principal contém cinco destinos e troca para `NavigationRail` em paisagem/tablet.
- Confirmar que `VigiaTheme`, `VigiaModeCard` e `VigiaQuickAction` são reutilizáveis e não dependem de assets do mockup.
- Executar `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh`.
- Flutter/Android SDK não estão instalados neste ambiente; `flutter analyze`, `flutter test` e o build APK final precisam ser confirmados pelo workflow.

## 1.0.112+112 — Próximos pontos e mapa expandido

- Validar separação entre **Próximos pontos** e **Configurações do mapa e percurso**.
- Validar filtros rápidos e indicação Online/Offline.
- Validar Câmera: Ligada, Desligada e Mapa na área principal em retrato e paisagem.
- Validar `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh`.

## 1.0.111+111 — mapa e percurso com lista offline e alertas

- Confirmar que o botão **Mapa** da fileira fixa retrato e o botão **Mapa** do painel em paisagem agora abrem `_showMapExplorerSheet()`.
- Confirmar que o bottom sheet **Mapa e percurso** oferece raio, categorias, botões **Buscar agora**, **Salvar lista offline**, **Buscar e salvar**, **Mapas offline** e **Abrir mapa completo**.
- Confirmar que `RouteExplorerService` persiste preferências e lista offline em `route_explorer_state.json`.
- Confirmar que `searchNow()` usa Overpass/OpenStreetMap online e recai para a lista offline quando a requisição falhar.
- Confirmar que os switches de **Fala** e **Notificação** controlam os alertas automáticos de aproximação.
- `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh` devem passar em `1.0.111+111`.
- Flutter/Android SDK não estão instalados neste ambiente; `flutter analyze`, `flutter test` e o build APK final ainda precisam ser confirmados pelo workflow.

## 1.0.110+110 — quinto botão de mapa + Android-APK-78

- Confirmar que `_buildPortraitActionRow()` contém cinco `_DashboardActionButton` e inclui o rótulo **Mapa** entre Câmera e Áudio.
- Confirmar que o botão chama `_setMonitorMapVisibilityQuick()` com `always` ao mostrar e `hidden` ao ocultar.
- Confirmar que `.gitignore` existe e bloqueia `*.jks`, `*.keystore` e `android/key.properties`.
- Confirmar que `tool/package_source.sh` mantém `.gitignore` na lista de arquivos obrigatórios do ZIP.
- `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh` devem passar em `1.0.110+110`.
- Flutter/Android SDK não estão instalados neste ambiente; `flutter analyze`, `flutter test` e o build APK final ainda precisam ser confirmados pelo workflow.

## 1.0.109+109 — atalho global do mapa no monitor

- Confirmar presença dos rótulos **Mostrar mapa**, **Ocultar mapa** e **Mapa automático** em `lib/screens/monitor_screen_fullscreen.dart`.
- Confirmar que `_monitorMenu()` continua sendo reutilizado na tela retrato, paisagem, multicâmera e tela inteira.
- Confirmar que o atalho altera `MonitorMapVisibilityMode.always`, `hidden` e `automatic` via `MapRouteService`, sem criar persistência paralela.
- `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh` devem passar em `1.0.109+109`.
- Flutter/Android SDK não estão instalados neste ambiente; `flutter analyze`, `flutter test` e o build APK final ainda precisam ser confirmados pelo workflow.

## 1.0.108+108 — correção do Android-APK-76

- Android-APK-76: `flutter analyze` e os testes chegaram a passar; a falha ocorreu depois de ~4 minutos em `:app:processReleaseResources`.
- AAPT reportou exatamente três recursos ausentes: `mipmap/ic_launcher`, `style/LaunchTheme` e `style/NormalTheme`.
- Os recursos foram restaurados em `android/app/src/main/res`, incluindo tema noturno, fundo de lançamento e launcher adaptativo.
- A verificação preventiva passa a checar presença dos recursos e referências do Manifest antes da etapa longa de build.
- O workflow também inclui esses recursos no teste de integridade usado para decidir se precisa executar o bootstrap Android.
- `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh` devem passar em `1.0.108+108`.
- Flutter/Android SDK não estão instalados neste ambiente; `flutter analyze`, `flutter test` e o build APK final ainda precisam ser confirmados pelo workflow.

## 1.0.107+107 — correção do Android-APK-75

- Android-APK-75: `flutter analyze` passou sem issues e os 176 testes passaram antes da etapa de build.
- Falha isolada em `android/app/build.gradle.kts`: `BaseAppModuleExtension`, `kotlinOptions` e `jvmTarget` legados foram tratados como erros durante a compilação do script com Gradle 9.1.0 / AGP 9.0.1.
- `build.gradle.kts` alinhado ao template oficial do Flutter 3.44.9, removendo `id("kotlin-android")` explícito e migrando para `kotlin.compilerOptions.jvmTarget`.
- Verificadores adicionados para impedir retorno do plugin Kotlin explícito e do bloco `kotlinOptions` no módulo app.
- A compilação única da 1.0.106 permanece intacta; o próximo workflow deve confirmar geração dos quatro APKs e medir o tempo real com cache.
- Flutter/Android SDK não estão instalados neste ambiente; `flutter analyze`, `flutter test` e o build APK desta versão ainda precisam ser confirmados pelo workflow.

## 1.0.106+106 — otimização do Android-APK-74

- Baseline do log: job total aproximado de 10m16s; etapa `Build APKs release` aproximada de 7m30s, com duas chamadas `assembleRelease` (375,8s + 67,1s).
- Workflow alterado para uma única chamada `gradle :app:assembleRelease --build-cache --parallel`.
- `VIGIAIA_CI_MULTI_APK=1` habilita universal + três ABIs somente no CI; builds locais permanecem no comportamento padrão.
- Empacotamento valida quatro saídas pelo `output-metadata.json`: universal, armeabi-v7a, arm64-v8a e x86_64.
- `org.gradle.caching=true`, `org.gradle.parallel=true` e `setup-gradle@v6` configurados.
- Bootstrap Android passa a ser condicional e reproduz as propriedades de otimização quando necessário.
- Flutter/Android SDK não estão instalados neste ambiente; `flutter analyze`, `flutter test` e o tempo real do novo build precisam ser confirmados no próximo workflow.

## 1.0.105+105 — Android-APK-73

- Confirmar ausência de `dart:typed_data` em `lib/screens/map_monitoring_screen.dart`.
- Confirmar ausência do import direto `package:camera/camera.dart` em `lib/sources/local_camera_source.dart`.
- `python3 tool/check_version_sync.py`: **PASSOU** em `1.0.105+105`.
- `bash tool/verify_project.sh`: **PASSOU** em `1.0.105+105`, incluindo as guardas do Android-APK-73.
- Flutter/Dart/Android SDK não estão instalados neste ambiente; `flutter analyze`, `flutter test` e o build APK precisam ser confirmados pelo workflow.

## 1.0.104+104 — painel Stadia + seleção offline + mapa multicâmera

- Confirmar painel Stadia com status configurado/não configurado, Colar, Ver, Copiar, Testar, Trocar e Remover.
- Confirmar que o campo de edição permanece vazio ao abrir quando já existe chave, enquanto o status mascarado identifica a configuração existente.
- Confirmar seleção offline com alternância Mapa/Área e botões de zoom − / z / +.
- Confirmar que o mapa completo mantém telemetria no topo e somente Iniciar/Encerrar rota na barra inferior.
- Confirmar botão de mostrar/ocultar câmeras no mapa.
- Confirmar PiP principal alternando formato vertical/horizontal quando `previewAspectRatio` muda.
- Confirmar segunda câmera abaixo da principal por padrão e ambos os PiPs arrastáveis independentemente.
- Confirmar ausência da faixa textual Local sobre o PiP.
- `python3 tool/check_version_sync.py`: **PASSOU** em `1.0.104+104`.
- `bash tool/verify_project.sh`: **PASSOU** em `1.0.104+104`.
- Flutter/Dart/Android SDK não estão instalados neste ambiente; `flutter analyze`, `flutter test` e o build APK precisam ser confirmados pelo workflow.

## 1.0.103+103 — créditos de mapas + Android-APK-71

Data: 2026-09-23. Base preservada: 1.0.102+102.

- Confirmar que o `unnecessary_non_null_assertion` apontado em `offline_map_manager_sheet.dart` pelo Android-APK-71 foi removido.
- Abrir o planejador de **Região atual / Selecionar região / Trajeto** e conferir **Créditos estimados** junto de tiles e tamanho.
- Confirmar card mensal com usados/limite/restantes e configuração de limite local por presets e valor personalizado.
- Tentar configurar um download acima do saldo local e confirmar botão **Baixar** bloqueado/aviso de créditos.
- Projetar consumo acima de 80% e confirmar aviso preventivo.
- Iniciar um download e conferir progresso com tiles, créditos aproximados e bytes.
- Fechar/reabrir o app e confirmar persistência do contador mensal e do limite; a janela mensal deve reiniciar automaticamente quando o mês mudar.
- Confirmar que importação de MBTiles/link externo não é somada como consumo Stadia direto.
- `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh` devem passar em `1.0.103+103`.
- Flutter/Dart/Android SDK não estão instalados neste ambiente; `flutter analyze`, `flutter test` e build APK precisam ser confirmados pelo workflow.

## 1.0.102+102 — ajuda para API de mapas offline

Data: 2026-09-23. Base preservada: 1.0.101+101.

- Abrir **Mapas offline > Configurar fonte** e confirmar o botão **Como conseguir a chave?**.
- Na ajuda, conferir os passos **Manage Properties** e **Authentication Configuration**, além do aviso de proteção pelo Android Keystore.
- Tocar **Abrir painel** e confirmar abertura de `https://client.stadiamaps.com/dashboard/` no navegador.
- Tocar **Instruções oficiais** e confirmar abertura da documentação de API keys.
- Em aparelho sem handler de navegador, confirmar fallback que copia o link para a área de transferência.
- Salvar/remover uma chave e confirmar que o fluxo anterior de mapas offline continua funcional.
- `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh` devem passar em `1.0.102+102`.
- Flutter/Dart/Android SDK não estão instalados neste ambiente; `flutter analyze`, `flutter test` e build APK precisam ser confirmados pelo workflow.

## 1.0.101+101 — limite offline inteligente e mapa de navegação

Data: 2026-09-23. Base preservada: 1.0.100+100.

- Em **Região atual**, mover raio e zoom e confirmar que a combinação nunca permanece acima do espaço seguro restante; aumentar zoom deve reduzir o raio quando necessário.
- Em **Trajeto**, aumentar margem e detalhe e confirmar ajuste equivalente sem permitir download acima do limite.
- Confirmar que **Ajustar ao limite disponível** aproxima a estimativa do máximo seguro sem excedê-lo e que a tela diferencia 100 MB totais da reserva técnica.
- Em **Selecionar região**, arrastar o quadro e redimensionar pelos cantos; confirmar que o bounds retornado corresponde somente à área destacada, não à tela inteira.
- No mapa completo, validar altitude, rumo, GPS, **Seguindo / Mapa livre** e marcador orientado pelo heading quando disponível.
- Confirmar que câmera flutuante, rota compartilhada, pausa/retomada e GPX continuam operacionais.
- `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh` devem passar em `1.0.101+101`.
- Flutter/Dart/Android SDK não estão instalados neste ambiente; `flutter analyze`, `flutter test` e build APK precisam ser confirmados pelo workflow.

## 1.0.100+100 — buildfix Android-APK-68

Data: 2026-09-23. Base preservada: 1.0.99+99.

- Log Android-APK-68: `flutter analyze` encontrou exatamente 4 apontamentos: 2x `invalid_use_of_protected_member`, `prefer_conditional_assignment` e `unnecessary_non_null_assertion`.
- `monitor_screen_offline_map.dart` agora reutiliza `_refresh()` em vez de chamar `setState` diretamente pela extension.
- `map_route_service.dart` usa `??=` para a assinatura do stream; `offline_map_service.dart` remove o `!` redundante de `earliestExpiry`.
- As funções da 1.0.99 foram preservadas sem alteração funcional.
- `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh` devem passar em `1.0.100+100`.
- Flutter/Dart/Android SDK não estão instalados neste ambiente; `flutter analyze`, `flutter test` e build APK precisam ser confirmados pelo workflow.

## 1.0.99+99 — download offline direto, pausa de rota e GPX

Data: 2026-09-23. Base preservada: 1.0.98+98.

- Configurar uma API key válida da fonte offline, fechar/reabrir o app e confirmar que a credencial continua utilizável sem aparecer em texto puro no manifesto.
- Testar **Região atual**, **Selecionar região** e **Trajeto**; conferir estimativa de tiles/tamanho e bloqueio quando a soma dos mapas diretos exceder o limite de segurança ou o espaço livre.
- Durante um download, testar **Pausar**, **Continuar** e **Cancelar**; confirmar progresso em tiles/bytes e remoção do arquivo parcial ao cancelar/falhar.
- Concluir um download, ativar o MBTiles e testar modo Offline sem internet; sair dos bounds do pacote e confirmar aviso **Fora da área offline**.
- Verificar atualização recomendada após expiração do cache declarada pelo servidor e opção de atualizar pacote gerado pela fonte integrada.
- Iniciar rota, pausar, deslocar-se, continuar e confirmar que o novo trecho começa em outro segmento sem somar uma linha/salto artificial.
- Exportar GPX e validar XML 1.1 com `<trkseg>`, `<trkpt>`, elevação/tempo quando disponíveis.
- Confirmar que `OfflineMapService` não usa `tile.openstreetmap.org` para download em massa; o OSM público permanece apenas como camada online interativa.
- `python3 tool/check_version_sync.py`: aprovado em `1.0.99+99`; `bash tool/verify_project.sh`: aprovado, incluindo limite estrutural, mapas offline, rota/GPX e proteções históricas.
- Flutter/Dart/Android SDK não estão instalados neste ambiente; `flutter analyze`, `flutter test` e build APK precisam ser confirmados no workflow.

## 1.0.98+98 — mapa adaptativo, rota persistente e offline ampliado

Data: 2026-09-23. Base preservada: 1.0.97+97.

- Verificar no Monitor **Automático / Sempre mostrar / Ocultar**: em casa sem Bike/rota/movimento o mapa deve sumir; com Bike conectada ou rota ativa deve aparecer.
- Iniciar a rota no mapa completo, voltar ao Monitor e confirmar que distância, linha, início/fim e cronômetro representam a mesma sessão compartilhada.
- Reiniciar o app durante uma rota e confirmar restauração do trajeto/estado persistido em `map_route_state.json`.
- Abrir **Mapas offline**, importar um `.mbtiles` válido pelo seletor Android e confirmar validação/ativação; testar também download por link direto autorizado.
- Testar **Região atual**, **Selecionar região** e **Trajeto** e conferir estimativa de tamanho e espaço livre antes da importação/download.
- Confirmar rótulos compactos **Online / Offline / Mapa local** no mapa completo e câmera PiP ainda arrastável por toda a área útil.
- Confirmar que `tile.openstreetmap.org` não é usado pelo serviço de download offline.
- `python3 tool/check_version_sync.py`: aprovado em `1.0.98+98`; `tool/verify_project.sh`: aprovado com as novas proteções de mapa/rota/offline.
- Scripts `tool/*.sh`: sintaxe Bash validada; `app_identity.json`: JSON válido; `MainActivity.kt` e `tool/android/MainActivity.kt`: bytes idênticos.
- Flutter/Dart/Android SDK não estão instalados neste ambiente; `flutter analyze`, `flutter test` e build APK precisam ser confirmados no workflow.

## 1.0.97+97 — buildfix de sincronização do AppMetadata

Data: 2026-09-23. Base preservada: 1.0.96+96.

- Log `Android-APK-65`: `flutter analyze` passou sem issues; `flutter test` falhou somente em `test/app_metadata_test.dart` porque esperava `1.0.95`/build `95` enquanto AppMetadata estava em `1.0.96`/build `96`.
- Teste corrigido e incrementado junto com a entrega para `1.0.97+97`.
- `tool/check_version_sync.py` ampliado para validar o próprio teste de metadados.
- Funcionalidades de mapa offline e câmera flutuante preservadas.
- `python3 tool/check_version_sync.py`: aprovado em `1.0.97+97`.
- `tool/verify_project.sh`: aprovado.
- Flutter/Dart/Android SDK não estão instalados neste ambiente; `flutter analyze`, `flutter test` e o build APK precisam ser confirmados no workflow.

## 1.0.96+96 — mapas offline e PiP do mapa completo

- `tool/verify_project.sh` deve confirmar a dependência `flutter_map_mbtiles`, o serviço de pacotes offline, os três modos de mapa e a câmera principal arrastável.
- Validar no aparelho: baixar um `.mbtiles` válido por link direto, alternar Automático/Online/Offline, reiniciar o app e confirmar persistência do pacote ativo.
- Validar no Monitor: abrir o mapa completo, mover o PiP da câmera pelos quatro cantos e confirmar que o trajeto/mapa continuam interativos.
- Confirmar pelo workflow `flutter analyze`, `flutter test` e o build Android, pois o ambiente de edição pode não conter Flutter/Android SDK.


Data: 2026-09-23. Base preservada: 1.0.95+95.

## Executado nesta entrega

| Verificação | Resultado |
|---|---|
| Mapas offline 1.0.96 | MBTiles por link direto; modos Automático/Online/Offline; persistência, progresso e exclusão |
| `bash tool/verify_project.sh` | Passou, incluindo sincronização de versão, contratos antigos e a proteção contra regressão do lint do Android-APK-59 |
| `flutter analyze` / `flutter test` / build Android | Não executados localmente: Flutter, Dart e Android SDK não estão instalados neste ambiente; confirmar no workflow |
| Sincronização de versão | `pubspec.yaml`, AppMetadata, app_identity.json, Mudanças, README, CHANGELOG, arquitetura e release notes em 1.0.96+96 |
| Fontes Android espelhadas | `MainActivity.kt`, `AlertAudioPlayer.kt` e `AudioResourceCatalog.kt` são idênticos entre `tool/android` e o projeto Android gerado |
| JSON e scripts shell | Estruturas válidas e scripts sem erro de sintaxe do Bash |
| Áudios padrão | 78 arquivos M4A preservados em `custom_audio` e `res/raw`; verificador confirma igualdade dos bytes |
| Codec dos áudios | `ffprobe` validou os 78 arquivos como AAC-LC, mono, 24 kHz e com duração positiva |
| Transporte remoto | Sequência, timestamp UTC, cache desativado, resposta 204 e descarte de duplicatas protegidos pelo verificador |
| Política de orientação 1.0.92 | App normal limitado a retrato; Transmissão libera rotação automática; Monitor em tela inteira não força paisagem |
| Rotação da câmera | `SharedLocalCameraService` preserva cálculo por `sensorOrientation` + `deviceOrientation` para envio coerente do frame |
| Tela vertical do monitor | Câmera maior, mini-mapa em retrato, ações horizontais e painel avançado sob demanda implementados no `MonitorScreen` |
| Interface | Faixa permanente de receptor/transmissor protegida pelo verificador e ligada ao Status da sessão |
| Dashboard paisagem legado | Código preservado por compatibilidade histórica, mas não é alcançado pela política normal de orientação da 1.0.92 |
| Buildfix Android-APK-57 | Extensão do dashboard sem chamadas diretas a `setState`, eliminando `invalid_use_of_protected_member` do `flutter analyze` |
| Buildfix Android-APK-59 | Placeholder duplo do `separatorBuilder` corrigido em `monitor_screen_portrait.dart`, eliminando `unnecessary_underscores` do `flutter analyze` |
| Buildfix Android-APK-40 | Operador nulo desnecessário e import redundante removidos |
| Seleção de modo | Normal, Monitor, Bike e Transmissão persistidos por `AppLaunchModeService` e protegidos por teste |
| Monitor | Mantido em retrato inclusive na tela inteira; HUD e saída explícita continuam protegidos pelo verificador |
| Modo Câmera | Estado parado integrado, painel adaptativo e saída/parada claras protegidos pelo verificador |
| Buildfix Android-APK-43 | `unnecessary_non_null_assertion` removido de `camera_mode_screen.dart` e protegido contra regressão |
| Telemetria de áudio | Foco, fase, códigos MediaPlayer, origem, arquivo, volume, rota, tempos e fallback protegidos pelo verificador |
| Catálogo de áudio | 78 slots Dart, 78 referências `R.raw` explícitas e 78 M4A comparados automaticamente |
| Fluxo Monitor | Tela receptora, QR, endereço/chave manual, Central multicâmera e fonte Celular remoto protegidos pelo verificador |
| Câmeras adaptativas | Política testável para uma câmera integral, duas empilhadas no retrato e duas lado a lado na paisagem |
| Segunda câmera | Preview e status independentes, sem duplicar o pipeline de IA da câmera principal |
| Segunda câmera frontal de teste | Fonte preview-only em baixa resolução, PiP no retrato e IA preservada somente na principal; compatibilidade simultânea depende do aparelho |
| Sensores Bike | Hall, temperatura, pneus, bateria e distância normalizados, exibidos e enviados pelo status remoto |
| Permissões | Pedido automático nativo removido; novo marcador exige guia antes da escolha de modo |
| Retorno do transmissor | Botão superior e retorno do Android voltam à seleção, com confirmação de parada |
| Android-APK-47 | Oito usos protegidos de `setState` e uma referência estática sem qualificação corrigidos |
| Navegação principal | Quatro destinos: Início, Histórico, Monitor e Câmeras; Bike ausente dos índices compartilhados |
| Acesso ao Bike | Preservado na seleção inicial e adicionado em Configurações > Monitoramento |
| Histórico | Filtros adaptativos, ícones, ação Salvar e confirmação obrigatória antes da exclusão |
| ESP32 | Painel próprio, persistência protegida, `/status`, `POST /config`, sensores e câmera futura |
| Fontes | Local, RTSP, Celular remoto e ESP32 disponíveis na Central; ESP32 também pode ser segunda câmera |
| APK | Nome versionado, cache de Gradle/modelos, upload sem recompressão e relatório de tamanho |
| Android-APK-49 | `BuildContext` protegido por `mounted` antes da escolha do destino de exportação |
| Monitor vertical | Câmera e mapa priorizados; detecções detalhadas em painel inferior arrastável sob demanda |
| Bateria | Telemetria local aparece uma vez; bateria adicional somente para fonte remota |
| Telemetria ESP32/Bike | Faixa superior reorganizada em uma única linha horizontal rolável, sem grade quebrada no retrato |
| Diagnóstico | Estados Serviço/Câmera/Frames/IA/LAN/clientes/Permissões/2º plano ficam em faixa horizontal compacta; ações de 30 s, 60 s e Exportar permanecem juntas |

## Roteiro da 1.0.96

- abrir o mapa completo pelo Monitor e confirmar que a câmera principal aparece em PiP flutuante; arrastar pelos quatro cantos e também sobre regiões centrais do mapa;
- confirmar que mover a câmera não impede pan/zoom do mapa fora da janela PiP e que o trajeto permanece visível;
- abrir **Mapas offline**, colar um link direto para um `.mbtiles` raster válido, acompanhar o progresso e confirmar ativação automática ao concluir;
- testar **Automático**, **Online** e **Offline**; no modo Offline, desligar dados/Wi-Fi e confirmar que a região contida no MBTiles continua visível;
- reiniciar o app e confirmar persistência do pacote ativo e do modo selecionado;
- excluir o pacote ativo e confirmar que o serviço volta a um estado seguro sem deixar o mapa travado;
- abrir o mapa pelo modo Bike e confirmar que ele continua funcionando sem PiP de câmera;
- confirmar que nenhum download em massa usa `tile.openstreetmap.org`; a camada pública continua somente para visualização online normal.

## Roteiro da 1.0.95

- abrir o Monitor em retrato com ESP32/Bike ativo e confirmar que os cards de velocidade, temperatura, pneus e distância ficaram mais estreitos, sem cortar textos;
- confirmar que **Câmera**, **Áudio**, **Painel** e **Ajustes** aparecem juntos e que Áudio/Painel/Ajustes não parecem desabilitados;
- tocar em qualquer área livre do mini-mapa e confirmar abertura da tela completa; testar separadamente **Rota**, localização e zoom;
- tocar em **Câmera** e conferir câmera local, câmera frontal, ESP32 e demais fontes cadastradas, além da seleção entre uma e duas câmeras;
- confirmar que **Uma ou duas câmeras** e **Status da sessão** não aparecem mais no menu de três pontos e que o ícone de áudio não aparece mais no topo do Monitor;
- abrir **Painel** e conferir os seis atalhos na mesma linha em largura normal, sem sobreposição; em tela estreita, confirmar quebra responsiva;
- dar duplo toque na imagem principal e confirmar entrada em tela inteira;
- confirmar que o selo da câmera local mostra apenas **Local** em formato reduzido;
- ativar a câmera frontal de teste e arrastar o PiP para os quatro cantos da área de vídeo, verificando que ele não sai da câmera nem cobre mapa/botões inferiores;
- confirmar que as caixas verdes de detecção continuam apenas como overlay visual e que IA/alertas não mudaram nesta entrega.

## Roteiro da 1.0.94

- abrir o Monitor em retrato e confirmar que o mini-mapa ficou mais alto e que o resumo **Detectados** desceu sem cortar a parte inferior;
- confirmar que **Abrir mapa**, **Áudio**, **Painel** e **Ajustes** aparecem simultaneamente, sem rolagem horizontal, e que os quatro botões ficaram mais baixos/compactos;
- com GPS disponível, conferir que o canto inferior esquerdo do mapa mostra somente a altitude em metros, menor que antes, sem o texto **Bike**; validar que a distância continua na faixa superior;
- com ESP32/Bike ativo, verificar que velocidade, temperatura, pneus e distância usam cards menores, sem texto sobreposto ou cortado;
- abrir **Mais opções > Uma ou duas câmeras > Teste: câmera frontal** e confirmar que a câmera principal continua ocupando toda a área enquanto a frontal aparece em PiP pequeno no canto inferior direito;
- confirmar que a IA, caixas de detecção e alertas continuam ligados somente à câmera principal e que mapa/sensores/atalhos continuam presentes com a frontal ativa;
- em aparelho que não aceite câmera frontal + traseira simultâneas, confirmar que a falha fica restrita ao PiP e que a câmera principal continua funcional; depois desativar a segunda câmera e testar novamente;
- repetir com uma segunda fonte real, quando disponível, para confirmar que o mesmo espaço PiP é reutilizado no retrato.

## Roteiro da 1.0.93

- abrir o Monitor em retrato e confirmar que o bloco grande **Detectados agora** não ocupa mais a parte inferior da tela;
- provocar uma ou mais detecções e confirmar que o resumo compacto mostra quantidade e o objeto de maior confiança sem cortar o texto;
- tocar no resumo **Detectados** e confirmar que o painel sobe, pode ser arrastado entre aproximadamente 34% e 90% da tela e permite rolar a lista;
- confirmar que o mini-mapa mostra **Mapa**, **Ao vivo**, **Rota** e a distância com controles compactos de localização/zoom sem sobreposição;
- com sensores Bike ativos, conferir temperatura, pressão dianteira/traseira, velocidade e distância na faixa superior reduzida;
- testar telas estreitas e fonte grande para verificar que os novos rótulos curtos não cortam nem se sobrepõem.

## Roteiro da 1.0.81

- abrir o Monitor com câmera local e confirmar apenas uma porcentagem de bateria;
- confirmar que “Câmera local” mostra estado da imagem, sem repetir a bateria do receptor;
- provocar uma detecção e confirmar que a câmera não muda de altura e que a parte inferior não sobe;
- rolar apenas o conteúdo interno de `Detectados agora` quando houver vários objetos;
- testar Ao vivo, IA ativa, Painel e Ajustes na faixa acima da câmera;
- adicionar uma segunda câmera e confirmar divisão vertical dentro do mesmo cartão;
- girar para paisagem e confirmar que o HUD e a composição lado a lado continuam funcionando;
- executar o workflow e confirmar que `flutter analyze` ultrapassa o ponto que falhou no Android-APK-49.

## Roteiro da 1.0.80

- abrir Histórico em retrato e paisagem e confirmar filtros 2×2 ou em linha, sem cortes;
- abrir uma detecção, salvar a captura e conferir o arquivo em Downloads/Vigia IA ou no local escolhido;
- tentar excluir pelo card e pelo detalhe, cancelando e confirmando em testes separados;
- cadastrar um ESP32, testar `/status`, ajustar sensores e aplicar a configuração em `/config`;
- habilitar a câmera ESP32 e confirmar sua presença na Home, em Fonte, em `2ª câmera` e na página Câmeras;
- confirmar que a câmera principal executa IA e que a segunda continua apenas como preview;
- no workflow, confirmar `VigiaIA-v1.0.80.apk` e revisar `apk-size-report.txt` antes de qualquer redução de dependência.

## Roteiro da 1.0.79

- confirmar que o menu inferior em retrato mostra exatamente quatro opções e não corta os rótulos;
- confirmar que a barra lateral em paisagem mostra os mesmos quatro destinos;
- navegar entre Início, Histórico, Monitor e Câmeras e verificar os índices selecionados;
- abrir Configurações > Monitoramento > Modo Bike;
- na tela Bike, usar a engrenagem para voltar às configurações e usar Abrir Monitor para testar o HUD;
- selecionar Bike como modo inicial e confirmar que o app ainda abre diretamente nessa tela;
- executar `flutter analyze` e confirmar que os nove apontamentos do Android-APK-47 não reaparecem.

## Roteiro da 1.0.78

- em retrato, abrir uma câmera e confirmar que ela ocupa toda a área reservada ao vídeo;
- adicionar uma segunda câmera pelo Monitor ou pela Central e confirmar divisão vertical sem trocar de tela;
- girar para paisagem e confirmar as duas imagens lado a lado; remover a segunda e confirmar expansão da principal;
- validar no topo velocidade Hall, temperatura, pressão dianteira/traseira, bateria e distância sem texto cortado;
- confirmar que detecções, histórico, alertas e áudio pertencem à câmera principal/receptor;
- iniciar o transmissor, usar o botão Voltar e o gesto do Android, confirmar a parada e escolher outro modo;
- em instalação limpa/atualizada, confirmar Acesso inicial antes do pedido de permissão e antes da seleção de modo;
- remover câmera ou rede local nos ajustes e reabrir o app para conferir a orientação pontual.

## Orientação e transmissão

Validações manuais recomendadas no aparelho:

- abrir o Monitor e confirmar que permanece em retrato mesmo ao girar o aparelho;
- confirmar que temperatura, pressão dos pneus, velocidade e status continuam acessíveis no topo quando a telemetria Bike estiver ativa;
- entrar em tela cheia e confirmar que o Monitor continua vertical, com botões para sair da tela inteira e sair do monitoramento;
- abrir o Modo Transmissão e confirmar que ele acompanha a posição física do celular;
- colocar o transmissor deitado e confirmar que o frame chega ao receptor com a orientação correta;
- iniciar transmissão e confirmar botão Parar e saída clara no topo.

## Seleção inicial de modo

Validações manuais recomendadas no aparelho:

- concluir Acesso inicial e conferir as quatro opções: Normal, Monitor, Bike e Transmissão;
- escolher Modo Transmissão em um aparelho e confirmar endereço, chave, QR, status e conexão;
- escolher Modo Monitor no receptor, escanear QR ou preencher endereço/chave;
- confirmar que o Monitor abre como Celular remoto e que IA, alertas, histórico e áudios ficam no receptor;
- trocar o modo em Configurações > Monitoramento > Modo inicial.

O fluxo atualizado mantém o guia de permissões em primeiro lugar. Quando ele termina, o app abre `LaunchModeScreen` e pede a escolha entre:

- Modo normal: abre a Home;
- Modo Monitor: abre o fluxo de conexão do receptor;
- Modo Bike: abre o painel Bike;
- Modo transmissão: abre o Modo Câmera.

A decisão é salva em `launch_mode.json` e pode ser revista em Configurações > Monitoramento > Modo inicial.

## Correção do Android-APK-43

O pacote de logs anexado mostra que o workflow parou em `flutter analyze` antes dos testes e do APK:

- `unnecessary_non_null_assertion` em `camera_mode_screen.dart:212`.

O operador foi removido. O aviso de depreciação do Node apareceu apenas durante a tentativa posterior de enviar cobertura e não causou a falha do build.

## Teste acrescentado

Os testes de telemetria e coordenação de voz passam a confirmar que:

- o relatório JSON usa `schemaVersion: 3`;
- código e etapa da falha de áudio aparecem no resumo e no JSON;
- a decisão de fallback para TTS carrega erro, fase, origem, foco e volume;
- o diagnóstico textual inclui a causa nativa interpretada.

## Pendente no workflow e no dispositivo

Neste ambiente local, os comandos `flutter` e `dart` não estão instalados. `bash tool/verify_project.sh` e `tool/check_version_sync.py` passaram, mas `flutter analyze`, `flutter test` e a compilação do APK assinado ainda precisam ser confirmados pelo workflow. O Android-APK-59 mostra que a tentativa anterior chegou ao `flutter analyze` e falhou somente no lint `unnecessary_underscores` agora corrigido.

O teste final em aparelho deve confirmar áudio integrado, override importado/gravado, volume, Bluetooth/alto-falante e fallback TTS. Se houver falha, o diagnóstico agora informa código `what/extra`, etapa, origem, foco, arquivo, tamanho, rota e tempos da tentativa. O teste em dois celulares continua necessário para latência visual, baterias, reconexão, rotação e tela inteira.

## Mapa/GPS 1.0.86

- verificação estática: permissões `ACCESS_COARSE_LOCATION` e `ACCESS_FINE_LOCATION` presentes;
- dependências cartográficas declaradas no `pubspec.yaml`;
- acesso ao mapa integrado ao Modo Bike sem alterar os quatro destinos da navegação principal;
- tratamento de GPS desligado e permissões negada/bloqueada implementado;
- `flutter analyze`, `flutter test` e build Android ainda precisam ser confirmados no workflow porque o ambiente local desta entrega não possui Flutter/Android SDK completo.
