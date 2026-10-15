# Relatório de correção: Android-APK-195 / Vigia IA 1.0.240+240

## Evidências do workflow

- Log analisado: `Vigia-IA-Android-APK-195-logs.zip`, etapa `Testes`.
- `flutter analyze --fatal-infos --fatal-warnings` foi concluído sem falhas; o workflow prosseguiu até `flutter test`.
- A suíte terminou com `01:34 +497 -3`, três testes falhando:
  1. `test/map_telemetry_strip_test.dart`, caso `apresenta velocidade, altitude, rumo, GPS e clima ausente`, linha 58: buscava `19.8`, inexistente como texto isolado.
  2. `test/map_telemetry_strip_test.dart`, caso `layout compacto mantém cartões sem mostrar fonte secundária`: mesma expectativa `19.8` no formato compacto.
  3. `test/map_status_indicators_test.dart`, caso `velocimetro foca detalhe por callback e preserva fonte/rumo`, linha 44: buscava `GPS · rumo 92°`, mas a implementação tem `GPS · 92°`.
- Não ocorreu falha de compilação Dart demonstrada nem a etapa de geração de APK; o pipeline parou antes da compilação Android.

## Correção aplicada

- `find.text('19.8')` substituído exatamente duas vezes por `find.text('19.8 km/h')`. `Text.rich` usa `TextSpan` principal com valor e `TextSpan` secundários com espaço e unidade, e o finder do Flutter compara o conteúdo textual completo.
- Corrigida uma expectativa do velocímetro de foco para `find.text('GPS · 92°')`, preservando o formato produzido pela interface original.
- Os arquivos de widgets de produção permanecem sem alterações desde 1.0.239; não foram adicionadas dependências, rotinas de atualização nem consumo de bateria.
- Acrescentado `tool/check_build195_widget_text_240.py` ao verificador preventivo, e sincronizado todo o versionamento.

## Limitações e próximos passos

- As alterações dos três testes atacam diretamente as três falhas observadas no CI #195; não é possível declarar a nova suíte como aprovada sem novo `flutter test` executado no GitHub Actions.
- O SDK Flutter/Android não estava disponível no ambiente local. Executar `flutter analyze`, `flutter test` e o build Android para 1.0.240, seguido por validação em aparelho.
