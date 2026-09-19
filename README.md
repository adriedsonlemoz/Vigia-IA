# Vigia IA

Aplicativo Flutter, inicialmente para Android, para monitoramento local por câmera do aparelho, câmera IP/RTSP ou outro celular na mesma rede. A detecção de objetos, regras, histórico, alertas e processamento de IA são executados localmente sempre que possível.

> **Versão atual:** `1.0.43+43`

## Estado atual

A `1.0.43+43` é um buildfix da Etapa 3 do Modo Bike: remove dois casts desnecessários apontados pelo Flutter 3.44, preservando o painel remoto e liberando a análise estática do workflow.

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

O app continua funcionando sem nenhum arquivo extra. Para usar sua própria voz/gravação, coloque um único `.wav`, `.mp3` ou `.ogg` em `custom_audio/`. Há slots de detecção (`person_detected`, `vehicle_detected`, `animal_detected`, `object_detected`), entrada/saída por categoria (`person_entered`, `person_exited`, `vehicle_entered`, `vehicle_exited`, `animal_entered`, `animal_exited`) e fallbacks genéricos (`object_entered`, `object_exited`), além de `camera_obstructed` e `camera_moved`. O workflow copia esses arquivos para os recursos Android. Se um slot estiver ausente, o Vigia IA usa o TTS do Android. Consulte `custom_audio/README.md` para o passo a passo.

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
./tool/verify_project.sh
flutter analyze
flutter test
flutter build apk --release
```

O workflow `.github/workflows/android-apk.yml` executa a mesma sequência e publica o APK como artefato quando tudo passa.

O projeto-fonte pode ser empacotado com:

```bash
./tool/package_source.sh
```

O empacotador preserva `.github/workflows/android-apk.yml`, `.gitignore`, scripts e demais arquivos necessários ao CI.

## Privacidade

- a IA roda localmente;
- não existe envio automático de vídeo para nuvem;
- o modo celular remoto usa a rede local definida pelo usuário;
- fotos, clipes, eventos, configurações e estatísticas ficam no aparelho;
- credenciais RTSP persistidas no Android são protegidas pelo Keystore;
- backups portáteis não incluem credenciais sensíveis.
