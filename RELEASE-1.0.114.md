# Vigia IA 1.0.114+114

## Entrega

Correção do Android-APK-82. O workflow interrompeu em `flutter analyze`, antes dos testes e da compilação APK. Esta versão corrige os erros e warnings reportados sem avançar ainda para a próxima etapa visual do redesign.

## Correções

- `ButtonStyle.minSize` substituído por `ButtonStyle.minimumSize` em `lib/core/vigia_design.dart`;
- delimitadores de listas corrigidos no seletor de câmera e no `Stack` de `monitor_screen_multicamera.dart`;
- toggles do redesign da Home passam por `_HomeScreenState._updateHomeState`, mantendo `setState` dentro da subclasse de `State`;
- removidos `_MetricChip`, `_LiveDot` e `_showLandscapeQuickActions`, todos privados e sem referência;
- identidade e versão sincronizadas em `1.0.114+114`.

## Preservado

- redesign/fundação da 1.0.113;
- IA, áudio, transmissão, multicâmera, ESP32 e Bike;
- mapas, `RouteExplorerService`, `MapRouteService` e dados offline;
- histórico, diagnóstico e configurações;
- workflow Android otimizado e identidade `Vigia IA` / `vigiaia` / `com.vigiaia.app`.

## Validação

Executar:

```bash
python3 tool/check_version_sync.py
bash tool/verify_project.sh
```

O ambiente local desta correção não possui Flutter/Android SDK. O workflow deve reconfirmar `flutter analyze`, `flutter test` e a compilação release.
