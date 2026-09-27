# Vigia IA 1.0.198+198

Entrega de estabilização da compilação Android da telemetria global de uso de dados.

## Correção principal

- `TrafficStats.getUidRxBytes()` e `TrafficStats.getUidTxBytes()` retornam `Long`.
- O sentinela `TrafficStats.UNSUPPORTED` é convertido explicitamente com `toLong()` antes da comparação, removendo a incompatibilidade de tipos registrada no build 159.
- O comportamento funcional permanece o mesmo: métricas válidas são enviadas ao Flutter; valores não suportados continuam como `null`.
- A correção foi mantida também em `tool/android/MainActivity.kt`, evitando que a cópia de referência fique divergente.
- Áudio global, rádio persistente, mapa e telemetria das versões anteriores permanecem preservados.

## Validação

- `python3 tool/check_version_sync.py`
- `bash tool/verify_project.sh`
- `flutter analyze`
- `flutter test`
- workflow Android completo, incluindo `:app:compileReleaseKotlin` e geração dos APKs release

## Instalação

Esta entrega usa `versionName 1.0.198` e `versionCode 198`. O APK não faz parte do ZIP de código-fonte.
