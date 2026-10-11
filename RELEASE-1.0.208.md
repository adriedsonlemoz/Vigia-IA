# Vigia IA 1.0.208+208

Correção do bloqueio da análise estática no workflow Android APK #172.

## Mudanças

- `RadioCatalogCache` e `RadioHealthService` usam initializing formals em construtores privados para atender ao lint `prefer_initializing_formals`.
- A fábrica pública mantém os parâmetros nomeados `file:` e os comportamentos anteriores do cache e das estações de rádio.
- Permanecem as melhorias RTSP, logs persistentes de etapas e modo de compatibilidade da 1.0.207.

## Validação

- Confirmar `bash tool/verify_project.sh` e `python3 tool/check_version_sync.py`.
- No GitHub Actions, executar `flutter analyze`, `flutter test` e compilação Android release assinada.
- Para investigar o encerramento RTSP no telefone, usar o novo diagnóstico e, se houver crash nativo, `adb logcat`.

**Nota:** os logs do workflow #172 não incluem nenhuma execução de câmera RTSP em Android.
