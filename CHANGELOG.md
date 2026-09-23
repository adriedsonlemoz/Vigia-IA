# CHANGELOG

## 1.0.99+99 — 2026-09-23

- Adicionado download direto de mapas offline por **região** ou **corredor do trajeto** usando fonte configurada explicitamente pelo usuário, sem prefetch de `tile.openstreetmap.org`.
- Integração inicial com raster **Stadia Maps Alidade Smooth** mediante API key própria do usuário; a credencial é protegida pelo Android Keystore e não é incluída no projeto.
- O downloader estima tiles/tamanho, verifica espaço livre, controla o limite pelo total de mapas diretos armazenados no aparelho, mostra progresso em tiles/bytes e permite **Pausar / Continuar / Cancelar**.
- O pacote baixado é construído como MBTiles raster SQLite, validado antes da ativação e registra bounds, zoom, provedor e validade estimada do cache.
- O mapa completo alerta quando a posição está **fora da área offline** ativa e o gerenciador sinaliza pacote que recomenda atualização.
- `MapRouteService` ganhou **Pausar/Continuar** rota com segmentação para evitar salto de distância após a retomada.
- Adicionada exportação **GPX 1.1** da rota compartilhada pelo seletor nativo, preservando segmentos, coordenadas, elevação e tempo quando disponíveis.
- A importação de MBTiles local e o download de arquivo MBTiles por link direto foram preservados como alternativas.
- Adicionada dependência direta `sqlite3 ^2.9.4` para criação/leitura controlada do banco MBTiles no aparelho.
- Versionamento, AppMetadata, app_identity.json, Mudanças, README, CHANGELOG, arquitetura, validação, testes e verificadores sincronizados em `1.0.99+99`.

## 1.0.98+98 — 2026-09-23

- Adicionado `MapRouteService` como sessão única e persistente de localização/trajeto para o mini-mapa do Monitor e o mapa completo.
- O Monitor ganhou política de mapa **Automático / Sempre mostrar / Ocultar**; no automático, o mapa some no uso doméstico e reaparece com Bike conectada, rota ativa ou movimento recente pelo GPS.
- O trajeto, início/fim, distância, estado de rastreamento e preferência de visibilidade são gravados em `map_route_state.json` e restaurados após reinício do app.
- O mapa completo passa a refletir imediatamente a mesma rota do Monitor e mantém o PiP da câmera principal arrastável.
- O indicador de fonte do mapa foi simplificado para **Online**, **Offline** ou **Mapa local** conforme o modo/pacote ativo.
- O gerenciador de mapas offline agora importa `.mbtiles` pelo seletor de arquivos do Android, além de baixar por link direto.
- Adicionados planejadores de **Região atual**, **Selecionar região** e **Trajeto**, com estimativa de tiles, tamanho aproximado e espaço livre; a obtenção do pacote continua exigindo fonte autorizada/importação e não usa download em massa do servidor público do OpenStreetMap.
- Versionamento, AppMetadata, app_identity.json, Mudanças, README, CHANGELOG, arquitetura, validação, testes e verificadores sincronizados em `1.0.98+98`.

## 1.0.97+97 — 2026-09-23

- Corrigido `test/app_metadata_test.dart`, que ainda validava `1.0.95+95` e fazia o workflow falhar depois que AppMetadata já estava em `1.0.96+96`.
- `tool/check_version_sync.py` agora valida também as expectativas de versão/build do teste de AppMetadata para impedir nova regressão.
- Funcionalidades da 1.0.96 preservadas sem alterações de comportamento.
- Versionamento, AppMetadata, app_identity.json, Mudanças, README, CHANGELOG, arquitetura, validação, testes e verificadores sincronizados em `1.0.97+97`.

## 1.0.96+96 — 2026-09-23

- Adicionado suporte a mapas offline raster por pacotes `.mbtiles` usando `flutter_map_mbtiles`.
- Novo `OfflineMapService` persiste pacotes no armazenamento interno, valida SQLite/MBTiles e o formato raster PNG/JPG/WebP, acompanha progresso, ativa e exclui mapas locais.
- Gerenciador **Mapas offline** permite baixar um pacote por link HTTP/HTTPS direto e alternar entre **Automático**, **Online** e **Offline**.
- No modo Automático, o MBTiles ativo funciona como camada local de base/fallback e a camada online continua atualizando o mapa quando houver rede; o zoom nativo declarado pelo pacote é respeitado para permitir overzoom correto.
- O app não realiza download em massa do servidor público do OpenStreetMap; pacotes offline devem vir de uma fonte/servidor autorizado para esse uso.
- Ao abrir o mapa completo pelo Monitor, a câmera principal passa a aparecer em PiP flutuante.
- O PiP da câmera principal pode ser arrastado livremente por toda a área útil do mapa para não encobrir o trajeto.
- O mapa aberto pelo modo Bike continua disponível sem exigir câmera.
- Versionamento, AppMetadata, app_identity.json, Mudanças, README, CHANGELOG, arquitetura, validação e verificadores sincronizados em `1.0.96+96`.

## 1.0.95+95 — 2026-09-23

- Cards de velocidade, temperatura, pneus e distância ficaram mais estreitos e densos, reduzindo espaço vazio à direita e permitindo mais telemetria na mesma linha.
- O mini-mapa vertical ficou mais alto; tocar na área útil do mapa abre a tela completa, mantendo os controles de rota/localização/zoom.
- **Abrir mapa** foi removido da barra inferior e substituído por **Câmera**.
- Novo hub **Câmeras** reúne fonte principal, modo de uma ou duas câmeras, câmera local, frontal de teste, ESP32 e demais fontes cadastradas, com acesso à configuração avançada para RTSP/outro celular.
- **Uma ou duas câmeras** e **Status da sessão** foram removidos do menu de três pontos para eliminar duplicações; o botão de áudio do topo também foi removido porque a ação já existe na barra inferior.
- **Áudio**, **Painel** e **Ajustes** passam a usar foreground/background explícitos para não aparentarem estado desabilitado.
- Os seis atalhos do painel do Monitor usam layout responsivo e cabem em uma única linha quando a largura permitir.
- Duplo toque sobre a área de vídeo aciona a mesma tela inteira do botão superior.
- O selo da câmera principal foi compactado e usa **Local** no lugar de “Câmera local / Principal / IA e alertas” no Monitor vertical.
- A segunda câmera em PiP agora pode ser arrastada dentro da área da câmera principal, com posição limitada ao vídeo para não cobrir mapa e controles externos.
- As caixas verdes de detecção foram avaliadas e preservadas nesta entrega; são apenas overlay visual e podem ser removidas/transformadas em opção futura sem afetar a IA.
- Versionamento, AppMetadata, app_identity.json, Mudanças, README, CHANGELOG, arquitetura, validação, testes e verificadores sincronizados em `1.0.95+95`.

## 1.0.94+94 — 2026-09-23

- Ajuste fino do Monitor vertical com mini-mapa mais alto e resumo **Detectados** deslocado para baixo.
- Os quatro atalhos **Abrir mapa**, **Áudio**, **Painel** e **Ajustes** deixam de usar rolagem horizontal e passam a ficar sempre visíveis em uma única linha compacta.
- Botões inferiores recebem altura, bordas, margens, ícones e tipografia menores para reduzir consumo vertical.
- A informação inferior esquerda do mapa deixa de exibir a distância acompanhada de **Bike** e passa a mostrar a altitude real do GPS, em destaque menor; a distância permanece no card superior.
- Cards de velocidade, temperatura, pneus e distância da telemetria ESP32/Bike foram compactados em largura, padding, ícone e tipografia.
- Teste temporário de segunda câmera frontal adicionado ao seletor de câmeras; no retrato ela aparece em janela PiP pequena sobre a principal, sem substituir a câmera principal nem entrar no pipeline de IA.
- A composição PiP é reutilizada para qualquer segunda fonte no Monitor vertical, preparando o mesmo espaço para uma segunda câmera real.
- Falha de abertura da segunda câmera deixa o controlador pronto para nova tentativa e a frontal concorrente falha de forma isolada quando o aparelho não suporta duas câmeras simultâneas.
- Mini-mapa continua visível mesmo com segunda câmera ativa, permitindo avaliar simultaneamente câmera, mapa, sensores e ações.
- Versionamento, AppMetadata, app_identity.json, Mudanças, README, CHANGELOG, arquitetura, validação, testes e verificadores sincronizados em `1.0.94+94`.

## 1.0.93+93 — 2026-09-23

- Monitor vertical reorganizado para reduzir conteúdo fixo e aproveitar melhor a altura disponível.
- O bloco grande **Detectados agora** foi substituído por um resumo compacto tocável com quantidade e detecção de maior confiança.
- Detalhes das detecções passam a abrir em `DraggableScrollableSheet`, permitindo subir, ampliar e rolar o painel sob demanda.
- Mini-mapa compactado: **Mapa do trajeto** vira **Mapa**, **Sua posição em tempo real** vira **Ao vivo**, **Ver rota completa** vira **Rota** e a legenda de distância foi encurtada.
- Controles de localização e zoom foram reduzidos e alinhados horizontalmente para evitar sobreposição em mapas mais baixos.
- Faixa de métricas da bike reduzida de 96 para 84 px e altura do mini-mapa ajustada para preservar espaço para temperatura, pneus e imagem da câmera.
- A política de orientação da 1.0.92 foi preservada: aplicativo em retrato e Transmissão acompanhando a posição física do celular.
- Versionamento, AppMetadata, app_identity.json, Mudanças, README, CHANGELOG, arquitetura, validação, testes e verificadores sincronizados em `1.0.93+93`.

## 1.0.92+92 — 2026-09-23

- Política de orientação centralizada em `AppOrientationService`.
- Telas normais do Vigia IA passam a ficar limitadas ao modo retrato.
- Modo Transmissão libera retrato e paisagem e acompanha a posição física do celular sem forçar uma orientação específica.
- Ao sair da Transmissão, o retrato é restaurado antes da navegação para evitar que outras telas permaneçam deitadas.
- Tela inteira do Monitor deixa de forçar paisagem e mantém apenas o comportamento imersivo/Ajustar-Preencher.
- Pipeline de câmera preservado: a rotação do frame continua calculada com `sensorOrientation` e `deviceOrientation`.
- Teste e verificador preventivo adicionados para proteger a nova política.
- Versionamento, AppMetadata, app_identity.json, Mudanças, README, CHANGELOG, arquitetura, validação, testes e verificadores sincronizados em `1.0.92+92`.

## 1.0.91+91 — 2026-09-23

- Corrigido o lint `unnecessary_underscores` em `monitor_screen_portrait.dart`, substituindo o segundo placeholder nomeado por `_`.
- `flutter analyze` deixa de falhar no ponto reportado pelo Android-APK-59.
- Adicionada verificação preventiva específica para impedir a reintrodução de `separatorBuilder: (_, __)` na tela vertical do Monitor.
- Interface, mapa, IA, transmissão e regras de orientação permanecem inalterados em relação à 1.0.90.
- Versionamento, AppMetadata, app_identity.json, Mudanças, README, CHANGELOG, arquitetura, validação, testes e verificadores sincronizados em `1.0.91+91`.

## 1.0.90+90 — 2026-09-22

- Tela vertical do Ao vivo redesenhada para ampliar a câmera e adaptar melhor o enquadramento quando a fonte estiver em horizontal.
- Mini-mapa integrado também ao modo retrato, com rota, distância, posição atual e atalho para a tela completa do mapa.
- Barra fixa de botões grandes entre câmera e detecções foi substituída por ações horizontais e por um painel dedicado para áreas, objetos, regras, fonte e recursos.
- Bloco **Detectados agora** continua presente, com altura ajustada para caber junto do mapa sem estrangular a interface vertical.
- Versionamento, AppMetadata, app_identity.json, Mudanças, README, CHANGELOG, arquitetura, validação, testes e verificadores sincronizados em `1.0.90+90`.

## 1.0.89+89 — 2026-09-22

- Corrigidos os quatro `invalid_use_of_protected_member` reportados pelo `flutter analyze` no dashboard paisagem.
- `monitor_screen_landscape_dashboard.dart` não chama mais `setState` diretamente a partir da extensão; as mudanças de estado passam pelo método da própria `State`.
- Novo dashboard Ao vivo, mini-mapa, GPS, telemetria da bike e ações rápidas da 1.0.88 foram preservados.
- Adicionada verificação preventiva para impedir regressão de `setState` direto no arquivo extraído do dashboard.
- Versionamento, AppMetadata, app_identity.json, Sobre/Mudanças, README, arquitetura, validação, testes e verificadores sincronizados em `1.0.89+89`.

## 1.0.88+88 — 2026-09-22

