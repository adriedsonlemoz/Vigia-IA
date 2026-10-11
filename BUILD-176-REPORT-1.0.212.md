# Relatorio de correção do build 176 — Vigia IA 1.0.212+212

## Diagnostico comprovado

O workflow `Android APK #176` executou com sucesso a verificacao preventiva de metadados e `flutter analyze` (`No issues found!`). Nos testes: `+388 -1`. O unico caso que falhou foi `cancelamento do seletor nao altera o modo` em `test/map_workspace_mode_test.dart` linha 58.

Erro: `Expected exactly one matching candidate; Found 0 widgets with type CupertinoNavigationBarBackButton`, originado pelo `tester.pageBack()` da propria suite de testes. O app usa `showModalBottomSheet`; esta rota nao tem botao de voltar de AppBar. Nao ha evidencias neste log de falha de compilacao Dart, de Gradle ou de execucao do GPS.

## Correcoes

1. Substituido `tester.pageBack()` por `tester.binding.handlePopRoute()` para acionar o comportamento de Voltar do Android em teste de widget e verificar se o painel desapareceu e nao houve nova selecao.
2. Adicionado teste para cancelar via toque fora da folha, verificando fechamento sem mudar modo.
3. Adicionada verificacao de regressao no validador local, impedindo a reintroducao de `tester.pageBack()` nesse arquivo.
4. Versionamento e documentacao atualizados para `1.0.212+212`, preservando o restante do app e seus modulos.

## Limites

A 1.0.212 e um buildfix: nao implementa GPS com tela apagada, salvamento/reconstrucao de trajetos nem troca do marcador de posicao. Estes recursos devem ser trabalhados numa versao posterior. A passagem no CI depende de `flutter analyze`, `flutter test` e compilacao APK, que exigem os SDKs Flutter/Android. A versao 1.0.211 foi analisada no CI, mas este pacote atualizado ainda precisa ser revalidado.
