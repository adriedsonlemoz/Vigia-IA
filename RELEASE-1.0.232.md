# Vigia IA — Release 1.0.232+232

Data: 12/10/2026 · versionCode 232 · correção isolada do Android APK #191

## Alterações

- Adicionadas chaves na condição de `MapMonitoringScreen._scheduleRouteRecovery` que bloqueia reagendamentos quando offline, sem alterar o resultado da condição nem a execução da navegação.
- Adicionada regressão negativa para impedir retorno do aviso `curly_braces_in_flow_control_structures` no mesmo ponto.
- Metadados, documentação, Novidades, telas Sobre/Mudanças e User-Agents atualizados sequencialmente.

## Evidência e limitações

O workflow #191 da versão 1.0.231 passou na verificação preventiva, mas o `flutter analyze` apresentou um aviso fatal em `map_monitoring_offline_support.dart:73:54`; não executou `flutter test` nem compilou o APK. A análise Flutter e o APK da 1.0.232 ainda precisam ser confirmados em CI. Não houve alteração funcional dos módulos de câmera, IA, ESP32, rádio e mapas.

A instalação/teste manual cumulativo do ciclo 228–231 deve ocorrer após CI aprovado, antes da refatoração gradual.