- Tela Ao vivo em paisagem redesenhada para o novo dashboard com cabeçalho, câmera em destaque, mapa do trajeto e barra de ações inferior.
- Mini-mapa integrado ao monitor usa o GPS local quando disponível, mostra rota/posição atuais e oferece ativação guiada quando a localização ainda não foi liberada.
- Telemetria da bike (velocidade, temperatura, pneus e distância) passa a ficar fixa logo abaixo do conteúdo principal, junto da faixa de status da sessão.
- Detecções deixam de ocupar a lateral da câmera única e passam a abrir em painel dedicado sob demanda, preservando as opções antigas no modo de duas câmeras.
- Versionamento, AppMetadata, app_identity.json, Sobre/Mudanças, README, arquitetura, validação, testes e verificadores sincronizados em `1.0.88+88`.

## 1.0.87+87 — 2026-09-22

- Corrigida a ordem da diretiva `part of` em `bike_mode_screen_components.dart`.
- Eliminado o erro `directive_after_declaration` que interrompia o `flutter analyze` no workflow Android.
- Mantida sem regressões a implementação de mapa/GPS, posição atual e registro de rota da 1.0.86.
- Versionamento, AppMetadata, app_identity.json, Sobre/Mudanças, README, arquitetura, validação, testes e verificadores sincronizados em `1.0.87+87`.

## 1.0.86+86 — 2026-09-22

- Iniciada a implantação de mapas no Modo Bike com nova tela `Mapa do monitoramento`.
- Adicionados `flutter_map`, `geolocator` e `latlong2`; a etapa inicial usa OpenStreetMap e GPS do aparelho sem exigir chave de API.
- Mapa mostra posição atual, precisão do GPS, velocidade, última atualização e permite recentralizar após navegação manual.
- Rotas podem ser iniciadas/encerradas com linha do trajeto, marcadores de início/fim, distância acumulada e cronômetro da sessão.
- Adicionadas permissões Android de localização aproximada e precisa; não foi adicionada localização em segundo plano nesta etapa.
- Fluxos específicos orientam o usuário quando o GPS está desligado, a permissão foi negada ou bloqueada permanentemente.
- Versionamento, AppMetadata, app_identity.json, Sobre/Mudanças, README, arquitetura, validação, testes e verificadores sincronizados em `1.0.86+86`.

## 1.0.85+85 — 2026-09-22

- Faixa de telemetria do ESP32/Bike no Monitor passa a priorizar uma única linha horizontal rolável, mantendo o máximo de dados na mesma linha e liberando altura para a câmera.
- Os blocos de Velocidade, Temperatura, Pneus, Sensores/Simulação e Distância foram compactados em mini-cards horizontais.
- A tela Diagnóstico reorganiza Serviço, Câmera, Frames, IA, LAN, clientes, Permissões e 2º plano em uma faixa horizontal compacta com rolagem lateral.
- Em Desempenho da sessão, `Diagnóstico 30 s`, `Diagnóstico 60 s` e `Exportar` agora ficam alinhados na mesma linha horizontal.
- Versionamento, AppMetadata, app_identity.json, Sobre/Mudanças, README, arquitetura, testes e verificadores sincronizados em `1.0.85+85`.

## 1.0.84+84 — 2026-09-22

- Corrigido `flutter analyze`: rótulos adaptativos da Central de Câmeras não são mais construídos como constantes quando dependem da largura disponível.
- Removido parâmetro interno não utilizado de expansão em Configurações, eliminando o aviso restante da análise estática.
- Versionamento, AppMetadata, app_identity.json, Sobre/Mudanças, README, arquitetura, testes e verificadores sincronizados em `1.0.84+84`.

## 1.0.83+83 — 2026-09-22

- Cadastro manual renomeado e reorganizado para identificar claramente Celular transmissor ou Câmera RTSP antes do preenchimento.
- Central de Câmeras compactada em grade para QR, Celular, RTSP e ESP32; dados de modelo, resolução, FPS e bateria do celular remoto aparecem quando a transmissão os informa.
- Transmissor passa a expor a resolução JPEG efetiva no status da rede local.
- Filtros de Histórico ficam em uma linha nas telas usuais, menores e com o rótulo compacto `Carros`.
- Adicionado `Alterar modo` no topo de Normal, Monitor, Bike e Transmissão; o Monitor ativo também permite trocar pelo menu, sem apagar dados.
- Configurações reagrupadas: Preferências reúne áudio/aparência, Sistema reúne permissões/saúde/IA avançada e Sobre é o último grupo.
- Tela Mudanças limitada visualmente às cinco versões recentes.
- Versionamento, metadados, Sobre/Mudanças, README, arquitetura, testes e verificadores sincronizados em `1.0.83+83`.

## 1.0.82+82 — 2026-09-22

- Workflow Android passa a gerar e assinar quatro APKs: universal, `arm64-v8a`, `armeabi-v7a` e `x86_64`.
- Os arquivos usam o padrão `VigiaIA-v1.0.82+82-<arquitetura>.apk` e são publicados na GitHub Release como downloads diretos, sem ZIP.
- O APK universal continua disponível; `x86_64` foi preservado para emuladores e dispositivos compatíveis.
- Relatórios de tamanho e dependências passam a um artifact técnico separado, evitando misturá-los ao download instalável.
- Versionamento, metadados, Sobre/Mudanças, README, arquitetura e verificadores sincronizados em `1.0.82+82`.

## 1.0.81+81 — 2026-09-22

- Redesenhado o Monitor vertical com blocos permanentes para status, modos, câmera, ações e detecções, seguindo a organização da referência fornecida.
- A imagem deixa de ficar como fundo de toda a tela e passa a ocupar um cartão delimitado, inclusive com uma ou duas câmeras.
- Removido o painel expansível de detecções que subia sobre a imagem; a lista agora permanece em área própria e rola internamente.
- Adicionados atalhos compactos para Ao vivo, IA ativa, Painel e Ajustes acima do vídeo.
- O status da câmera local não repete mais a bateria do receptor; a segunda bateria só aparece para celular remoto ou ESP32 com telemetria própria.
- Corrigido `use_build_context_synchronously` em `events_screen_actions.dart`, causa da falha do Android-APK-49 no `flutter analyze`.
- Layout de paisagem, tela cheia, sensores Bike, ESP32 e composição adaptativa de duas câmeras foram preservados.
- Versionamento, metadados, Sobre/Mudanças, README, arquitetura, validação e verificadores sincronizados em `1.0.81+81`.

## 1.0.80+80 — 2026-09-22

- Reorganizado o Histórico com filtros adaptativos em uma linha quando houver espaço, ícones de categoria e metadados compactos nos cards.
- Adicionados botões Salvar e Excluir no detalhe da captura; exclusões individuais agora exigem confirmação e removem a mídia associada.
- Criado painel próprio em Configurações > Monitoramento > ESP32 e sensores.
- O painel cadastra endereço/chave, testa conexão, configura Hall, circunferência/ímãs, temperatura, pressão, telemetria e câmera futura, e envia o contrato JSON para `/config`.
- Adicionados `CameraEndpointType.esp32` e `VideoSourceType.esp32`, mantendo credenciais protegidas pelo armazenamento existente.
- ESP32 com câmera habilitada aparece na Home, no seletor de fonte do Monitor, no seletor de segunda câmera e na página Câmeras.
- Página Câmeras ganhou identificação explícita do tipo de fonte e acesso direto ao gerenciamento ESP32.
- A ação de composição no Monitor passou a se chamar `2ª câmera`; a segunda fonte continua somente em preview, sem duplicar a IA.
- Workflow renomeia o APK para `VigiaIA-v1.0.80.apk`, usa cache de Gradle e modelos e desativa recompressão do APK no artefato.
- O build passa a gerar `apk-size-report.txt` com tamanho final, grupos internos e os 30 maiores arquivos do APK, além de `flutter-dependencies.txt` e `gradle-release-dependencies.txt` para atribuir o peso às dependências corretas.
- Auditoria do projeto identificou como principais candidatos de tamanho os binários nativos universais do Flutter/VLC/LiteRT, dois modelos TFLite e 78 áudios integrados; nenhum recurso foi removido sem medição do APK real.
- Versionamento, documentação, tela de informações, testes e verificadores sincronizados em `1.0.80+80`.

## 1.0.79+79 — 2026-09-22

- Corrigidos os oito avisos `invalid_use_of_protected_member` causados por chamadas diretas a `setState` nos módulos multicâmera extraídos.
- A classe `State` proprietária agora expõe atualizadores internos para os módulos `part`, preservando a separação dos arquivos sem ignorar o analisador.
- Corrigido `unqualified_reference_to_static_member_of_extended_type` no intervalo automático da Central multicâmera.
- Removido o destino Bike do menu inferior e da barra lateral principal.
- O menu principal permanece com Início, Histórico, Monitor e Câmeras, com índices de navegação sincronizados.
- Modo Bike permanece como modo inicial possível e ganhou acesso em Configurações > Monitoramento.
- A tela Bike deixa de usar a navegação principal e oferece atalho próprio para Configurações e para testar o Monitor.
- Teste do menu, verificadores, documentação, tela de mudanças e metadados sincronizados em `1.0.79+79`.

## 1.0.78+78 — 2026-09-22

- Adicionado layout único e adaptativo no Monitor: uma câmera ocupa toda a área; duas câmeras ficam empilhadas no retrato e lado a lado na paisagem.
- A câmera principal mantém IA, histórico, alertas, clipes e áudios; a segunda câmera opera como visualização leve, sem segundo pipeline de inferência.
- Central multicâmera e menu do Monitor passam a permitir escolher uma segunda câmera ou retornar à composição de uma câmera.
- Criada faixa compacta para velocidade Hall, temperatura, pressão dianteira/traseira, bateria dos sensores e distância.
- Adicionado contrato de entrada para telemetria ESP32, controle de dados atrasados e serialização dos sensores no status do celular transmissor.
- O receptor passa a aproveitar a telemetria Bike recebida da câmera remota, mantendo análise e alertas no aparelho receptor.
- Corrigido o fluxo inicial Android para sempre explicar permissões antes de solicitá-las e antes da escolha de modo.
- Instalações atualizadas recebem uma vez o novo guia de acesso; permissões obrigatórias removidas depois exibem orientação sem reiniciar o onboarding.
- Corrigidos botão superior e gesto Voltar do Modo Transmissão para retornar à seleção de modo, com confirmação quando a transmissão estiver ativa.
- O Modo Transmissão mostra de forma compacta se existe receptor conectado e informa que envia imagem, bateria e telemetria, enquanto a IA permanece no receptor.
- Versionamento, metadados, tela de informações, README, arquitetura, validação, testes e verificadores sincronizados em `1.0.78+78`.

## 1.0.77+77 — 2026-09-22

- Corrigida a falha `FILE_UNAVAILABLE` / `resource_id_zero` observada nos áudios integrados do Android.
- Removidas reflexão e busca dinâmica por nome; os 78 slots agora apontam diretamente para constantes compiladas `R.raw`.
- O player nativo passa a distinguir slot desconhecido de recurso com ID inválido e inclui cobertura do catálogo no diagnóstico.
- Adicionado verificador que exige igualdade entre catálogo Dart, catálogo Android e os 78 arquivos M4A de `res/raw`.
- O bootstrap Android passa a restaurar também `AudioResourceCatalog.kt` antes do build.
- Corrigida a expectativa antiga do build no teste de metadados.
- Versionamento, metadados, Sobre/Mudanças, README, arquitetura, validação e verificadores sincronizados em `1.0.77+77`.

## 1.0.76+76 — 2026-09-22

- Adicionado Modo Monitor como opção explícita na seleção inicial.
- Modo Monitor abre uma tela própria para receber transmissão de outro celular por QR, endereço/chave manual ou Central multicâmera.
- Ao conectar, o Monitor abre usando a fonte `Celular remoto`, mantendo IA, histórico, alertas e áudios personalizados no aparelho receptor.
- Modo Normal, Modo Bike e Modo Transmissão ganharam textos mais diretos sobre o papel deste celular: usar câmera própria, receber/analisar ou enviar imagem.
- `AppLaunchModeService` passa a persistir e restaurar também o modo `monitor`.
- Configurações > Monitoramento > Modo inicial foi atualizado para incluir Normal, Monitor, Bike e Transmissão.
- Versionamento, metadados, Sobre/Mudanças, README, arquitetura, validação, testes e verificadores sincronizados em `1.0.76+76`.

## 1.0.75+75 — 2026-09-22

