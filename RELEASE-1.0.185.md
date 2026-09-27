# Vigia IA 1.0.185+185

## Entrega

Esta release transforma os cinco cards de telemetria do mapa em um painel de instrumentos contextual para cicloviagem, mantendo a leitura compacta na tela principal e expandindo detalhes somente sob demanda.

## Principais mudanças

- Painéis responsivos: bottom sheet em retrato e painel lateral em paisagem.
- Velocidade com mostrador semicircular, média, máxima, distância, tempo, precisão e comparação do ritmo atual.
- Altitude com perfil gráfico real, mínima, máxima, amplitude, tendência e filtro de precisão vertical ruim.
- GPS com qualidade baseada em precisão/idade, coordenadas, heading, velocidade, altitude e leituras rejeitadas.
- Bússola com rosa dinâmica, graus, fonte real e troca de orientação Norte/Direção/Rota.
- Clima com previsão horária de até 12 horas, incluindo temperatura, sensação, chuva, vento, rajadas, direção e condição WMO.
- Avaliação meteorológica local para pedal, com limites explícitos e aviso de que não substitui alertas oficiais.
- Cache de clima atualizado para schema 2 e testes ampliados para previsão, GPS e altitude.

## Compatibilidade

- Busca incremental, rotas, mapas offline, Bike/ESP32, pressão dos pneus, IA, câmeras e alertas da 1.0.184 foram preservados.
- Nenhum serviço paralelo de GPS, clima ou ESP32 foi criado.
- O ZIP de entrega contém somente código-fonte; APK/AAB não faz parte do pacote.

## Validação realizada

- `python3 tool/check_version_sync.py`: aprovado em `1.0.185+185`.
- `python3 tool/verify_audio_resource_catalog.py`: aprovado, 78 slots de áudio Android validados.
- `bash -n tool/verify_project.sh`: aprovado.
- `bash tool/verify_project.sh`: aprovado, incluindo os contratos antigos preservados e os novos painéis 1.0.185.
- Revisão estrutural dos Dart alterados: delimitadores balanceados e JSONs de identidade válidos.
- `flutter analyze` e `flutter test` não foram executados neste ambiente porque os executáveis Flutter/Dart não estão instalados; continuam obrigatórios no CI/ambiente Flutter antes do APK de produção.
