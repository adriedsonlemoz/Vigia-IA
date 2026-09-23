# Vigia IA 1.0.103+103

## Objetivo

Corrigir o Android-APK-71 e tornar visível/controlável o consumo de créditos dos downloads diretos de mapas offline.

## Correção do build

- Removido o operador `!` desnecessário no cálculo de zoom da região selecionada em `offline_map_manager_sheet.dart`.
- O warning `unnecessary_non_null_assertion` do Android-APK-71 deixa de interromper o `flutter analyze`.

## Créditos de mapas

- Cada plano de download mostra tiles, tamanho e **créditos estimados**.
- A referência usada para raster padrão é **1 tile = 1 crédito**.
- Contador mensal local persistente registra somente downloads diretos feitos pelo Vigia IA neste aparelho.
- Limite mensal configurável; padrão de 150.000 créditos com presets de 50k, 100k, 150k e 200k.
- O download é bloqueado se a estimativa ultrapassar o saldo local e recebe aviso quando a projeção passa de 80%.
- O contador reinicia automaticamente quando muda o mês.
- A tela informa explicitamente que não consulta o uso global da conta Stadia e não inclui outros aparelhos/apps.

## Validação local

- `python3 tool/check_version_sync.py` deve passar em `1.0.103+103`.
- `bash tool/verify_project.sh` deve passar.
- Flutter, Dart e Android SDK não estão disponíveis neste ambiente; `flutter analyze`, `flutter test` e o build APK devem ser confirmados pelo workflow.