- Corrigido o `unnecessary_non_null_assertion` em `camera_mode_screen.dart` que interrompeu o Android-APK-43 no `flutter analyze`.
- A negação ou exceção de foco de áudio deixou de cancelar a reprodução; o `MediaPlayer` tenta tocar e registra a condição para diagnóstico.
- O player nativo agora registra solicitação, tentativa, origem `override`/`bundled`, etapa, arquivo sem caminho privado, tamanho, volume, rota, foco, tempo desde o frame e tempo desde a solicitação.
- Erros do `MediaPlayer` passam a expor os nomes de `what` e `extra`, incluindo IO, arquivo malformado, formato não suportado, timeout e erro de sistema.
- Falhas da ponte Android e da reprodução são persistidas na Central de Diagnóstico, com slot, prioridade, etapa, código e indicação do fallback para TTS.
- A telemetria de desempenho passa ao esquema 3 e inclui um resumo humano do áudio, os dados nativos completos e a decisão de fallback.
- A tela Áudios e voz exibe o código/etapa real da falha após o teste e informa que o registro foi salvo no Diagnóstico.
- Mantidos os 78 M4A AAC-LC mono 24 kHz, o fallback do override para o áudio integrado e o fallback final para TTS.
- Versionamento, metadados, Sobre/Mudanças, README, arquitetura, validação, testes e verificadores sincronizados em `1.0.75+75`.

## 1.0.74+74 — 2026-09-22

- O Monitor em paisagem deixa de usar AppBar fixa e passa a sobrepor controles translúcidos na própria transmissão.
- Adicionada ação explícita para sair/encerrar o monitoramento no HUD superior e na tela cheia.
- Em paisagem e tela cheia, informações de fonte, IA, detecções, voz, preenchimento, aparelhos e dados da Bike ficam agrupadas no topo.
- O preview passa a preencher automaticamente em paisagem/tela cheia para reduzir faixas pretas e aproveitar melhor a imagem.
- O Modo Câmera ganhou barra superior translúcida com saída clara e ação de parar quando estiver transmitindo.
- O ícone isolado de câmera desligada foi substituído por um estado visual integrado, com descrição do papel do transmissor.
- O painel do Modo Câmera fica sobreposto à câmera em retrato e vira painel lateral em paisagem.
- O fluxo de permissões antes da escolha de modo foi preservado e documentado como requisito da entrega.
- Versionamento, metadados, Sobre/Mudanças, README, arquitetura, validação e verificadores sincronizados em `1.0.74+74`.

## 1.0.73+73 — 2026-09-21

- Adicionada seleção inicial de modo após o acesso inicial/permissões.
- O usuário pode escolher entre Modo normal, Modo Bike e Modo transmissão.
- A escolha fica persistida em `launch_mode.json` e passa a decidir a primeira tela do app.
- Adicionado atalho em Configurações > Monitoramento para revisar e trocar o modo inicial.
- O Modo transmissão continua dedicado a capturar/enviar imagem pela rede local; mapa/GPS e recursos futuros da Bike ficam concentrados no aparelho receptor.
- Adicionado teste para proteger os valores aceitos de `AppLaunchMode`.
- Versionamento, metadados, Sobre/Mudanças, README, arquitetura, validação e verificadores sincronizados em `1.0.73+73`.

## 1.0.72+72 — 2026-09-21

- Corrigido o `flutter analyze` do Android-APK-40.
- `remote_camera_server_service.dart` deixou de usar operador nulo desnecessário ao serializar a telemetria do transmissor.
- `remote_phone_camera_source_test.dart` deixou de importar `dart:async` sem necessidade.
- Documentado que o futuro mini mapa/GPS deve ser exibido no aparelho receptor, mantendo o aparelho transmissor dedicado à captura e envio de imagem.
- Versionamento, metadados, Sobre/Mudanças, README, arquitetura, validação e verificadores sincronizados em `1.0.72+72`.

## 1.0.71+71 — 2026-09-21

- Desacoplada a recepção da câmera remota da cadência da IA, com polling entre 250 e 400 ms.
- Adicionados sequência de quadro, timestamp UTC e cabeçalhos sem cache; o servidor responde sem conteúdo quando ainda não existe imagem nova.
- Quadros remotos repetidos deixam de ser decodificados e enviados novamente ao pipeline de análise.
- O Monitor passa a manter visíveis receptor e transmissor, com bateria, carregamento, estado da conexão e latência remota quando disponível, inclusive no perfil econômico.
- A faixa dos aparelhos permanece no retrato, paisagem e tela inteira e abre o Status da sessão ao toque.
- A resolução de áudios Android passa a priorizar `R.raw`, com fallback e diagnóstico do identificador/erro do recurso.
- Adicionado teste de regressão para consulta rápida e supressão de quadro remoto repetido.
- Versionamento, metadados, Sobre/Mudanças, documentação, testes e verificadores sincronizados em `1.0.71+71`.

## 1.0.70+70 — 2026-09-21

- Corrigido o empacotamento do código-fonte: o ZIP 1.0.69 não continha o arquivo oculto `.gitignore`.
- O `.gitignore` volta a bloquear `*.jks`, `*.keystore` e `android/key.properties`, atendendo à verificação preventiva e protegendo a chave de assinatura.
- Mantida a checagem que falha caso uma keystore seja incluída no projeto.
- Nenhuma lógica funcional de IA, áudio, alertas, câmera ou tela inteira foi alterada.
- Versionamento, AppMetadata, app_identity.json, tela de mudanças, README/ARCHITECTURE/VALIDATION, testes e verificadores sincronizados em `1.0.70+70`.

## 1.0.69+69 — 2026-09-21

- Corrigido o único lint restante do `flutter analyze` em `speech_service.dart`.
- A telemetria de fala agora usa elemento de mapa null-aware (`'error': ?error`), compatível com a regra `use_null_aware_elements` do Dart 3.8+.
- Nenhum comportamento de áudio, TTS, IA, alertas ou tela inteira foi removido ou alterado funcionalmente.
- Versionamento, AppMetadata, app_identity.json, tela de mudanças, README/ARCHITECTURE, testes e verificadores sincronizados em `1.0.69+69`.

## 1.0.68+68 — 2026-09-21

- Corrigida a null-safety do worker de detecção ao trocar entre EfficientDet-Lite0 e o modelo fallback.
- Corrigida a janela de observação das Regras Inteligentes, que referenciava a própria variável antes da declaração.
- Removidos avisos do analisador em import, blocos condicionais e telemetria de fala.
- Mantidas as melhorias da 1.0.67 em detecção, áudio integrado e tela inteira.
- Versionamento, AppMetadata, app_identity.json, tela de mudanças, README/ARCHITECTURE, testes e verificadores sincronizados em `1.0.68+68`.

## 1.0.67+67 — 2026-09-21

- Otimiza conversão da câmera e tensor de entrada com buffers planos/reutilizáveis, preservando letterbox e coordenadas.
- Solicita XNNPACK/2 threads, mantém fallback CPU e adiciona troca controlada para SSD MobileNet V1 sob lentidão persistente.
- Corrige expiração prematura da confirmação/permanência em baixa cadência; evidências fortes deixam de esperar confirmação genérica extra.
- Limita todas as inferências auxiliares pelo orçamento e reduz codificação LAN sem visualizadores.
- Corrige o fluxo de áudio: volume de mídia, prepareAsync, foco transitório, prioridades, fila curta, cache por versão e fallback após erros assíncronos.
- Acrescenta tela inteira horizontal com preenchimento proporcional, Ajustar/Preencher, controles temporários e Voltar sem encerrar a câmera.
- Evita preview com CameraController descartado e frames de uma geração anterior.
- Telemetria v2 separa inferência nativa da transferência dos tensores; inclui decisão de alerta, regras efetivas e eventos de áudio/TTS.
- Atualiza metadados, Sobre/Mudanças, documentação, verificadores e testes de regressão. Flutter/Android SDK indisponíveis no ambiente desta entrega; analyze/test/build dependem do workflow.


## 1.0.66+66

- Corrigido o único teste que falhou no Android-APK-34 após o `flutter analyze` passar sem problemas.
- `session_status_test.dart` agora valida `Inferências auxiliares` como hotspot no cenário granular usado pelo teste.
- `primaryInferenceMs` continua representando o round-trip agregado da inferência principal e, por isso, não participa da comparação das etapas locais granulares em `pipelineHotspot`.
- Nenhuma lógica funcional de IA, telemetria, relatórios, Downloads, onboarding ou layouts foi alterada.
- Versionamento e documentação sincronizados em `1.0.66+66`.

## 1.0.65+65

- Corrigido o `flutter analyze` reportado pelo Android-APK-33.
- Removido o import redundante `dart:typed_data` de `native_platform_service.dart`; `Uint8List` já é disponibilizado por `package:flutter/services.dart`.
- `diagnostic_report_service_test.dart` agora valida que o caminho exportado não é nulo antes de criar `File`, respeitando o retorno `Future<String?>` da API de exportação.
- Adicionadas verificações preventivas para impedir a volta desses dois problemas.
- Nenhuma lógica funcional de telemetria, relatórios, Downloads, onboarding, IA ou layouts foi alterada.
- Versionamento e documentação sincronizados em `1.0.65+65`.

## 1.0.64+64

- Implementada telemetria granular do pipeline da IA: conversão/decodificação da fonte, transporte, fila/transferência entre isolates, materialização, imagem RGB, resize/letterbox, tensor, LiteRT/TFLite puro, pós-processamentos, total e fim a fim.
- `PerformanceTelemetryService` mantém amostras normais e diagnóstico profundo de 30/60 s, calcula média/min/max/P50/P90/P95/P99 e identifica o maior custo observado.
- Exportação de desempenho gera ZIP com `resumo.txt`, `telemetria.json` e `telemetria.csv`, sem imagens por padrão.
- Diagnósticos técnicos e de desempenho salvam em `Downloads/Vigia IA` por padrão; Configurações permite trocar para `Perguntar sempre`, usando o seletor nativo do Android.
- Acesso inicial agora é exibido somente na primeira instalação; atualizações existentes são reconhecidas sem reabrir o onboarding e a tela continua disponível em Configurações > Permissões do aplicativo.
- Os chips Câmera/Alertas/Pareamento permanecem em uma única linha com redução de escala quando necessário.
- Saúde da sessão passa a distinguir custo de conversão da fonte, preparação da IA e LiteRT puro, evitando atribuir todo o round-trip ao modelo.
- Melhorias adaptativas: Central multicâmera usa três ações em uma linha quando há espaço; Histórico usa filtros 2×2; Alertas e clipes usa duas colunas em tela larga e SafeArea; Status da sessão usa painel lateral e detalhes internos no mesmo painel.
- `DeviceTelemetrySnapshot` inclui fabricante/modelo e versão/SDK Android para contextualizar relatórios.
- Novos testes cobrem percentis, gargalo provável, prioridade do diagnóstico profundo e metadados de dispositivo.
- Versionamento e documentação sincronizados em `1.0.64+64`.

## 1.0.63+63

- Corrigidos 19 avisos `unnecessary_this` reportados pelo `flutter analyze` em `monitor_controller.dart` no workflow Android-APK-31.
- Removidos apenas qualificadores `this.` redundantes; os wrappers continuam delegando para as mesmas implementações internas `*Impl`.
- Adicionada verificação preventiva para evitar a reintrodução de `this._` no `MonitorController`.
- Nenhuma lógica funcional do Monitor, Modo Bike, IA, TTC, telemetria, áudio ou interface foi alterada.
- Versionamento e documentação sincronizados em `1.0.63+63`.

## 1.0.62+62

- Corrigido o erro `Permission denied` / exit code 126 do workflow ao executar `tool/bootstrap_android.sh` após importação do ZIP.
- O workflow agora chama `bootstrap_android.sh`, `fetch_model.sh` e `verify_project.sh` explicitamente via `bash`, sem depender do bit executável dos arquivos ser preservado pelo ZIP/GitHub Manager.
- Adicionada verificação preventiva para impedir que o workflow volte a executar esses scripts diretamente.
- Nenhuma lógica funcional do Monitor, Modo Bike, IA, alertas, áudio ou interface foi alterada.
- Versionamento e documentação sincronizados em `1.0.62+62`.

## 1.0.61+61

- Corrigidos os três avisos `unused_element` reportados pelo workflow da 1.0.60 em `monitor_controller.dart`.
- Removidos os wrappers privados `_refreshSessionTelemetry`, `_deliverAlert` e `_zonesDiagnosticContext`, que ficaram sem referências após a extração dos módulos internos.
- A implementação ativa permanece em `_refreshSessionTelemetryImpl`, `_deliverAlertImpl` e `_zonesDiagnosticContextImpl`, preservando telemetria, alertas/TTC e diagnóstico de áreas.
- Nenhuma funcionalidade do Monitor, Modo Bike, IA, áudio, histórico ou diagnóstico foi removida.
- Versionamento e documentação sincronizados em `1.0.61+61`.

## 1.0.60+60

