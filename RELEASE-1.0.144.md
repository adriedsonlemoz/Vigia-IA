# Vigia IA 1.0.144+144

## Estados da IA nos PiPs

- Os PiPs do mapa agora exibem um estado compacto e explícito da análise: `IA ativa`, `IA desligada`, `Aguardando frames`, `Sem frames`, `Analisando` e `Possível erro da IA`.
- Problemas da fonte são diferenciados da IA: câmera local com falha mostra `Câmera indisponível`; RTSP, celular remoto e ESP32 em reconexão/erro mostram `Conexão perdida`.
- O estado é calculado a partir do `MonitorController` existente, usando detector, processamento, estado da fonte e último frame recebido; nenhum segundo pipeline de IA foi criado.
- A regra de prioridade impede que o PiP mostre `Analisando` quando a IA estiver desligada ou o detector não estiver pronto.
- Câmeras secundárias e câmeras abertas apenas pelo mapa continuam sendo somente visualização e deixam `IA desligada` explícito quando a fonte estiver normal.
- Quando a câmera analisada também exibe aproximação de veículos, o estado da IA permanece compacto e separado do indicador TTC/risco.

## Testes e validação

- Adicionado `monitor_ai_status_resolver_test.dart` para cobrir IA desligada, análise ativa, primeiro frame, frames vencidos, falha local, perda de conexão e possível erro da IA.
- Adicionado `map_ai_status_overlay_test.dart` para validar os rótulos principais do novo overlay.
- O catálogo global de Novidades ganhou a entrada da versão `1.0.144+144`.
- Versionamento, tela Sobre/Mudanças, README, CHANGELOG, ARCHITECTURE, VALIDATION e User-Agents foram sincronizados.
