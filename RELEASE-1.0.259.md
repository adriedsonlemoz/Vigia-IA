# Vigia IA 1.0.259+259: correção do workflow Android APK 213

## Diagnóstico

A análise estática detectou `duplicate_definition` para o getter `activeDetectorModel` em `monitor_controller_ai_support.dart:51`. O pipeline preventivo foi concluído, mas a etapa `flutter analyze --fatal-infos --fatal-warnings` bloqueou o build antes de compilar o APK.

## Correção

- Removida a segunda declaração do mesmo getter. `activeDetectorModel` continua disponível para os relatórios e para o seletor manual de IA.
- Adicionado contrato estático e três testes que simulam duplicação e garantem uma única declaração. O teste YOLO histórico deixou de exigir literalmente a versão 1.0.258.
- Preservada toda a seleção do modelo Automático, diagnóstico de 15/30/60 segundos, fallback, câmera local/RTSP/ESP32/MCRP e transmissão sem IA.

## Validação

- `python3 tool/check_analyzer_213_259.py`
- `python3 -m unittest -q tool/test_analyzer_213_259.py`
- `python3 tool/check_version_sync.py`
- `bash tool/verify_project.sh`
- `flutter analyze`, `flutter test` e `flutter build`: executar no CI, pois o SDK Flutter não está disponível neste ambiente.