- Quarto lote da refatoração preventiva concluído em `session_status.dart`, `system_health_screen.dart` e `object_detection_service.dart`.
- `SessionStatusData`, enums e snapshots permanecem em `session_status.dart`; o analisador de saúde foi movido para `session_status_health_analyzer.dart`.
- `SystemHealthScreen` mantém coleta, timer, persistência e ações no arquivo principal; cards e componentes visuais foram movidos para `system_health_screen_components.dart`.
- `ObjectDetectionService` mantém a API pública, inicialização, fila de requisições e ciclo de vida do isolate; worker, pré-processamento, inferência e pós-processamento foram movidos para `object_detection_worker.dart`.
- Arquivos principais reduzidos de 563 → 223 linhas, 539 → 404 linhas e 536 → 236 linhas, respectivamente.
- Os quatro lotes planejados agora totalizam 12 arquivos refatorados em grupos de três.
- Verificadores foram atualizados para reconhecer os novos módulos e impor limites preventivos de tamanho.
- Nenhuma métrica, diagnóstico, contrato do detector, modelo de IA ou comportamento de inferência foi removido.
- Versionamento e documentação sincronizados em `1.0.60+60`.

## 1.0.59+59

- Terceiro lote da refatoração preventiva concluído em `session_status_panel.dart`, `error_center_screen.dart` e `events_screen.dart`.
- Status da sessão move cards, métricas, badges e helpers visuais para `session_status_panel_components.dart`, preservando `SessionStatusPanel` e `VideoSessionDetailsPanel` como entradas públicas.
- Central de diagnóstico move resumo operacional, grid, chips e cards de registros para `error_center_screen_components.dart`, mantendo carregamento, exportação, compartilhamento e filtros no arquivo principal.
- Histórico move cards, thumbnails, estados vazio/erro e reprodução de mídia para `events_screen_components.dart`, mantendo persistência, filtros, navegação e ações no arquivo principal.
- Arquivos principais reduzidos de 700 → 258 linhas, 597 → 303 linhas e 586 → 359 linhas, respectivamente.
- Verificadores foram atualizados para a estrutura modular e ganharam limites preventivos para esses três arquivos.
- Nenhuma funcionalidade, filtro, reprodução MP4, diagnóstico ou métrica da sessão foi removida.
- Versionamento e documentação sincronizados em `1.0.59+59`.



## 1.0.58+58

- Segundo lote da refatoração preventiva concluído em `multi_camera_screen.dart`, `app_info_screen.dart` e `bike_mode_screen.dart`.
- Central multicâmera move cabeçalho, cards e chips de métricas para `multi_camera_screen_components.dart`, preservando estado, QR, probe, edição e navegação no arquivo principal.
- Informações do aplicativo move Sobre, Mudanças, Doações e cards auxiliares para `app_info_screen_components.dart`; seleção de seção e cópia da chave PIX permanecem no arquivo principal.
- Modo Bike move hero, telemetria e cards auxiliares para `bike_mode_screen_components.dart`, preservando carregamento, persistência, simulador e navegação.
- Arquivos principais reduzidos de 941 → 648 linhas, 723 → 95 linhas e 701 → 441 linhas, respectivamente.
- Verificadores foram atualizados para a estrutura modular e ganharam limites preventivos para esses três arquivos.
- Nenhuma funcionalidade, rota, configuração de Bike, Central multicâmera ou informação exibida foi removida.
- Versionamento e documentação sincronizados em `1.0.58+58`.


## 1.0.57+57

- Primeiro lote da refatoração preventiva concluído em `monitor_controller.dart`, `monitor_screen.dart` e `home_screen.dart`.
- `MonitorController` separa telemetria/saúde da sessão, eventos/alertas/TTC e estado/diagnóstico em módulos internos `part`, preservando a API pública e o comportamento do pipeline.
- `MonitorScreen` move seus componentes visuais auxiliares para `monitor_screen_components.dart`.
- `HomeScreen` move seus componentes visuais auxiliares para `home_screen_components.dart`.
- Arquivos principais reduzidos de 2.379 → 1.744 linhas, 1.808 → 1.332 linhas e 1.199 → 800 linhas, respectivamente.
- Verificador preventivo passou a reconhecer os módulos extraídos e impõe limites de tamanho para impedir regressão imediata da refatoração.
- Nenhuma função de monitoramento, Modo Bike, TTC, HUD, áudio ou fonte de vídeo foi removida nesta etapa.
- Versionamento e documentação sincronizados em `1.0.57+57`.

## 1.0.56+56

- Implementado caminho rápido de aproximação para o Modo Bike, executado logo após a inferência principal.
- Novo `BikeApproachEstimator` associa automóveis entre frames e usa o crescimento suavizado da escala aparente para estimar TTC visual.
- O primeiro aviso acontece antes de inferências auxiliares, histórico e gravação, reduzindo trabalho no caminho crítico do alerta.
- Automóveis necessários ao alerta Bike são incluídos somente na inferência principal de segurança, independentemente do filtro normal do Monitor; os eventos normais continuam respeitando a seleção do usuário.
- HUD sobre o vídeo ganhou estados observação/aviso/crítico e mostra `TTC ~Xs`, sem apresentar distância em metros.
- Alertas de voz/notificação têm prioridade alta, cooldown por veículo e escalada imediata quando o risco sobe para crítico.
- Modo Bike ganhou controle de ativação e limiar configurável de aviso entre 2,5 e 7 s.
- Simulador sem ESP32 ganhou o cenário `Veículo se aproximando`, com ciclo visual e áudio marcado como teste.
- Novos testes cobrem crescimento, afastamento, filtragem de não veículos, reset do estimador e persistência das novas preferências.
- Integração real com ESP32 e radar FMCW continuam fora desta versão.
- Versionamento e documentação sincronizados em `1.0.56+56`.

## 1.0.55+55

- Corrigidos os dois avisos `unnecessary_non_null_assertion` em `monitor_screen.dart` que faziam o `flutter analyze` falhar no workflow da 1.0.54.
- Nova base adaptativa para celular retrato, celular paisagem e tablet: telas principais trocam a barra inferior por `NavigationRail` quando há largura útil.
- Home e Modo Bike passam a usar duas colunas em tela larga; Histórico ganha filtros laterais e Configurações divide categorias em duas colunas.
- Monitor em celular paisagem prioriza o vídeo: o painel de controles/detecções pode ser recolhido; em tablet grande ele permanece lateral.
- Monitor ganhou `Ajustar / Preencher`; caixas da IA e áreas de vigilância usam a mesma geometria de contain/cover para permanecer alinhadas.
- HUD da Bike fica mais compacto em telas de pouca altura.
- Status da sessão abre como diálogo largo em telas grandes e posiciona Este celular/Celular remoto lado a lado.
- ESP32 continua sem implementação real; o simulador permanece disponível para validação do HUD.
- Versionamento e documentação sincronizados em `1.0.55+55`.

## 1.0.54+54

- Implementado HUD transparente do Modo Bike diretamente sobre o vídeo do Monitor.
- O HUD exibe velocidade, pressão do pneu dianteiro/traseiro e bateria da futura central/sensores sem esconder a imagem principal.
- Alertas visuais destacados para pressão baixa, bateria de sensores baixa/crítica e perda de conexão.
- Adicionado simulador interno para desenvolvimento e teste sem ESP32, com cenários normal, pneu dianteiro baixo, pneu traseiro baixo, bateria baixa e desconectado.
- Dados simulados ficam explicitamente marcados como `SIMULAÇÃO`.
- Novo contrato `BikeSensorSnapshot` e `BikeSensorService` deixam o HUD independente da futura origem ESP32.
- Corrigido o lint `use_null_aware_elements` em `SessionStatusPanel` reportado pelo workflow Android-APK-25 da 1.0.53.
- Novos testes cobrem persistência do simulador e classificação de alertas dos sensores.
- Versionamento e documentação sincronizados em `1.0.54+54`.
- Integração real com ESP32 continua fora desta etapa.

### Como testar sem ESP32

1. Abra `Bike`.
2. Em `Teste do HUD sem ESP32`, ative `Simular sensores da bike`.
3. Escolha um cenário e toque em `Abrir Monitor e testar HUD`.
4. Confirme o HUD transparente no vídeo e alterne os cenários para verificar cada alerta.

### Validação disponível

- `tool/verify_project.sh` valida a estrutura, o buildfix, o simulador, o HUD e a sincronização da versão.
- Este ambiente não contém Flutter/Android SDK; `flutter analyze`, `flutter test` e o build do APK ainda precisam ser confirmados pelo workflow.


## 1.0.53+53

- Corrigida a reprodução dos áudios padrão que ainda podia falhar em aparelho real com “Não foi possível reproduzir este áudio”.
- Removida a dependência de `android.resource://` para os M4A padrão durante a reprodução.
- `MainActivity` agora lê o recurso de `res/raw`, grava uma cópia íntegra no cache privado e entrega o caminho local ao `MediaPlayer`.
- O fallback de áudio personalizado inválido para o áudio padrão foi preservado.
- Os 78 M4A padrão não foram reconvertidos nem alterados; apenas o mecanismo de abertura/reprodução foi corrigido.
- Versionamento, AppMetadata, app_identity.json, tela de mudanças, README, ARCHITECTURE, testes/verificadores e fontes Android sincronizados em `1.0.53+53`.
- Fluxo imersivo do Bike e integração ESP32 permanecem inalterados.

### Validação disponível

- `tool/verify_project.sh` valida a nova estratégia de reprodução, espelhamento do `MainActivity`, biblioteca padrão e sincronização da versão.
- Este ambiente não contém Flutter/Android SDK; `flutter analyze`, `flutter test` e o build do APK ainda precisam ser confirmados pelo workflow.

## 1.0.52+52

- Instrumentação do pipeline da IA por etapa: pré-processamento, inferência principal, inferências auxiliares, pós-processamento, total e fim a fim estimado.
- Detalhes de vídeo mostram uso do orçamento de análise, folga restante, maior custo local, quantidade de execuções do detector e varreduras opcionais evitadas.
- Nova `AnalysisBudgetPolicy` protege a responsividade antes de iniciar uma varredura opcional de detalhe.
- A inferência principal não é removida nem condicionada pelo orçamento; apenas o refinamento opcional pode ser adiado.
- O avaliador de saúde sinaliza pipeline perto do limite ou acima do intervalo configurado.
- Novos testes cobrem cálculo do pipeline e a política de orçamento para varreduras de detalhe.
- Versionamento, AppMetadata, app_identity.json, tela de mudanças, README, ARCHITECTURE, testes e verificadores sincronizados em `1.0.52+52`.
- Fluxo imersivo do Modo Bike e integração ESP32 permanecem inalterados.

### Validação disponível

- `tool/verify_project.sh` valida a estrutura, a nova política de orçamento e o versionamento desta entrega.
- `flutter analyze`, `flutter test` e o build do APK ainda precisam ser confirmados pelo workflow quando Flutter/Android SDK estiverem disponíveis.

## 1.0.51+51

- Status da sessão agora calcula saúde operacional em tempo real com estados Saudável, Atenção, Instável e Desconectado.
- Detecção de frame atrasado/sem atualização, latência elevada, atraso ponta a ponta, FPS recebido abaixo do esperado, inferência lenta e perdas reais enquanto a IA está ocupada.
- Gargalo provável classificado entre rede, captura de vídeo, processamento da IA e recursos do aparelho.
- Frames pulados intencionalmente pelo filtro de movimento separados dos descartes por processamento, para não contaminar o diagnóstico de desempenho.
- Histórico curto de ocorrências da sessão com registro de recuperação/normalização.
- Detalhes de vídeo ampliados com idade da imagem, FPS esperado e contadores separados de descarte/otimização.
- Novos testes do avaliador de saúde para sessão saudável, frame congelado, latência alta, reconexão e perdas de processamento.
- Versionamento, AppMetadata, app_identity.json, tela de mudanças, README, ARCHITECTURE, testes e verificadores sincronizados em `1.0.51+51`.
- Fluxo imersivo do Modo Bike e integração ESP32 permanecem inalterados.

### Validação disponível

- `tool/verify_project.sh` valida a estrutura e o versionamento desta entrega.
- `flutter analyze`, `flutter test` e o build do APK ainda precisam ser confirmados pelo workflow quando Flutter/Android SDK estiverem disponíveis.


## 1.0.50+50

- Buildfix da entrega `Status da sessão` após o workflow real da 1.0.49 apontar três avisos `unnecessary_brace_in_string_interps`.
- Corrigidas as interpolações de resolução recebida, resolução analisada e atraso do frame em `lib/models/session_status.dart`.
- Nenhuma funcionalidade do painel, Monitor normal, telemetria remota ou preparação para o Modo Bike foi removida ou alterada.
- Fluxo imersivo do Modo Bike e integração ESP32 permanecem inalterados.
- Versionamento, AppMetadata, app_identity.json, tela de mudanças, README, ARCHITECTURE, testes e verificadores sincronizados em `1.0.50+50`.

### Validação disponível

- `tool/verify_project.sh` valida a correção das três interpolações e a sincronização da versão.
- Este ambiente não contém Flutter/Android SDK; `flutter analyze`, `flutter test` e o build do APK ainda precisam ser confirmados pelo workflow.

## 1.0.49+49

