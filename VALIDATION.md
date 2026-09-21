# Validação — Vigia IA 1.0.74+74

Data: 2026-09-22. Base preservada: 1.0.73+73.

## Executado nesta entrega

| Verificação | Resultado |
|---|---|
| `bash tool/verify_project.sh` | Passou, incluindo versão, identidade, recursos, espelhos Android, contratos da 1.0.71, buildfix da 1.0.72, seleção inicial da 1.0.73 e HUD paisagem da 1.0.74 |
| Sincronização de versão | `pubspec.yaml`, AppMetadata, app_identity.json, Mudanças, README, CHANGELOG e arquitetura em 1.0.74+74 |
| Fontes Android espelhadas | `MainActivity.kt` e `AlertAudioPlayer.kt` são idênticos entre `tool/android` e o projeto Android gerado |
| JSON e scripts shell | Estruturas válidas e scripts sem erro de sintaxe do Bash |
| Áudios padrão | 78 arquivos M4A preservados em `custom_audio` e `res/raw`; verificador confirma igualdade dos bytes |
| Transporte remoto | Sequência, timestamp UTC, cache desativado, resposta 204 e descarte de duplicatas protegidos pelo verificador |
| Interface | Faixa permanente de receptor/transmissor protegida pelo verificador e ligada ao Status da sessão |
| Buildfix Android-APK-40 | Operador nulo desnecessário e import redundante removidos |
| Seleção de modo | Normal, Bike e Transmissão persistidos por `AppLaunchModeService` e protegidos por teste |
| Paisagem/monitor | AppBar fixa removida em paisagem, HUD superior compacto e saída explícita protegidos pelo verificador |
| Modo Câmera | Estado parado integrado, painel adaptativo e saída/parada claras protegidos pelo verificador |

## Layout de paisagem e transmissão

Validações manuais recomendadas no aparelho:

- abrir Monitor em retrato e confirmar que o fluxo anterior permanece legível;
- girar para paisagem e confirmar que a imagem preenche a tela sem AppBar fixa;
- confirmar que pressão, velocidade, status dos aparelhos e ações ficam juntas no topo;
- entrar em tela cheia e confirmar botões para sair da tela cheia e sair do monitoramento;
- abrir Modo Câmera parado e confirmar o estado visual integrado;
- iniciar transmissão e confirmar botão Parar e saída clara no topo.

## Seleção inicial de modo

O fluxo atualizado mantém o guia de permissões em primeiro lugar. Quando ele termina, o app abre `LaunchModeScreen` e pede a escolha entre:

- Modo normal: abre a Home;
- Modo Bike: abre o painel Bike;
- Modo transmissão: abre o Modo Câmera.

A decisão é salva em `launch_mode.json` e pode ser revista em Configurações > Monitoramento > Modo inicial.

## Correção do Android-APK-40

O log falhou em `flutter analyze` com dois avisos tratados como erro:

- `invalid_null_aware_operator` em `remote_camera_server_service.dart`;
- `unnecessary_import` em `remote_phone_camera_source_test.dart`.

Ambos foram corrigidos sem alterar o comportamento funcional do vídeo remoto.

## Teste acrescentado

`remote_phone_camera_source_test.dart` cria um servidor HTTP local, entrega um JPEG com sequência e confirma que:

- o receptor consulta novamente em menos de um segundo, mesmo com intervalo de análise maior;
- a resposta `204` é tratada como conexão saudável;
- o mesmo quadro remoto não é publicado duas vezes para a IA.

## Pendente no workflow e no dispositivo

Este ambiente não possui Flutter, Dart ou Android SDK. Por isso, `flutter analyze`, `flutter test` e a compilação do APK não puderam ser executados localmente e continuam obrigatórios no workflow incluído.

O teste final em dois celulares deve confirmar latência visual, atualização das duas baterias, reconexão, áudio padrão, rotação, tela inteira e Ajustar/Preencher. O diagnóstico de áudio agora informa também o identificador do recurso e o erro de abertura caso o aparelho ainda rejeite algum arquivo. Um futuro mini mapa/GPS deve ser validado no receptor, não como tela do transmissor.
