# Relatório do build Android-APK-194 e correção 1.0.239+239

## Diagnóstico observado

- Logs do workflow 194: verificação preventiva passou (`36 tests`, contratos estruturais anteriores válidos).
- `flutter analyze --fatal-infos --fatal-warnings` encerrou com código 1 por 10 mensagens informativas `use_key_in_widget_constructors`.
- Foram identificados 2 construtores em `map_navigation_metrics.dart`, 1 em `map_navigation_record_control.dart`, 1 em `map_route_alternatives_button.dart`, 1 em `map_route_preview_card.dart`, 2 em `map_status_indicators.dart`, 1 em `map_telemetry_strip.dart` e 2 em `map_zoom_controls.dart`.
- Os logs não mostram execução de `flutter test` nem compilação do APK; nenhuma conclusão sobre esses estágios pode ser tirada do build 194.

## Solução

- Usado `super.key` opcional nos construtores nomeados de todos os dez widgets públicos, preservando seus demais argumentos e corpos.
- Mantidos os hashes históricos das transposições 234–238, com remoção exclusiva da nova linha `super.key` na entrada da comparação; não foram aceitas alterações dos corpos dos widgets.
- Criado `tool/check_map_widget_keys_239.py`, incorporado à verificação preventiva.
- Atualizados pubspec, AppMetadata, arquivos de identidade, testes de metadados, User-Agents, notas, Novidades e os dois painéis de histórico.

## Pendências

- Validação preventiva: `bash tool/verify_project.sh` aprovado, 40 testes Python e os contratos das etapas 233–238. Fontes dos sete widgets confrontadas com o ZIP 1.0.238: somente `super.key` mudou; a tela principal de mapas permanece byte a byte idêntica.
- Integridade do ZIP: a verificar no empacotamento final.
- Executar no GitHub Actions: `flutter analyze --fatal-infos --fatal-warnings`, `flutter test`, build Android e testes físicos.