- Adicionado o painel reutilizável `Status da sessão` em tempo real no Monitor.
- O vídeo fica resumido em um card compacto; os detalhes foram isolados em painel próprio.
- O painel detalha fonte da imagem, dispositivo que executa a IA, FPS recebido e analisado, resolução recebida/analisada, inferência, atraso do frame, latência de rede e frames descartados.
- Telemetria é apresentada separadamente para `Este celular` e `Celular remoto`: bateria, carga, temperatura, brilho, CPU, RAM, armazenamento e conexão.
- `MonitorController` passa a medir chegada e análise separadamente, mantendo contadores da sessão e tempo de inferência.
- `RemoteCameraServerService` disponibiliza telemetria remota também fora do Bike e anexa ao JPEG o horário real de captura do frame.
- `RemotePhoneCameraSource` preserva o timestamp remoto e mede o tempo de transferência do frame para cálculo de atraso/latência.
- Android passa a expor o tipo de conexão ativa via `ConnectivityManager`, com `ACCESS_NETWORK_STATE`.
- O fluxo imersivo do Modo Bike e a integração ESP32 não foram alterados.
- Versionamento, AppMetadata, app_identity.json, tela de mudanças, README, ARCHITECTURE, testes e verificadores sincronizados em `1.0.49+49`.

### Validação disponível

- `tool/verify_project.sh` valida versão, novos arquivos do painel, telemetria, timestamp remoto e sincronização Android.
- Este ambiente não contém Flutter/Android SDK; `flutter analyze`, `flutter test` e o build do APK ainda precisam ser confirmados pelo workflow.

## 1.0.48+48

- Corrigida a falha de reprodução na tela `Áudios e voz` observada em aparelho real.
- Os 78 áudios padrão passam de WAV PCM para AAC/M4A mono em 24 kHz para maior compatibilidade com o `MediaPlayer` Android.
- O player nativo passa a usar `AudioAttributes` de sonificação/fala e URI `android.resource://` para abrir os recursos embarcados.
- `Ouvir`, `Trocar` e `Gravar` permanecem lado a lado em uma única linha, com rótulos compactos e ajuste automático sem cortar texto.
- `Restaurar padrão` foi movido para um ícone no cabeçalho dos itens personalizados para não quebrar a linha de ações.
- Importação e gravação de áudio personalizado permanecem compatíveis com os formatos já aceitos.
- Versionamento, AppMetadata, app_identity.json, tela de mudanças, README, ARCHITECTURE, testes e verificadores sincronizados em `1.0.48+48`.

### Validação disponível

- `tool/verify_project.sh` valida a biblioteca M4A, a equivalência entre `custom_audio` e `res/raw`, o novo player e o layout compacto.
- Este ambiente não contém Flutter/Android SDK; `flutter analyze`, `flutter test` e o build do APK ainda precisam ser confirmados pelo workflow.

## 1.0.47+47

- Assinatura Android release migrada de `debug` para uma keystore permanente fornecida exclusivamente por GitHub Secrets.
- Workflow passa a exigir `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` e `ANDROID_KEY_PASSWORD` antes do build.
- Keystore é reconstruída temporariamente em `$RUNNER_TEMP`, validada com `keytool` e nunca é adicionada ao repositório, ZIP fonte ou artifact final.
- `bootstrap_android.sh` injeta uma `signingConfig` release que lê caminho e credenciais apenas do ambiente do runner, preservando a recriação completa da pasta Android.
- Após o build, `apksigner verify` confirma que o APK release está efetivamente assinado antes do upload do artifact.
- `.gitignore` reforçado para bloquear arquivos `.jks`, `.keystore` e `android/key.properties`.
- Versionamento, AppMetadata, app_identity.json, tela de mudanças, README, ARCHITECTURE, testes e verificadores sincronizados em `1.0.47+47`.

### Migração da assinatura

- Instalações feitas com a antiga assinatura debug podem exigir uma última desinstalação antes de instalar a primeira APK assinada com a chave permanente.
- Depois da primeira instalação com esta chave, as próximas versões poderão atualizar por cima normalmente, desde que os quatro Secrets sejam preservados e o `versionCode` continue aumentando.

### Validação disponível

- `tool/verify_project.sh` valida a política de assinatura e impede o retorno de `signingConfigs.getByName("debug")` no release.
- `flutter analyze`, `flutter test` e o build/validação criptográfica da APK continuam sendo confirmados pelo GitHub Actions.

## 1.0.46+46

- Buildfix da tela `Configurações → Geral → Áudios e voz` após validação no Flutter 3.44.9.
- Corrigido `Icons.person_voice_outlined`, getter inexistente que fazia o `flutter analyze` encerrar com dois erros na 1.0.45.
- O chip `Seu áudio` passa a usar `Icons.mic_rounded`, mantendo o mesmo significado visual sem depender de um ícone indisponível.
- Biblioteca central com 78 vozes, overrides por arquivo, gravação própria, restauração e fallback TTS preservados sem mudança de contrato.
- `tool/verify_project.sh` ampliado para impedir a reintrodução do getter incompatível.
- Versionamento, metadados, documentação, tela de mudanças e verificadores sincronizados em `1.0.46+46`.

### Validação disponível

- O workflow da 1.0.45 confirmou dependências e verificação preventiva; a falha ocorreu exclusivamente na análise estática do ícone.
- `tool/verify_project.sh` deve passar localmente nesta entrega; `flutter analyze`, `flutter test` e build APK precisam ser confirmados pelo próximo workflow.

## 1.0.45+45

- Criado sistema central de áudio do Vigia IA com 78 slots únicos.
- Os 68 novos avisos gerados pelo usuário foram recortados e adicionados aos 10 áudios já existentes.
- Os 14 slots do monitor atual ficam prontos para uso imediato; 64 slots Bike/ESP32 ficam reservados para as integrações futuras.
- Nova tela `Configurações → Geral → Áudios e voz` com busca, agrupamento por categoria, prévia e indicação de áudio personalizado/futuro.
- Cada aviso pode ser substituído por arquivo de áudio, gravado diretamente pelo microfone, restaurado individualmente ou restaurado em lote.
- Overrides são armazenados nos dados privados do app e têm prioridade sobre os recursos `res/raw`; arquivo inválido cai para o áudio padrão e, quando aplicável, para TTS.
- Android ganhou seletor SAF sem permissão de armazenamento e gravação AAC/M4A com `RECORD_AUDIO` solicitado apenas ao iniciar gravação.
- `MonitorController` passa a referenciar os IDs centrais do catálogo em vez de strings soltas para detecção, entrada/saída e integridade da câmera.
- `bootstrap_android.sh` continua reconstruindo `res/raw` a partir de `custom_audio/` e agora aceita também M4A/AAC como formatos versionados.
- Teste novo valida 78 slots únicos, 14 slots atuais e 64 slots Bike futuros.
- Versionamento, metadados, documentação, tela de mudanças e verificadores sincronizados em `1.0.45+45`.

### Validação disponível

- `tool/verify_project.sh` valida catálogo, arquivos, ponte Android, tela de configuração e sincronização da versão.
- Este ambiente não contém Flutter/Android SDK; `flutter analyze`, `flutter test` e o build do APK ainda precisam ser confirmados pelo workflow.

## 1.0.44+44

- Corrigida a navegação do Modo Bike conforme o desenho original do produto.
- `Bike` agora é o quinto destino permanente do menu principal inferior, ao lado de Início, Histórico, Monitor e Câmeras.
- A tela `BikeModeScreen` mantém a barra principal visível com o destino Bike selecionado.
- Home, Histórico e Central multicâmera passam a abrir o Modo Bike pelo fluxo principal de navegação.
- Removido o atalho duplicado de Configurações → Monitoramento para o modo não ficar escondido nem ter duas entradas concorrentes.
- Funcionalidades de economia, telemetria, painel remoto e alertas da Etapa 3 foram preservadas.
- Adicionado teste de widget para garantir cinco destinos no menu e o índice 4 reservado para Bike.
- Versionamento, metadados, documentação, tela de mudanças e verificadores sincronizados em `1.0.44+44`.

### Validação disponível

- `tool/verify_project.sh` valida o quinto destino Bike, a seleção correta na tela e a ausência do antigo atalho de Configurações.
- Este ambiente não contém Flutter/Android SDK; `flutter analyze`, `flutter test` e o build do APK ainda precisam ser confirmados pelo workflow.

## 1.0.43+43

- Buildfix da Etapa 3 do Modo Bike após validação real no GitHub Actions com Flutter 3.44.9.
- Removidos dois casts desnecessários em `lib/models/remote_phone_status.dart` e `lib/sources/remote_phone_camera_source.dart`.
- O workflow da 1.0.42 chegava à análise estática, mas encerrava com `unnecessary_cast`; a correção preserva o mesmo comportamento de parsing e telemetria.
- Teste de metadados atualizado para a nova versão e verificações preventivas ampliadas para impedir a reintrodução dos dois casts.
- Versionamento, metadados, documentação, tela de mudanças e verificadores sincronizados em `1.0.43+43`.

### Validação disponível

- `tool/verify_project.sh` valida a sincronização da versão e os dois pontos que bloquearam o `flutter analyze` da 1.0.42.
- O workflow anterior confirmou que dependências e verificação preventiva da 1.0.42 passavam; `flutter analyze`, `flutter test` e build da 1.0.43 ainda precisam ser confirmados no próximo workflow.

## 1.0.42+42

- Etapa 3 do Modo Bike concluída com painel remoto no celular que recebe a imagem.
- `RemotePhoneCameraSource` passa a consultar `/status` em paralelo ao frame JPEG e mantém a transmissão funcionando mesmo quando apenas a telemetria falha.
- Telemetria remota exibe bateria/carga, temperatura, brilho/tela, CPU do Vigia IA, RAM disponível/total e memória do processo.
- Modo Câmera informa FPS aproximado da captura; o receptor mede também a latência da resposta de telemetria.
- Monitor Ao vivo ganhou atalho de bicicleta, resumo compacto sobre o preview e painel detalhado do aparelho traseiro.
- Avisos visuais cobrem bateria baixa conforme o limite configurado no traseiro, aquecimento, CPU elevada, pouca RAM e telemetria atrasada.
- `DeviceTelemetrySnapshot.fromJson` preserva o horário de captura recebido do outro aparelho.
- Testes novos cobrem parsing do status remoto, perfil, FPS/latência, alertas críticos e telemetria atrasada.
- Versionamento, metadados, documentação, tela de mudanças e verificadores sincronizados em `1.0.42+42`.

### Validação disponível

- `tool/verify_project.sh` cobre a integração da Etapa 3, os novos modelos/widgets e a sincronização da versão.
- Este ambiente não contém Flutter/Android SDK; `flutter analyze`, `flutter test` e o build do APK ainda precisam ser confirmados pelo workflow.

## 1.0.41+41

- Etapa 2 do Modo Bike concluída: os perfis agora alteram o pipeline real em vez de servirem apenas como configuração.
- O intervalo efetivo de captura/análise passa a respeitar o mínimo de cada perfil: Normal 400 ms, Economia 650 ms e Economia extrema 1000 ms, sem acelerar uma configuração do usuário que já seja mais lenta.
- A transmissão LAN ganhou limite de FPS por perfil e política de JPEG adaptativa: os modos econômicos reduzem largura/qualidade para diminuir CPU, tráfego e consumo.
- O Modo Câmera do celular traseiro também respeita os perfis de energia, permitindo usar o telefone apenas como câmera com a mesma estratégia de economia.
- Brilho do app pode ser reduzido nativamente durante monitoramento/transmissão no Modo Bike e é restaurado quando a operação termina.
- Telemetria nativa ampliada com percentual/carga da bateria, origem/corrente aproximada de carga, temperatura, brilho/tela, CPU do processo, núcleos e memória do aparelho.
- A tela Modo Bike passa a mostrar as condições atuais do celular traseiro e Saúde do sistema/Diagnóstico passam a exibir as novas métricas.
- Telemetria do aparelho é incorporada aos endpoints locais de status do Monitor LAN e do Modo Câmera quando permitido, preparando o painel remoto da Etapa 3.
- Aviso de bateria baixa passa a funcionar durante operação do Modo Bike, com antirrepetição até a carga se recuperar.
- Corrigido o teste de metadados que ainda esperava build 39 na base 1.0.40.
- Versionamento, metadados, documentação, tela de mudanças e verificadores sincronizados em `1.0.41+41`.

### Validação disponível

- `tool/verify_project.sh` cobre a integração do perfil energético, telemetria, brilho e preparação do status remoto.
- Este ambiente não contém Flutter/Android SDK; `flutter analyze`, `flutter test` e o build do APK ainda precisam ser confirmados pelo workflow.

## 1.0.40+40

