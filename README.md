# Vigia IA

Aplicativo Flutter, inicialmente para Android, para monitoramento local por câmera do aparelho, câmera IP/RTSP ou outro celular na mesma rede. A detecção de objetos, regras, histórico, alertas e processamento de IA são executados localmente sempre que possível.

> **Versão atual:** `1.0.30+30`

## Estado atual

A `1.0.30+30` é uma correção de build da ETAPA 4. Mantém as funcionalidades introduzidas na `1.0.29+29` e corrige os erros detectados pelo `flutter analyze` no Android APK 2.

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

O Foreground Service continua opt-in e usa notificação persistente + `PARTIAL_WAKE_LOCK`. Na 1.0.26 ele usa o tipo `camera` quando a câmera local está ativa e `specialUse` para fontes sem câmera. O serviço usa `START_NOT_STICKY` para não renascer sozinho sem o pipeline Flutter/IA.

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
