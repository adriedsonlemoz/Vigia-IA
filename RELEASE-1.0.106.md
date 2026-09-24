# Vigia IA 1.0.106+106

## Objetivo

Reduzir o tempo de compilação observado no Android-APK-74 sem remover análise estática, testes, cobertura, assinatura ou variantes de APK.

## Mudanças

- Uma única execução Gradle `:app:assembleRelease` gera universal + `armeabi-v7a` + `arm64-v8a` + `x86_64`.
- Geração múltipla é habilitada somente no CI por `VIGIAIA_CI_MULTI_APK=1`.
- APKs são descobertos por `output-metadata.json` e renomeados para `VigiaIA-v1.0.106+106-<tipo>.apk`.
- Cache e paralelismo Gradle ativados.
- `setup-gradle` atualizado para v6, fixado em Gradle 9.1.0 e configurado sem limpeza final do cache.
- Projeto Android existente é reutilizado; bootstrap completo ocorre apenas como recuperação.

## Versionamento

- Versão: `1.0.106+106`.
- `pubspec.yaml`, AppMetadata, `app_identity.json`, Mudanças, README, CHANGELOG, ARCHITECTURE, VALIDATION, testes e verificadores sincronizados.
- O empacotador padrão agora conserva `+106` no nome do ZIP-fonte.
- Android continua usando `flutter.versionName` / `flutter.versionCode`, agora fornecidos ao build Gradle otimizado pelo `local.properties` do CI.

## Validação disponível neste ambiente

Scripts, JSON, YAML estrutural, sincronização de versão e verificadores locais podem ser validados. Flutter/Android SDK não estão disponíveis aqui; o ganho real de tempo e o build completo devem ser confirmados pelo próximo workflow.