- Iniciada a implementação do Modo Bike em uma tela própria dentro de Configurações → Monitoramento.
- Adicionados perfis `Normal`, `Economia` e `Economia extrema`, com metas explícitas de intervalo da IA e FPS de transmissão para orientar a integração com o pipeline.
- Ativação, perfil e preferências do Modo Bike são persistidos em armazenamento privado do app.
- Adicionadas preferências para reduzir atividade da tela traseira, manter telemetria remota e definir alerta de bateria baixa.
- Estrutura foi separada em `BikeModeConfig`, `BikeModeService` e `BikeModeScreen`, preparando a próxima etapa sem duplicar o pipeline de IA.
- Novo teste cobre padrão, serialização e limites da configuração do Modo Bike.
- Versionamento, metadados, documentação, tela de mudanças e verificadores sincronizados em `1.0.40+40`.

### Validação disponível

- `tool/verify_project.sh` valida a presença da nova estrutura e a sincronização da versão.
- Este ambiente não contém Flutter/Android SDK; `flutter analyze`, `flutter test` e o build do APK ainda precisam ser confirmados pelo workflow.

## 1.0.39+39

- Corrigido o bloqueio do `flutter analyze` no Flutter 3.44: a seleção visual da fonte deixou de usar `Radio.groupValue` e `Radio.onChanged`, ambos obsoletos.
- Nova tela inicial de permissões explica câmera, notificações e rede local/dispositivos próximos, com ações para solicitar ou abrir os ajustes do Android.
- Monitor passa a usar o título `Ao vivo`; o chip `Status` foi renomeado para `Painel` e textos longos foram ajustados para reduzir sobreposição.
- Tela `Fonte` foi reformulada com explicações por tipo de origem e suporte a escanear o QR do outro aparelho.
- Adicionada pista complementar para presença humana parcial em regiões móveis quando o detector principal não encontra o corpo completo.
- Adicionada memória visual curta para reduzir fala repetida do mesmo objeto após pequenas perdas de rastreamento.
- Versionamento, metadados, documentação, tela de mudanças e verificações sincronizados em `1.0.39+39`.

### Validação disponível

- O log Android-APK-11 confirmou que o verificador preventivo passava e que o único bloqueio era o uso das duas propriedades `Radio` obsoletas.
- Este ambiente não contém Flutter SDK; `flutter analyze`, `flutter test` e a geração do APK precisam ser confirmados pelo próximo workflow Android APK.

## 1.0.38+38

- Pacote de voz fornecido pelo usuário em um único WAV foi separado em dez arquivos curtos e incorporado a `custom_audio/`.
- Incluídos áudios para pessoa/veículo/animal/objeto detectado, pessoa entrou/saiu, veículo entrou/saiu, câmera obstruída e câmera deslocada.
- Transições de área passam a selecionar slots por família (`person_*`, `vehicle_*`, `animal_*`) antes do fallback `object_*`.
- `animal_entered` e `animal_exited` permanecem em TTS porque essas duas frases não estavam presentes no WAV recebido; adicionar os arquivos depois não exige mudança de código.
- Os WAVs atuais também foram copiados para `android/app/src/main/res/raw/`, preservando build direto, enquanto `tool/bootstrap_android.sh` continua sendo a fonte de reconstrução no CI.
- README, ARCHITECTURE, tela de mudanças, metadados e verificador preventivo sincronizados em `1.0.38+38`.

### Validação disponível

- `tool/verify_project.sh` valida slots, arquivos incluídos, sincronização Android e versão.
- Este ambiente não contém Flutter SDK; `flutter analyze`, `flutter test` e o APK precisam ser confirmados pelo workflow Android APK.

## 1.0.37+37

- Detecção de movimento passa a usar luminância e distância RGB, permitindo reconhecer mudanças relevantes de cor mesmo quando o brilho médio permanece semelhante.
- Adicionado `ObjectAppearanceService`: cada Pessoa, Animal ou Automóvel confirmado recebe histograma de cor leve; pessoas também usam pistas separadas de tronco/pernas e veículos priorizam a região central do corpo.
- `Detection` passa a carregar `ObjectAppearance` opcional sem alterar o contrato do detector TFLite.
- `ObjectTracker` combina aparência com IoU, distância, tamanho e velocidade; rótulos diferentes da mesma família podem preservar o mesmo ID quando posição/aparência são compatíveis.
- Identidade do track pode ser retida por 12 s após perda temporária. A visibilidade/saída continua obedecendo um limite curto, portanto a memória não mantém objetos inexistentes na tela.
- Chave do anti-repetição passa de `label#trackId` para `grupo#trackId`, evitando nova fala por oscilações como `car↔truck` e `cat↔dog`.
- Transições de entrada/saída do mesmo ID/área recebem cooldown de voz de 5 s para reduzir chatter; o Histórico continua registrando os eventos.
- Áudios personalizados opcionais adicionados via `custom_audio/`. Slots ausentes usam TTS automaticamente; o bootstrap copia `.wav`, `.mp3` ou `.ogg` para `res/raw`.
- `MainActivity` ganha reprodução de slot por `MediaPlayer`, com interrupção/liberação segura do áudio anterior.
- Novos testes cobrem diferença de cor no movimento, extração de cores de roupa, similaridade visual e reaquisicao de veículo com troca de rótulo.
- Versão, metadados, tela de mudanças, README, ARCHITECTURE e verificador preventivo sincronizados em `1.0.37+37`.

### Validação disponível

- `tool/verify_project.sh` cobre os novos componentes e invariantes.
- Este ambiente não contém Flutter SDK; `flutter analyze`, `flutter test` e a geração do APK devem ser confirmados pelo workflow Android APK.

## 1.0.36+36

- Detector passa a filtrar `allowedLabels` dentro do worker antes de aplicar `maxResults`, evitando que classes COCO irrelevantes ocupem as primeiras posições e escondam Pessoa, Animal ou Automóvel selecionado.
- Limiar bruto de candidatos foi ampliado para permitir objetos pequenos/distantes; a aceitação final agora considera classe e área da caixa. Candidatos pequenos usam confirmação temporal de até 3 observações para controlar falsos positivos.
- `TemporalDetectionFilter` ganhou retenção adaptativa por classe/tamanho, reduzindo piscadas durante oclusões curtas sem manter objetos desaparecidos por vários segundos.
- Movimento localizado passa a ser separado em componentes independentes com `focusRegions()`. Dois movimentos distantes deixam de formar um único recorte grande que anulava o ganho de zoom.
- Adicionado `DetectionScanPlanner`: em intervalos controlados (~1,6 s), o pipeline tenta reaquirir um objeto recém-perdido por recorte local ou alterna dois tiles sobrepostos para aumentar a resolução efetiva de objetos pequenos.
- A varredura detalhada é limitada a uma inferência extra por ciclo normal; passagens focadas por movimento têm prioridade para evitar aumento permanente de CPU.
- `DetectionMerger` passa a suprimir duplicatas muito sobrepostas da mesma família (ex.: `car`/`truck`, `cat`/`dog`) mantendo a detecção mais confiante.
- Novos testes cobrem limiar por tamanho, confirmação de objeto pequeno, tiles, reaquisicao, mesclagem semântica e múltiplas regiões de movimento.
- Versão, metadados, tela de mudanças, README, ARCHITECTURE e verificador preventivo sincronizados em `1.0.36+36`.

### Validação disponível

- `tool/verify_project.sh` valida os novos componentes e invariantes da evolução 1.0.36.
- Este ambiente não contém Flutter SDK; `flutter analyze`, `flutter test` e a geração do APK precisam ser confirmados pelo workflow Android APK.

## 1.0.35+35

- Corrigido o único bloqueio mostrado pelo Android-APK-7: `flutter analyze` apontava `unnecessary_import` em `lib/services/shared_local_camera_service.dart`.
- Removido `import 'dart:typed_data';` desse serviço; `Uint8List` continua disponível por `package:flutter/services.dart`, portanto não há mudança funcional na câmera compartilhada.
- Pipeline de detecção da 1.0.34 preservado: EfficientDet-Lite0, fallback SSD, letterbox, confiança adaptativa, confirmação temporal e segunda passagem localizada continuam inalterados.
- `tool/verify_project.sh` passa a impedir a volta desse import redundante.
- Versão, metadados, tela de mudanças, README e ARCHITECTURE sincronizados em `1.0.35+35`.

### Validação disponível

- O log Android-APK-7 confirmou download correto dos dois modelos e `tool/verify_project.sh` aprovado antes do analisador.
- O ambiente local desta correção não contém Flutter SDK; `flutter analyze`, `flutter test` e build do APK devem ser confirmados pelo próximo workflow.

## 1.0.34+34

- Detector principal atualizado para **EfficientDet-Lite0**, mantendo **SSD MobileNet V1** como fallback automático e preservando o mesmo pipeline local/offline.
- Pré-processamento do detector passa a preservar a proporção do frame com letterbox e remapeamento das caixas, evitando deformação geométrica antes da inferência.
- Adicionada política de confiança por grupo: detecções um pouco abaixo do limiar principal podem virar candidatas para Pessoa, Automóvel e Animal, mas precisam de confirmação temporal; detecções fortes continuam imediatas.
- Adicionado `TemporalDetectionFilter`, que exige dois frames coerentes para candidatas fracas e mantém uma detecção confirmada por uma queda curta de frame, reduzindo piscadas e falsos negativos transitórios.
- O modo Somente movimento passa a executar atualização silenciosa de presença a cada 800 ms mesmo em cena parada, evitando que pessoas, animais ou veículos desapareçam apenas por terem parado de se mover.
- `MotionDetectionResult.focusRegion()` identifica movimento localizado. Quando a primeira passagem não encontra objeto útil, uma segunda inferência é feita apenas no recorte ampliado dessa região.
- `DetectionMerger` combina passagem normal e focada sem duplicar o mesmo objeto.
- Regras Inteligentes padrão ficam mais responsivas: veículo 600 ms, animal 800 ms e outros 1.200 ms; Pessoa permanece em 0 ms. Migração do schema para `version: 7` altera somente valores antigos ainda iguais aos padrões, preservando ajustes personalizados.
- `tool/fetch_model.sh` baixa EfficientDet-Lite0 oficial e mantém o SSD como fallback obrigatório; falha apenas no download do modelo principal não impede o build de usar o fallback.
- Testes adicionados para transformação de imagem, confiança adaptativa, confirmação temporal, mesclagem de resultados e região de foco do movimento.
- Versão, metadados, tela de mudanças, README, ARCHITECTURE e verificador preventivo sincronizados em `1.0.34+34`.

### Validação local

- `tool/verify_project.sh` cobre os novos componentes e invariantes da detecção.
- Este ambiente não contém Flutter SDK; `flutter analyze`, `flutter test` e a geração do APK precisam ser confirmados pelo workflow Android APK.

## 1.0.33+33

- Corrigido o conflito de câmera revelado pelo Diagnóstico (`No supported surface combination`): `LocalCameraSource` e Modo Câmera agora usam `SharedLocalCameraService`, mantendo um único `CameraController`/pipeline CameraX e múltiplos consumidores de frames.
- A recuperação de câmera em segundo plano reinicia o pipeline compartilhado, evitando que outro consumidor mantenha uma instância travada.
- Visualizador LAN reformulado: o endereço manual fica limpo (`http://IP:8766`), a chave é digitada separadamente e o acesso automático usa `#key=...`, que não é enviado na requisição HTTP.
- O navegador troca a chave por cookie temporário, remove o segredo da barra e passa a atualizar imagem por `/frame.jpg`, evitando dependência do suporte MJPEG do navegador.
- Estado web agora é real: `/status` informa servidor, frames recentes, sequência, FPS e clientes; a página exibe conexão, ausência de frames ou interrupção em vez de manter “transmissão ativa” fixo.
- Contagem de clientes LAN passou a usar sessões ativas recentes; sessão de autenticação permanece válida por até uma hora sem contar abas inativas como conectadas.
- Frames LAN só são marcados como recentes depois que o JPEG é codificado com sucesso; Saúde do sistema exige frame LAN recente para considerar transmissão operacional.
- Diagnóstico passa a distinguir explicitamente **Servidor LAN**, **Frames LAN recentes** e **Transmissão LAN operacional**, cobrindo o caso em que a página HTTP abre mas nenhuma imagem chega.
- Padrão da câmera local alterado de 800 ms para 400 ms e ausência padrão de 3 s para 1 s. Perfis antigos que ainda usam exatamente os padrões anteriores são migrados automaticamente; ajustes personalizados são preservados.
- Alertas TTS usam política “mais recente primeiro”: uma fala nova interrompe a anterior em vez de manter fila obsoleta, e transições/integridade de alta prioridade ficam protegidas por 5 s contra alertas genéricos.
- Alertas de entrada/saída e detecção confirmada são disparados antes da persistência do evento, evitando que escrita em disco atrase a voz/notificação. Voz e alerta nativo também são iniciados em paralelo, sem esperar o TTS terminar.
- Watchdog Flutter passou de 8 s para 3 s; frames são considerados travados em 4–8 s, conforme o intervalo de análise, e a tentativa de recuperação pode ocorrer novamente após 12 s.
- Foreground Service ganhou heartbeat do Flutter. Se o processo Dart parar de responder por 15 s, a notificação deixa claro que apenas o serviço Android está vivo e solicita reabertura; `START_STICKY` mantém a recuperação disponível após recriação; se só o serviço nativo sobreviver sem heartbeat por 1 minuto, ele se encerra para não manter wake lock/notificação órfãos.
- Saúde do sistema só considera segundo plano operacional quando serviço, heartbeat Flutter, monitoramento e frames estão ativos.
- Monitor e Modo Câmera agora mantêm leases independentes do Foreground Service: desligar um consumidor não encerra o serviço ainda necessário pelo outro, e o tipo `camera`/`specialUse` acompanha os consumidores restantes.
- Aplicativo passa a usar edge-to-edge globalmente; Monitor ao vivo e Modo Câmera usam modo imersivo, restaurando edge-to-edge ao abrir telas comuns.
- Mensagem de erro de inicialização deixa de atribuir falha a “Agendamento” quando o agendamento está desativado; a mesma falha de `start()` deixa de ser registrada em duplicidade como erro da fonte e do chamador.
- Testes de URL LAN e padrões de reação atualizados; verificação preventiva ampliada para câmera compartilhada, sessão web, heartbeat, tela cheia e versão.

