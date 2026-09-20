# Vigia IA — Regras obrigatórias do projeto

Estas regras valem para qualquer correção, melhoria, refatoração, buildfix ou entrega.

## Versionamento obrigatório

- Nunca entregar uma nova modificação usando a mesma versão da entrega anterior.
- Toda entrega nova incrementa a versão pública e o build, inclusive correções pequenas.
- Sequência esperada: `1.0.49+49` → `1.0.50+50` → `1.0.51+51` → `1.0.52+52` → `1.0.53+53` → `1.0.54+54` → `1.0.55+55` → `1.0.56+56` → `1.0.57+57` → `1.0.58+58` → `1.0.59+59` → `1.0.60+60` → `1.0.61+61`.
- Nunca reutilizar uma versão que já tenha sido entregue em ZIP.

Antes do ZIP final, manter sincronizados:

- `pubspec.yaml`;
- `lib/core/app_metadata.dart`;
- `app_identity.json`;
- tela Sobre / Mudanças;
- `README.md`;
- `CHANGELOG.md`;
- `ARCHITECTURE.md`, quando aplicável;
- testes/verificadores de versão;
- nome do ZIP final.

## Validação obrigatória

Antes de entregar:

1. confirmar que a versão é maior que a última já entregue;
2. executar `tool/verify_project.sh`;
3. executar `flutter analyze`, quando o SDK estiver disponível;
4. executar `flutter test`, quando o SDK estiver disponível;
5. validar a integridade do ZIP;
6. não reintroduzir nomes antigos do aplicativo;
7. entregar o ZIP com link clicável.

Se Flutter/Android SDK não estiver disponível, declarar explicitamente que analyze/test/build ainda precisam ser confirmados pelo workflow.

## Identidade oficial

- Nome público: `Vigia IA`
- Nome técnico: `vigiaia`
- Package/applicationId: `com.vigiaia.app`
- Protocolo: `vigiaia://pair`

## Checagem final

Antes de responder com uma entrega, conferir:

> A versão foi incrementada? Todos os metadados estão sincronizados? O CHANGELOG foi atualizado? O ZIP foi validado e está linkado?

Se alguma resposta for não, corrigir antes de entregar.
