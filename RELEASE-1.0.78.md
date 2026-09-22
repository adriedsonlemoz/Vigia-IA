# Vigia IA 1.0.78+78

Entrega focada na composição adaptativa das câmeras, na futura integração física dos sensores da bike e na correção do fluxo inicial.

## Monitor com uma ou duas câmeras

- uma única câmera ocupa toda a área de vídeo;
- duas câmeras usam a mesma tela: empilhadas no modo vertical e lado a lado no horizontal;
- a Central multicâmera pode abrir uma câmera já acompanhada de outra fonte;
- o menu do Monitor permite adicionar, trocar ou remover a segunda imagem;
- somente a câmera principal executa IA, histórico, alertas, clipes e áudios, reduzindo custo em aparelhos de entrada.

## Sensores da bike

- HUD compacto com velocidade Hall, temperatura, pressão dianteira e traseira, bateria dos sensores e distância;
- contrato JSON normalizado e limitado para telemetria ESP32;
- estado desconectado após seis segundos sem atualização;
- status do transmissor inclui telemetria do aparelho e dos sensores;
- o receptor pode exibir os sensores recebidos do celular remoto e continua responsável pela análise.

## Fluxo e navegação

- o Android não solicita mais a câmera antes da tela Acesso inicial;
- o novo marcador de onboarding faz a versão atual explicar permissões antes da escolha de modo;
- permissões obrigatórias removidas depois mostram uma orientação curta, sem repetir toda a configuração;
- botão superior e gesto Voltar do Modo Transmissão retornam à seleção de modo, confirmando a parada quando necessário;
- o transmissor indica se um receptor está conectado e resume os dados enviados sem poluir a tela;
- Configurações > Monitoramento > Modo inicial permanece disponível.

## Validação necessária em dispositivo

Este ambiente de edição não inclui Flutter, Dart ou Android SDK. O workflow deve executar `flutter analyze`, `flutter test` e compilar o APK. Também é necessário testar em um ou dois celulares a rotação, conexão remota, QR, reconexão, permissões e legibilidade da faixa de sensores.