### Validação local

- `tool/verify_project.sh` valida identidade, sincronização Android/template, câmera compartilhada, sessão LAN, heartbeat, defaults rápidos, tela cheia e documentação.
- O ambiente de edição não contém Flutter SDK; `flutter analyze`, `flutter test` e o APK devem ser confirmados pelo workflow Android APK.

## 1.0.32+32

- Corrigido o bloqueio do Android APK 4 em `:app:compileReleaseKotlin`.
- Em `localNetworkPermissionStatus()`, `"canRequest" to !granted && !localNetworkPermissionRequestInFlight` era interpretado pelo Kotlin com precedência de chamada infixa, produzindo um `Pair<String, Boolean>` antes do `&&`.
- O valor agora é explicitamente agrupado como `"canRequest" to (!granted && !localNetworkPermissionRequestInFlight)`.
- A correção foi aplicada tanto à árvore Android quanto ao template `tool/android/MainActivity.kt`, que é restaurado pelo workflow antes do build.
- A verificação preventiva passou a exigir a expressão parentizada e a sincronização das duas cópias.
- Metadados, tela de mudanças, teste de versão, README e ARCHITECTURE sincronizados com `1.0.32+32`.

### Validação

- Android APK 4: `flutter analyze` concluiu com **No issues found**.
- Android APK 4: **73 testes passaram**.
- A única falha do pipeline ocorreu depois, na compilação Kotlin da linha de `canRequest`, corrigida nesta revisão.
- O aviso do plugin `flutter_tts` sobre Built-in Kotlin é preventivo/futuro e não foi a causa da falha atual.

## 1.0.31+31

- Corrigido o único teste que falhou no log Android APK 3 após o `flutter analyze` passar sem problemas.
- `MonitorLanStreamService` passa a usar `Uri.encodeComponent` para a chave do visualizador LAN, gerando `%20` para espaços e percent-encoding para caracteres reservados.
- A mesma codificação é aplicada ao endereço compartilhado e à URL do stream MJPEG embutida na página local.
- A leitura no servidor continua usando `request.uri.queryParameters`, portanto a chave é decodificada antes da comparação e o controle de acesso permanece inalterado.
- Metadados, tela de mudanças, teste de versão e verificação preventiva sincronizados com `1.0.31+31`.

### Validação

- Android APK 3: `flutter analyze` concluiu com **No issues found**.
- Android APK 3: 71 testes passaram e somente `monitor_lan_stream_service_test.dart` falhou por esperar `%20` e receber `+`; a causa foi corrigida na origem.
- `tool/verify_project.sh` foi ampliado para validar o uso da codificação canônica da chave LAN.

## 1.0.30+30

- Corrigidos os 5 erros encontrados pelo `flutter analyze` no log Android APK 2.
- `MonitorController` agora importa explicitamente `system_health.dart`, tornando `CameraHealthState` visível nos estados de obstrução, deslocamento e câmera offline.
- `StorageSizeFormatter` passa a usar `0.0` nos caminhos de normalização negativa, evitando inferência `num` ao chamar o formatador que exige `double`.
- Metadados, tela de mudanças, teste de versão e verificação preventiva sincronizados com `1.0.30+30`.
- Nenhuma funcionalidade da ETAPA 4 foi removida.

### Validação

- O log Android APK 2 foi revisado e a falha estava limitada aos 5 erros acima durante `flutter analyze`.
- `tool/verify_project.sh` foi atualizado para validar a correção e a nova versão.

## 1.0.29+29

- ETAPA 4 concluída para Diagnóstico, Saúde do sistema e armazenamento.
- Diagnóstico passa a capturar um snapshot único do estado real e dos registros técnicos; a mesma captura alimenta a tela, o TXT exportado, a cópia e o compartilhamento.
- Adicionados botões **Exportar** e **Compartilhar** no Diagnóstico, com arquivos `vigiaia_diagnostico_*.txt` em documentos/exports/diagnostico.
- Saúde do sistema separa serviço Android, câmera/fonte, frames, IA, LAN, clientes conectados, permissões e funcionamento em segundo plano.
- Serviço Android ativo sem frames recentes não é mais tratado como monitoramento funcionando.
- Frames congelados expiram por heartbeat e derrubam o estado operacional da câmera/IA; LAN também só é considerada transmitindo quando há frames atuais.
- Valores de armazenamento e memória passam por um formatador único, usando B/KB/MB/GB/TB e vírgula decimal na interface em português.
- Tela Armazenamento e backup também usa a mesma formatação, inclusive no limite de fotos e vídeos.
- Botões curtos de ajuda adicionados a Diagnóstico, Saúde do sistema e Armazenamento/backup.
- Bridge Android adiciona compartilhamento nativo de texto do diagnóstico e métricas de memória/armazenamento passam a trafegar em bytes, evitando números crus em MB.
- Novos testes cobrem formatação, expiração de frames, estados da Saúde, geração do diagnóstico e exportação do TXT.
- Versão incrementada para `1.0.29+29`; README, CHANGELOG, ARCHITECTURE, metadados e verificações preventivas sincronizados.

### Validação

- `tool/verify_project.sh` cobre os novos arquivos, testes, identidade técnica e versão.
- `flutter analyze`, `flutter test` e build APK permanecem no workflow GitHub Actions porque o SDK Flutter não está instalado neste ambiente de edição.

## 1.0.28+28

- Identidade técnica migrada integralmente para `vigiaia`, sem hífen em protocolo ou identificadores de projeto.
- Pacote Dart alterado para `vigiaia`; imports de testes atualizados.
- Namespace/applicationId e package Kotlin alterados para `com.vigiaia.app`.
- MethodChannels e alias criptográfico interno migrados de nomes legados para `vigiaia`.
- Protocolo de pareamento alterado para `vigiaia://pair`.
- Workflow/artifact e empacotamento de fonte atualizados para a nova identidade técnica.
- Corrigido `use_null_aware_elements` em `BackgroundMonitorService`, que fazia `flutter analyze` retornar código 1 no Android APK 26.
- Removido import redundante `dart:typed_data` de `MonitorLanStreamService`, eliminando o segundo aviso do analisador.
- Testes de metadados e verificação preventiva sincronizados com `1.0.28+28`.

### Compatibilidade

- Como o `applicationId` foi alterado para `com.vigiaia.app`, o Android trata esta identidade como um aplicativo diferente das builds que usavam o identificador legado.

### Validação

- O log Android APK 26 foi revisado: o pipeline parou apenas porque `flutter analyze` encontrou dois lints de nível `info`; ambos foram corrigidos na origem.
- `tool/verify_project.sh` foi atualizado para rejeitar referências técnicas legadas e conferir a identidade `vigiaia`.

## 1.0.27+27

- Adicionada transmissão do monitor ativo pela rede local para outro celular, acessível diretamente pelo navegador.
- Criado `MonitorLanStreamService`, que publica MJPEG na porta `8766` e reutiliza os frames já entregues ao `MonitorController`; nenhuma segunda instância de câmera é aberta.
- O visualizador HTML, `/stream.mjpg`, `/frame.jpg` e `/status` são protegidos por chave aleatória gerada a cada sessão de monitoramento.
- Botão **Rede local** no monitor mostra o endereço completo, copia para a área de transferência e informa quantos aparelhos estão assistindo.
- O servidor é encerrado junto com a fonte de vídeo, inclusive em pausa de agenda, troca de fonte e encerramento do monitor.
- Manifest e bridge Android preparados para `NEARBY_WIFI_DEVICES` no Android 16 e `ACCESS_LOCAL_NETWORK` no Android 17, solicitando a permissão apenas quando necessária ao fluxo LAN.
- Negar acesso à rede local não derruba a câmera nem a IA; a falha é exibida e registrada separadamente.
- Adicionados testes do endereço de acesso e do parser de status da permissão LAN.
- Versão atualizada para `1.0.27+27`; documentação, tela de mudanças, templates Android e verificação preventiva sincronizados.

### Validação

- `tool/verify_project.sh` valida servidor LAN, MJPEG, chave por sessão, integração com o `MonitorController`, permissões Android e testes novos.
- O ZIP fonte é verificado por integridade. `flutter analyze`, `flutter test` e o APK continuam obrigatórios no GitHub Actions, pois este ambiente não possui SDK Flutter.

## 1.0.26+26

- Permissão da câmera passa a ser solicitada automaticamente na primeira abertura em Android e também é revalidada antes de iniciar uma fonte local.
- Ao conceder câmera pelo fluxo de Iniciar monitoramento, o mesmo toque continua o processo e abre o monitor sem exigir nova tentativa.
- Foreground Service reforçado com tipos Android `camera` e `specialUse`, notificação permanente e `PARTIAL_WAKE_LOCK`.
- O serviço é iniciado enquanto a Activity ainda está visível, antes da câmera local, respeitando as restrições de permissões “while-in-use” do Android 14+.
- `Modo Câmera` agora inicia o foreground service antes da transmissão e o encerra junto com o servidor.
- Monitoramento em segundo plano mantém um heartbeat de frames; a notificação diferencia fluxo saudável de câmera sem imagens recentes.
- Ao bloquear/minimizar, a fonte local permanece ativa quando Segundo plano está habilitado; se os frames pararem, há tentativa de recuperação com cooldown.
- Ao voltar ao app, o serviço e a fonte são revalidados e recuperados quando necessário.
- O serviço mudou para `START_NOT_STICKY` para evitar reinício isolado sem o pipeline Flutter/IA, que poderia deixar notificação “ativa” sem monitoramento real.
- Mantida a recuperação assistida por notificação após boot/atualização, sem tentar abrir câmera silenciosamente a partir do background.
- Versão atualizada para `1.0.26+26`; documentação, tela de mudanças, templates Android e verificações preventivas sincronizados.

### Validação

- Verificação estática do projeto cobre permissão inicial da câmera, tipos de foreground service, `START_NOT_STICKY`, notificação persistente e sincronização dos templates Android.
- `flutter analyze`, `flutter test` e o build APK continuam obrigatórios no workflow GitHub Actions; o SDK Flutter não está disponível neste ambiente local.

## 1.0.25+25

- Nome público alterado para **Vigia IA** em metadados Dart, título do aplicativo, Android Manifest, notificações/avisos nativos, textos internos e documentação.
- `AppMetadata` atualizado para `1.0.25` build `25` e `pubspec.yaml` para `1.0.25+25`.
- Tema padrão de novas instalações alterado para **Escuro**; preferências de aparência já persistidas continuam sendo respeitadas.
- Fallback de preferência visual inválida/corrompida também passa a usar Escuro.
- `app_identity.json` agora registra a identidade pública final e documenta a preservação do `applicationId`/namespace Android.
- `applicationId` e namespace não foram trocados nesta etapa para preservar atualização sobre o app existente e seus dados locais.
- Verificador preventivo atualizado para conferir nome, versão, Manifest, tema padrão e documentação da 1.0.25.
- Adicionado teste unitário dos metadados públicos do aplicativo.

### Validação

- Verificação estática do projeto executada localmente por `tool/verify_project.sh`.
- `flutter analyze` e `flutter test` continuam previstos no workflow; o SDK Flutter não está instalado neste ambiente de edição.
- Nenhuma mudança funcional de câmera, permissões, segundo plano ou LAN foi antecipada nesta etapa; esses itens ficam para as próximas etapas planejadas.

## 1.0.24+24

