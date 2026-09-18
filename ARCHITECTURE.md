# Arquitetura — Vigia IA 1.0.35+35

## 1. Princípios

A 1.0.35 mantém integralmente a arquitetura de detecção da 1.0.34 e corrige somente o aviso de análise estática no serviço de câmera compartilhada. O pipeline continua priorizando EfficientDet-Lite0 com fallback SSD, preservando a geometria da imagem antes da inferência, estabilizando candidatas fracas no tempo e usando uma segunda passagem apenas quando o movimento localizado justifica o custo.

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
- `MotionDetectionService` — movimento e região de foco;
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

`tool/bootstrap_android.sh` recria a plataforma com o template do Flutter e reaplica esses arquivos. Isso evita perder integrações nativas quando `android/` é regenerado no CI.

## 16. Verificação e CI

`tool/verify_project.sh` valida regressões estruturais, a presença das funções 1.0.18, as correções de build 1.0.19 e a inicialização de velocidade do rastreador corrigida na 1.0.20.

O workflow `.github/workflows/android-apk.yml` executa:

1. bootstrap do Android;
2. obtenção do modelo quando necessário;
3. `flutter pub get`;
4. `tool/verify_project.sh`;
5. `flutter analyze`;
6. `flutter test`;
7. `flutter build apk --release`;
8. upload do APK.

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
