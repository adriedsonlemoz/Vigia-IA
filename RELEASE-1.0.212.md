# Vigia IA 1.0.212+212 — Buildfix do Android APK #176

## Resumo

- Correção do teste de widget do seletor de modos da interface 1.0.211.
- `tester.pageBack()` tentava localizar `CupertinoNavigationBarBackButton` ou `BackButton`; esse componente nao existe no painel modal.
- Simulacao de Voltar do Android via `tester.binding.handlePopRoute()` e teste adicional de cancelamento pela barreira escura externa.
- Mantem inalteradas as funcionalidades de mapas, GPS, cameras, IA, RTSP e ESP32.

## Evidencias do log #176

- Verificacao preventiva aprovada.
- `flutter analyze`: `No issues found!`.
- `flutter test`: 388 testes aprovados e 1 falha no cancelamento do seletor, antes do APK.
- Compilacao Android nao executada nessa tentativa.

## Validacao necessaria

- `tool/verify_project.sh` local, `flutter analyze` e `flutter test` em ambiente com SDK e build APK no GitHub Actions.
- Testar em aparelho real botao Voltar, toque fora do painel e selecao dos quatro modos.
- Nao inclui a futura gravacao de percurso com tela apagada, recuperacao de trilhas ou marcador direcional de bicicleta.
