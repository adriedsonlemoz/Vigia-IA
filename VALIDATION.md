# Validação — Vigia IA 1.0.103+103

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
