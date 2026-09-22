# Vigia IA 1.0.81+81

Monitor vertical fixo e correção do Android-APK-49.

## Monitor

- o retrato segue a hierarquia da referência: status, modos, câmera, ações e detecções;
- a câmera fica dentro de um cartão com altura estável;
- `Detectados agora` não expande nem cobre a imagem e usa rolagem interna;
- uma ou duas câmeras continuam usando a mesma tela adaptativa;
- sensores Bike permanecem no topo quando estão disponíveis;
- paisagem e tela cheia preservam o HUD compacto existente.

## Bateria

- Receptor mostra a bateria deste celular;
- Câmera local mostra apenas o estado da imagem, pois usa o mesmo aparelho;
- celular remoto e ESP32 continuam mostrando bateria própria quando a telemetria está disponível.

## Buildfix

O Android-APK-49 parou no `flutter analyze` com `use_build_context_synchronously` em `events_screen_actions.dart`. O estado `mounted` agora é verificado imediatamente antes de abrir o seletor de destino após consultar o arquivo.

## Validação

Os verificadores locais, a sincronização e o formatador Dart passam. O Flutter SDK temporário falhou nativamente ao reconstruir sua ferramenta antes do `analyze`; testes e APK assinado permanecem sob responsabilidade do workflow.
