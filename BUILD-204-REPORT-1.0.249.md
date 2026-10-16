# Relatório do workflow Android-APK-204 — Vigia IA 1.0.249+249

## Linha do tempo medida no ZIP dos logs

- Job 23:44:18–23:56:54 UTC (12 min 36 s).
- Flutter setup 23:44:22–23:44:42 (20 s).
- Gradle setup 23:44:42–23:45:24 (42 s).
- Dependências 23:45:26–23:45:27 (~1,5 s).
- Verificação preventiva 23:45:27–23:45:31 (~4 s).
- `flutter analyze --fatal-infos --fatal-warnings` 23:45:31–23:45:47 (15 s): **No issues found**.
- `flutter test --reporter expanded --coverage` 23:45:47–23:56:44 (10 min 57 s): +529 -1, último teste expira em 10 min.
- Teste travado: `test/mcrp_saved_cameras_screen_test.dart` (lista câmera sem expor token e permite remover cadastro), iniciado 23:46:43 e finalizado 23:56:43.
- Nenhum APK foi compilado, pois os testes bloqueiam o gate da compilação.

## Diagnóstico

O `testWidgets` aguardava `Directory.systemTemp.createTemp`, `store.save` e I/O de arquivo dentro da zona de tempo simulado do Flutter. Esses Futures reais podem ficar pendentes sem `tester.runAsync`. Testes da persistência em disco devem permanecer como `test()` sem `testWidgets`.

## Correção

- Substituído acesso real a disco no teste de widget por `McrpSavedCamerasStore` fake em memória, implementando `load` e `remove`; interface, token oculto, confirmação e remoção continuam testados.
- Testes unitários de persistência real mantidos inalterados, cobrindo escrita, leitura, deduplicação, remoção e limites.
- `--timeout 120s` por teste e `timeout-minutes: 7` na etapa, preservando `--coverage` e todos os casos.
- 6 testes preventivos Python e verificador estrutural adicionados ao gate existente.

## Limites

A correção da causa é fundamentada na inspeção do código e no timeout observado. Não existe SDK Flutter/Android local para confirmar execução. O tempo da compilação Gradle não está disponível nos logs porque o workflow parou nos testes; não é possível prometer build completo abaixo de 10 minutos.
