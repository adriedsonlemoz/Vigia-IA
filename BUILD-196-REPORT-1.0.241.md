# Relatório Android-APK-196: correção 1.0.241+241

## Diagnóstico verificado

- Fonte: `Vigia-IA-Android-APK-196-logs.zip` / `build/11_Analise estatica.txt` e `build/13_Testes.txt`.
- `flutter analyze --fatal-infos --fatal-warnings`: `No issues found!`.
- Testes Flutter: `01:28 +499 -1`, total de 500 testes concluídos e um caso falhando.
- Erro na linha 59 de `test/map_telemetry_strip_test.dart`, caso `apresenta velocidade, altitude, rumo, GPS e clima ausente`: `Expected: exactly one matching candidate`, `Found 0 widgets with text "553"`.
- `_MapTelemetryCard` renderiza um `Text.rich` com `TextSpan` para valor e unidade, e o texto renderizado é `553 m`. O teste usava `find.text('553')`, que compara a string completa e não corresponde ao valor com unidade.
- O caso continha também `find.text('±8')`, enquanto a precisão GPS possui `unit: 'm'`, formando `±8 m`. Essa asserção ainda não havia sido executada por causa da primeira falha; foi corrigida preventivamente.

## Alteração e escopo

- `test/map_telemetry_strip_test.dart`: duas expectativas atualizadas (`553 m`, `±8 m`), mais uma cobertura nova para o modo compacto verificando também que os valores sem unidade não são encontrados isoladamente.
- `tool/check_build196_telemetry_units_241.py` e `tool/test_build196_telemetry_units_241.py`: garantias preventivas, com cinco testes Python incluindo mutações negativas.
- `tool/verify_project.sh` chama ambos os verificadores; continua executando todos os contratos anteriores e não desativa Flutter Analyze/Test.
- Nenhum arquivo do aplicativo em `lib/widgets/map_telemetry_strip.dart` ou `lib/screens/map_monitoring_screen.dart` foi alterado, salvo metadados de versão, documentação, User-Agent, Sobre e Novidades.

## Limitações

- O SDK Flutter/Android não está disponível no ambiente local. As correções estão apoiadas nos logs e no código exato do widget, mas a suíte completa e o APK da 1.0.241 ainda precisam ser testados em GitHub Actions.
