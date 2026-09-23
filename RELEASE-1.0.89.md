# Vigia IA 1.0.89+89

## Correção Android-APK-57

O workflow parava no `flutter analyze` com quatro avisos `invalid_use_of_protected_member` em `monitor_screen_landscape_dashboard.dart`.

## Alteração

- Removidas as chamadas diretas a `setState` de dentro da extensão do dashboard.
- As atualizações passam por `_updateMulticameraState`, método da própria `_MonitorScreenState`, mantendo o mesmo comportamento visual.
- O dashboard Ao vivo, mini-mapa, GPS, telemetria da bike, alertas e ações rápidas permanecem funcionais no código-fonte.
- Verificador preventivo ampliado para detectar a regressão antes do workflow.
