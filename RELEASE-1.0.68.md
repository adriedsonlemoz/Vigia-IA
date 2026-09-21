# Vigia IA 1.0.68+68 — Correção do build

Esta entrega corrige o erro de `flutter analyze` da versão 1.0.67+67 sem retirar as melhorias de IA, áudio integrado e tela inteira.

## Correções

- Worker da IA agora mantém uma referência não nula ao detector ativo durante inferência e troca automática de modelo.
- Regras Inteligentes comparam `observationWindow` corretamente com `absenceReset`.
- Import não utilizado e avisos de estilo/null-aware foram removidos para manter o analisador limpo.

## Validação esperada

Execute `bash tool/verify_project.sh`, `flutter analyze`, `flutter test` e o build Android no workflow. O build assinado depende do Android SDK/keystore configurados no GitHub Actions.
