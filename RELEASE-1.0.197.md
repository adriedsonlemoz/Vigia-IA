# Vigia IA 1.0.197+197

Entrega de estabilização do pipeline após a inclusão da telemetria global de uso de dados.

## Correção principal

- `DataUsageService` mantém a referência do `Timer.periodic` e cancela defensivamente uma instância anterior antes de registrar a próxima.
- O aviso `unused_field` apontado pelo `flutter analyze` deixa de ocorrer sem desativar regras do analisador.
- O intervalo de atualização permanece em 15 minutos.
- Áudio global, rádio persistente, mapa e telemetria adicionados na 1.0.196 permanecem inalterados.

## Validação

- `python3 tool/check_version_sync.py`
- `bash tool/verify_project.sh`
- `flutter analyze`
- `flutter test`
- workflow Android completo para geração do APK

## Instalação

Esta entrega usa `versionName 1.0.197` e `versionCode 197`. O APK não faz parte do ZIP de código-fonte.
