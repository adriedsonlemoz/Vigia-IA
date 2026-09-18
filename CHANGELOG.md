# CHANGELOG

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
