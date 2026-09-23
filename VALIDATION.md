# Validação — Vigia IA 1.0.90+90

Data: 2026-09-22. Base preservada: 1.0.89+89.

## Executado nesta entrega

| Verificação | Resultado |
|---|---|
| `bash tool/verify_project.sh` | Passou, incluindo sincronização de versão, contratos antigos e os ajustes de dashboard ao vivo com mapa desta entrega |
| Sincronização de versão | `pubspec.yaml`, AppMetadata, app_identity.json, Mudanças, README, CHANGELOG, arquitetura e release notes em 1.0.90+90 |
| Fontes Android espelhadas | `MainActivity.kt`, `AlertAudioPlayer.kt` e `AudioResourceCatalog.kt` são idênticos entre `tool/android` e o projeto Android gerado |
| JSON e scripts shell | Estruturas válidas e scripts sem erro de sintaxe do Bash |
| Áudios padrão | 78 arquivos M4A preservados em `custom_audio` e `res/raw`; verificador confirma igualdade dos bytes |
| Codec dos áudios | `ffprobe` validou os 78 arquivos como AAC-LC, mono, 24 kHz e com duração positiva |
| Transporte remoto | Sequência, timestamp UTC, cache desativado, resposta 204 e descarte de duplicatas protegidos pelo verificador |
| Tela vertical do monitor | Câmera maior, mini-mapa em retrato, ações horizontais e painel avançado sob demanda implementados no `MonitorScreen` |
| Interface | Faixa permanente de receptor/transmissor protegida pelo verificador e ligada ao Status da sessão |
| Painel ao vivo em paisagem | Cabeçalho, mini-mapa, cards de telemetria e barra de ações do novo dashboard implementados no `MonitorScreen` para câmera única |
| Buildfix Android-APK-57 | Extensão do dashboard sem chamadas diretas a `setState`, eliminando `invalid_use_of_protected_member` do `flutter analyze` |
| Buildfix Android-APK-40 | Operador nulo desnecessário e import redundante removidos |
| Seleção de modo | Normal, Monitor, Bike e Transmissão persistidos por `AppLaunchModeService` e protegidos por teste |
| Paisagem/monitor | AppBar fixa removida em paisagem, HUD superior compacto e saída explícita protegidos pelo verificador |
| Modo Câmera | Estado parado integrado, painel adaptativo e saída/parada claras protegidos pelo verificador |
| Buildfix Android-APK-43 | `unnecessary_non_null_assertion` removido de `camera_mode_screen.dart` e protegido contra regressão |
| Telemetria de áudio | Foco, fase, códigos MediaPlayer, origem, arquivo, volume, rota, tempos e fallback protegidos pelo verificador |
| Catálogo de áudio | 78 slots Dart, 78 referências `R.raw` explícitas e 78 M4A comparados automaticamente |
| Fluxo Monitor | Tela receptora, QR, endereço/chave manual, Central multicâmera e fonte Celular remoto protegidos pelo verificador |
| Câmeras adaptativas | Política testável para uma câmera integral, duas empilhadas no retrato e duas lado a lado na paisagem |
| Segunda câmera | Preview e status independentes, sem duplicar o pipeline de IA da câmera principal |
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
| Monitor vertical | Câmera e detecções em regiões fixas; painel expansível removido |
| Bateria | Telemetria local aparece uma vez; bateria adicional somente para fonte remota |
| Telemetria ESP32/Bike | Faixa superior reorganizada em uma única linha horizontal rolável, sem grade quebrada no retrato |
| Diagnóstico | Estados Serviço/Câmera/Frames/IA/LAN/clientes/Permissões/2º plano ficam em faixa horizontal compacta; ações de 30 s, 60 s e Exportar permanecem juntas |

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

## Layout de paisagem e transmissão

Validações manuais recomendadas no aparelho:

- abrir Monitor em retrato e confirmar que o fluxo anterior permanece legível;
- girar para paisagem e confirmar que a imagem preenche a tela sem AppBar fixa;
- confirmar que pressão, velocidade, status dos aparelhos e ações ficam juntas no topo;
- entrar em tela cheia e confirmar botões para sair da tela cheia e sair do monitoramento;
- abrir Modo Câmera parado e confirmar o estado visual integrado;
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

O formatador do Dart 3.13.3 validou e formatou os arquivos alterados. Um Flutter SDK temporário resolveu o próprio cache, mas sofreu falha nativa ao reconstruir a ferramenta antes de executar o comando do projeto; o analisador Dart isolado não consegue resolver `package:flutter` sem essa etapa. Por isso, `flutter analyze`, `flutter test` e a compilação do APK assinado continuam obrigatórios no workflow incluído.

O teste final em aparelho deve confirmar áudio integrado, override importado/gravado, volume, Bluetooth/alto-falante e fallback TTS. Se houver falha, o diagnóstico agora informa código `what/extra`, etapa, origem, foco, arquivo, tamanho, rota e tempos da tentativa. O teste em dois celulares continua necessário para latência visual, baterias, reconexão, rotação e tela inteira.

## Mapa/GPS 1.0.86

- verificação estática: permissões `ACCESS_COARSE_LOCATION` e `ACCESS_FINE_LOCATION` presentes;
- dependências cartográficas declaradas no `pubspec.yaml`;
- acesso ao mapa integrado ao Modo Bike sem alterar os quatro destinos da navegação principal;
- tratamento de GPS desligado e permissões negada/bloqueada implementado;
- `flutter analyze`, `flutter test` e build Android ainda precisam ser confirmados no workflow porque o ambiente local desta entrega não possui Flutter/Android SDK completo.