- Corrigido o `use_build_context_synchronously` em `multi_camera_screen.dart` apontado pelo log do Android APK 22.
- Interface de classes reduzida a **Pessoas, Automóveis e Animais**; classes COCO não relevantes continuam apenas internas ao modelo.
- Automóveis agrupam `car`, `motorcycle`, `bus` e `truck`; Animais usam `bird`, `cat`, `dog`, `horse`, `sheep` e `cow`.
- `ObjectFilterPolicy` normaliza o nome exibido para Pessoa, Automóvel ou Animal, inclusive em alertas, histórico e estatísticas.
- Adicionada migração das seleções antigas para os três grupos atuais, evitando falha ou monitor silencioso após atualização.
- Tela de seleção refeita com três cards e ativação independente de um, dois ou três grupos.
- Navegação principal simplificada para **Início, Histórico, Monitor e Câmeras**; Configurações e Diagnóstico foram retirados da barra inferior.
- Uma única engrenagem centraliza Configurações, reorganizadas em Monitoramento, Alertas, Aparência, Armazenamento, Sistema, Diagnóstico e Sobre; controles técnicos ficam em **Avançado**.
- Histórico passa a exibir apenas passagens relevantes de Pessoa/Automóvel/Animal com mídia, horário, câmera, categoria e confiança quando disponíveis, além de filtros por grupo e câmera.
- Ocorrências de integridade da câmera deixam de ser gravadas no Histórico e permanecem registradas no Diagnóstico.
- Adicionado sistema de aparência persistente com **Sistema, Claro, Escuro** e cores **Turquesa, Azul, Roxo e Laranja**.
- Multicâmera permanece independente de contagem. `CameraEndpoint.countingEnabled` foi adicionado apenas como reserva futura, inicia `false` e não é consumido pelo pipeline atual.
- Textos de rastreamento, áreas, entrada/saída, confiança mínima, intervalo da IA e repetição de alertas foram reescritos em linguagem mais simples.
- Estatísticas ignoram eventos legados fora dos três grupos e agregam resultados por Pessoa/Automóvel/Animal.
- Preservados câmera local, RTSP, celular remoto, QR Code, IA LiteRT/TFLite offline, alertas, rastreamento, áreas, clipes, backup, diagnóstico, presets e funcionamento offline.

### Validação

- `tool/verify_project.sh` foi atualizado para validar a navegação, os três grupos, a migração, a aparência, a separação Histórico/Diagnóstico e a independência da futura contagem por câmera.
- `flutter analyze` e `flutter test` permanecem obrigatórios quando o SDK Flutter está disponível.
- Workflow Android continua responsável pela análise, testes e build do APK em ambiente Flutter completo.

## 1.0.23+23

- Adicionado pareamento entre celulares por **QR Code** sem remover o cadastro manual existente.
- `Modo Câmera` passa a exibir um QR contendo endereço local, chave temporária, versão do protocolo e nome sugerido.
- Criado formato de pareamento próprio `vigiaia://pair`, com validação de versão, tipo, endereço HTTP local e chave de sessão.
- A tela de leitura usa apenas QR Code e rejeita códigos que não pertencem ao Vigia IA.
- A Central multicâmera testa o endpoint remoto antes de confirmar o cadastro; celular offline ou fora da mesma rede não é salvo pelo fluxo de QR.
- Ao escanear um celular já cadastrado no mesmo endereço, a chave de sessão é atualizada no mesmo registro em vez de criar duplicata.
- O servidor remoto passou a priorizar endereços IPv4 privados (10/8, 172.16/12 e 192.168/16) ao montar o endereço exibido/embutido no QR.
- A chave temporária é apagada da memória do serviço quando o Modo Câmera é encerrado e uma nova chave continua sendo criada a cada nova sessão.
- Adicionados `mobile_scanner` e `qr_flutter`; o scanner permanece com ML Kit embarcado para não depender de download na primeira leitura.
- Testes unitários adicionados para round-trip do payload e rejeição de QR, versão e endereço inválidos.
- README, arquitetura, avisos de terceiros, tela de mudanças e verificação preventiva atualizados.

### Validação

- `tool/verify_project.sh` valida versão 1.0.23, dependências QR, codec de pareamento, scanner, teste de conexão e testes unitários.
- `flutter analyze`, `flutter test --reporter expanded --coverage` e `flutter build apk --release` continuam obrigatórios no GitHub Actions.
- Nenhuma função existente de IA, RTSP, histórico, clipes, alertas, backup, presets ou monitoramento foi removida.

## 1.0.22+22

- Consolidadas em uma única release as etapas planejadas de **estabilidade/testes** e **Central multicâmera avançada**.
- Central multicâmera passou a usar grade responsiva: 1 coluna em telas estreitas, 2 em larguras intermediárias e 3 em telas maiores/paisagem.
- Status das câmeras é atualizado automaticamente a cada 15 segundos, com atualização manual disponível e probes executados em paralelo.
- Cada câmera exibe estado online/offline/desativado, latência da verificação, mensagem de conexão e último evento conhecido.
- Câmeras RTSP e celulares remotos agora podem ser renomeados, editados, ativados/desativados ou removidos sem apagar o histórico já registrado.
- O cadastro valida URL RTSP e endereço/chave do celular remoto antes de salvar.
- Eventos passam a persistir `cameraId` estável além do nome da fonte, preservando a associação correta mesmo se a câmera for renomeada depois.
- Eventos antigos sem `cameraId` continuam compatíveis através do vínculo legado pelo nome da fonte.
- `RemotePhoneCameraSource` agora diferencia reconexão transitória de falha persistente e continua tentando recuperar a transmissão automaticamente.
- Testes ampliados para serialização de `cameraId`, persistência do cadastro de câmera e preservação de ID após renomear.
- Workflow Android passa a executar `flutter test --reporter expanded --coverage` e salva `coverage/lcov.info` como artifact quando disponível.
- Nenhuma função existente foi removida ou simplificada.

### Validação

- `tool/verify_project.sh` ampliado para conferir versão, `cameraId`, atualização automática da Central, reconexão remota e cobertura no workflow.
- O pacote continua exigindo `flutter analyze`, testes e `flutter build apk --release` no GitHub Actions.
- Testes não foram afrouxados para mascarar falhas.

## 1.0.20+21

- Corrigido o teste de regressão do `ObjectTracker` que falhava no workflow **Android APK 19** ao cruzar duas pessoas em sentidos opostos.
- A primeira medição válida de velocidade de um track agora inicializa diretamente o vetor de movimento, em vez de ser suavizada contra uma velocidade zero artificial.
- A partir da segunda medição, a velocidade continua usando suavização exponencial para reduzir jitter sem atrasar a previsão de trajetória.
- A caixa prevista passa a acompanhar corretamente a direção inicial do objeto no primeiro cruzamento, reduzindo trocas de `trackId`.
- O teste existente de cruzamento foi preservado sem relaxar expectativas ou alterar dados apenas para fazê-lo passar.
- Nenhuma função de monitoramento, IA, multicâmera, MP4, alertas, backup, armazenamento, presets ou segurança RTSP foi removida.

### Validação

- O log do Android APK 19 foi revisado: `flutter analyze` passou com **No issues found** e o pipeline parou apenas nos testes.
- Resultado do workflow anterior: **44 testes passaram e 1 falhou**, especificamente o cenário de cruzamento do rastreador.
- `tool/verify_project.sh` foi ampliado para impedir a volta da inicialização amortecida de velocidade.
- `flutter analyze`, `flutter test` e `flutter build apk --release` permanecem obrigatórios no GitHub Actions.

## 1.0.19+20

- Corrigido o `flutter analyze` que bloqueava o workflow **Android APK 18**.
- `CameraIntegrityService` agora usa `double` explicitamente nos valores iniciais de brilho e diferença de cena, eliminando erros `num` → `double`.
- `RemotePhoneCameraSource` passou a usar o estado existente `VideoSourceState.streaming` quando o celular remoto está online; removido o estado inexistente `ready`.
- Tela de presets deixou de usar `RadioListTile.groupValue/onChanged` depreciados e passou a usar seleção direta por `ListTile`, preservando o mesmo fluxo de confirmação/aplicação.
- Removidos imports não usados/redundantes apontados pelo analisador.
- Verificação preventiva ampliada para impedir a volta dessas regressões.
- Nenhuma função de monitoramento, IA, multicâmera, MP4, backup, armazenamento, presets ou segurança RTSP foi removida.

### Validação

- O log do Android APK 18 foi revisado: a falha ocorreu em `flutter analyze`, antes dos testes e do build APK.
- `tool/verify_project.sh` continua obrigatório antes da análise estática.
- `flutter analyze`, `flutter test` e `flutter build apk --release` continuam no workflow GitHub Actions.

## 1.0.18+19

- Adicionado clipe real em **MP4/H.264** no Android usando `MediaCodec` + `MediaMuxer`, mantendo GIF como fallback configurável.
- Duração dos clipes configurável entre 3 e 20 segundos, mantendo associação ao mesmo evento do Histórico.
- Histórico passou a reconhecer e reproduzir clipes MP4 localmente.
- Alertas agora permitem combinar **voz, som, vibração e notificação Android** de forma independente.
- Adicionadas frases personalizadas para pessoa, veículo, animal, outros objetos, entrada, saída, câmera obstruída e câmera deslocada.
- Frases específicas por objeto + área agora usam seletores em português e as áreas já configuradas, evitando a necessidade de digitar classes técnicas.
- Adicionado **Modo Câmera** para transformar outro Android em fonte de vídeo pela mesma rede Wi‑Fi/hotspot, sem servidor externo.
- Adicionada **Central multicâmera** para câmera local, RTSP e celulares remotos, com status, último evento e abertura rápida do monitor.
- Fonte de celular remoto integrada ao mesmo pipeline de movimento, IA, regras, rastreamento, histórico e clipes.
- Rastreador evoluído para associação global com IoU, posição prevista, distância, tamanho e velocidade suavizada.
- Anti-repetição de alertas passou a considerar `trackId` quando o rastreamento está disponível.
- Foreground Service passou a usar `START_STICKY` e foi adicionada recuperação assistida após reinício/atualização do app, respeitando as restrições do Android para abertura de câmera em segundo plano.
- Adicionado `MonitorRecoveryReceiver` para boot/atualização e retomada explícita quando o Android exige interação do usuário.
- Credenciais RTSP e segredos da Central multicâmera passaram a ser protegidos com **AES-GCM no Android Keystore** antes de persistir localmente.
- Backups portáteis omitem credenciais e preservam somente dados não sensíveis.
- Adicionadas estatísticas por período, objeto, área, câmera e horário de maior movimento.
- Adicionado gerenciamento de armazenamento com retenção por dias, limite de espaço e limpeza automática/manual.
- Adicionado backup/restauração das configurações e exportação de eventos com JSON, fotos e clipes associados.
- Adicionado **Painel de Saúde do Sistema** com câmera, IA, FPS, bateria, temperatura, armazenamento, memória, segundo plano e erros/avisos recentes.
- Adicionada detecção local de câmera obstruída ou com mudança brusca de enquadramento, com evento e alerta próprios.
- Adicionados presets **Casa, Ausente, Noite e Personalizado**.
- Mantido o dashboard 1.0.17, com as novas funções agrupadas em Ajustes sem remover as ações rápidas da Home.
- Adicionado `app_identity.json` como ponto central de referência para a futura troca de nome/identidade, sem alterar o nome atual.
- Verificação preventiva ampliada para MP4, alertas, multicâmera, Keystore, armazenamento, backup, saúde, presets, recuperação e rastreamento.
- `README.md`, `CHANGELOG.md` e `ARCHITECTURE.md` atualizados.
- `.github/workflows/android-apk.yml` preservado no pacote-fonte.

### Compatibilidade e migração

- Configurações antigas continuam aceitas; `voiceEnabled` é migrado para o novo conjunto de saídas de alerta.
- Eventos antigos com GIF permanecem compatíveis.
- Perfis sem os novos campos recebem valores padrão sem exigir limpeza de dados.
- O nome do aplicativo continua **Vigia IA** até a escolha da identidade definitiva.

### Validação

- `tool/verify_project.sh` deve passar antes do empacotamento.
- `flutter analyze` e `flutter test` permanecem obrigatórios no GitHub Actions e devem ser executados localmente quando o Flutter SDK estiver disponível.
- Nenhum teste foi alterado apenas para mascarar falhas.

## 1.0.17+18

- Reforma visual do dashboard.
- Home mais compacta e ação principal sempre acessível.
- Monitor ao vivo com vídeo dominante, HUD reduzido e painel de detecções recolhível.
- Navegação principal com Início, Eventos, Monitor, Diagnóstico e Ajustes.
- Eventos, Diagnóstico e ajustes avançados compactados.
- Layout próprio em paisagem.
- Adicionada área Sobre, Mudanças e Doações.
- Chave PIX `adriedson@outlook.com` com botão de cópia.

## 1.0.16+17

- Empacotamento do projeto-fonte corrigido para preservar workflow e arquivos ocultos necessários.
- Mantidos monitoramento offline, histórico, áreas, rastreamento e segundo plano.
