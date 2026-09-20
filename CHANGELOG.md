# CHANGELOG

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
