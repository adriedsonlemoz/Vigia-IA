# Vigia IA 1.0.116+116

Correção do Android-APK-84. O analyzer do workflow passou sem issues, porém os testes de UI detectaram dois overflows reais introduzidos pela compactação da Home na 1.0.115.

## Correções

- `VigiaModeCard(compact: true)` foi densificado para caber em 160x158 sem `RenderFlex overflow`.
- `VigiaStatusPill` ganhou variante `dense` para reduzir a altura das tags apenas quando necessário.
- `VigiaQuickAction` foi compactado para caber em 104x96, preservando o rótulo **Diagnóstico**.
- Os testes que detectaram as regressões foram mantidos, sem aumentar artificialmente as áreas de teste.

## Preservado

IA, áudio, mapas, transmissão, multicâmera, ESP32, Bike, histórico, identidade `com.vigiaia.app` e o workflow Android permanecem preservados.

## Validação local

Executar `python3 tool/check_version_sync.py` e `bash tool/verify_project.sh`. O workflow deve reconfirmar `flutter analyze`, `flutter test` e o build APK, pois Flutter/Android SDK não estão disponíveis no ambiente local.
