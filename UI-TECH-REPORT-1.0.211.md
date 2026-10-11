# Relatório técnico de interface: Vigia IA 1.0.211+211

Base: arquivo completo de `1.0.210+210`. Implementação incremental, sem alterar protocolos RTSP, processamento de IA, persistência do histórico de rotas ou engine de MBTiles.

## Entregue

- `MapWorkspaceShell` substitui `HomeScreen` somente na entrada do papel normal (e na migração legada Bike). A tela `MapMonitoringScreen` continua única e é preservada durante alternância de modos visuais.
- `MapWorkspaceMode` enum independente de `AppLaunchMode`. `MapWorkspaceModePicker` seleciona Explorar, Pedalar, Navegar ou Monitorar sem ativar serviços. A seleção é apenas da sessão; reiniciar retorna ao modo Explorar.
- Botão Modos sobreposto ao mapa, menu Ferramentas sob demanda, painel curto de pedalada com gravação/distância real do `MapRouteService`, acesso explícito ao painel Bike/monitoramento. Navegar sem rota abre a busca de destino do próprio mapa quando há localização válida.
- Recursos legados acessíveis: monitoramento/IA, histórico de eventos, câmeras, configurações, Vigia Bike e escolha do papel do dispositivo. Escolher novo papel substitui a rota e encerra a tela mapa corretamente.
- `workspaceVisible` libera inscrição passiva do GPS, suspende câmeras de propriedade do mapa, cancela assinatura de bússola e interrompe atualizações periódicas de HUD durante navegação para outras ferramentas. Ao retornar, restaura consumidores do mapa. `MapRouteService` continua sendo dono de gravação e navegação, que não são interrompidas com troca de modo/tela.
- `MapMonitoringScreen` não inicializa cadastro de câmeras no carregamento isolado do mapa; abrir gerenciador de câmeras mantém inicialização sob demanda. A entrada normal não exige novamente permissão de câmera/rede local, embora a navegação por GPS continue usando sua autorização própria.
- Pedido nativo de retomada do monitoramento permanece respeitado: entra em `HomeScreen(startMonitorOnLoad: true)`. Papéis dedicados monitor/transmission não foram redirecionados.

## Arquivos de validação

- `test/map_workspace_mode_test.dart`: estados enum e seleção/cancelamento da folha de modos (teste escrito, não executado por falta de Flutter SDK).
- `tool/verify_project.sh` atualizado com contratos do shell/versão. `tool/check_version_sync.py` continua responsável por versão e metadados.

## Resultados neste ambiente

- PASSOU: `python3 tool/check_version_sync.py`.
- PASSOU: `bash tool/verify_project.sh` (incluindo contratos existentes de GPS, Bike, câmeras e IA).
- PASSOU: `bash -n tool/verify_project.sh` e `python3 -m py_compile tool/check_version_sync.py`.
- PENDENTE: `flutter analyze`, `flutter test` e `flutter build apk --release`, pois Flutter/Dart/Android SDK não estão disponíveis.
- PENDENTE: Android físico com permissões restritas, gravação ao apagar a tela, redes, MBTiles, câmera remota, sensores ESP32 e layout em paisagem.

## Limitações conhecidas

- Layout do rodapé com navegação em andamento precisa ser conferido em telas pequenas e modo paisagem, sobretudo com banners expandidos.
- Os modos são visuais e não introduzem gerenciamento independente de todas as tarefas do Android. O painel Navegar aciona a busca existente, mas roteamento Valhalla segue online.
- O onboarding original ainda possui seu próprio fluxo de permissões de câmera; apenas o lembrete na abertura normal do mapa foi alterado.
- Compilação e testes automatizados Flutter não puderam ser executados localmente, portanto a compatibilidade em runtime ainda depende do pipeline Android.

## Próximo incremento recomendado

1. Validar APK 1.0.211 em aparelho, corrigindo qualquer erro de compilação em nova versão sequencial.
2. Medir transição entre modos e saída/retorno de ferramentas com mapa ativo, gravação contínua e monitoramento real.
3. Refinar rodapé responsivo, acessibilidade e estabilidade de GPS em tela apagada com serviço foreground.
