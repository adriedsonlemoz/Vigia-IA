# Vigia IA 1.0.156+156

Buildfix do Android-APK-119 após a estabilização do renderer MapLibre 3D.

## Corrigido

- O workflow falhava em `flutter analyze` com `undefined_getter` em `lib/widgets/map_navigation_3d_view.dart:506:48`.
- `travelMode.storageValue` é fornecido pela extensão `MapTravelModeX`, declarada em `lib/models/map_travel_mode.dart`.
- O renderer importava `map_navigation_target.dart`, mas imports Dart não tornam extensões de bibliotecas dependentes transitivamente disponíveis.
- `MapNavigation3DView` agora importa diretamente `map_travel_mode.dart`, permitindo ao analyzer resolver `storageValue`.
- `tool/verify_project.sh` ganhou uma checagem preventiva para esse import explícito.

## Preservado

- Nenhuma parte da Etapa 2 foi implementada.
- A transição segura FlutterMap 2D → MapLibre 3D, timeout, fallback, logs e telemetria da 1.0.155 permanecem iguais.
- Rota, recálculo, GPS, voz, POIs, gravação, offline/MBTiles e perfis Bicicleta/Moto/Carro/A pé permanecem inalterados.

## Validação

- O erro foi reproduzido a partir do log Android-APK-119 e a causa foi confirmada no escopo de imports do Dart.
- `python3 tool/check_version_sync.py`: **aprovado** localmente.
- `bash tool/verify_project.sh`: **aprovado** localmente.
- Varredura focada do renderer 3D: **aprovada**; o import explícito da extensão está presente e não há `catch (_) {}` silencioso no arquivo.
- Flutter/Dart não estão instalados no ambiente local de edição; `flutter analyze`, `flutter test` e build release precisam ser reconfirmados pelo workflow Android.
- O ZIP de fonte não deve conter APK/AAB.
