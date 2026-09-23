# Vigia IA — Regras obrigatórias do projeto

Estas regras valem para qualquer correção, melhoria, refatoração, buildfix ou entrega.

## Versionamento obrigatório

- Nunca entregar uma nova modificação usando a mesma versão da entrega anterior.
- Toda entrega nova incrementa a versão pública e o build, inclusive correções pequenas.
- Sequência esperada: `1.0.49+49` → `1.0.50+50` → `1.0.51+51` → `1.0.52+52` → `1.0.53+53` → `1.0.54+54` → `1.0.55+55` → `1.0.56+56` → `1.0.57+57` → `1.0.58+58` → `1.0.59+59` → `1.0.60+60` → `1.0.61+61` → `1.0.62+62` → `1.0.63+63` → `1.0.64+64` → `1.0.65+65` → `1.0.66+66` → `1.0.67+67` → `1.0.68+68` → `1.0.69+69` → `1.0.70+70` → `1.0.71+71` → `1.0.72+72` → `1.0.73+73` → `1.0.74+74` → `1.0.75+75` → `1.0.76+76` → `1.0.77+77` → `1.0.78+78` → `1.0.79+79` → `1.0.80+80` → `1.0.81+81` → `1.0.82+82` → `1.0.83+83` → `1.0.84+84` → `1.0.85+85` → `1.0.86+86` → `1.0.87+87` → `1.0.88+88` → `1.0.89+89` → `1.0.90+90` → `1.0.91+91` → `1.0.92+92`.
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
