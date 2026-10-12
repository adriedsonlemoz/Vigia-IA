# Vigia IA 1.0.222+222

## Estabilização e prevenção de regressões

- Pipeline GitHub Actions agora executa Flutter analyze e testes Dart **antes** de exigir a keystore de assinatura; falhas no código são diagnosticadas mesmo com Secrets ausentes.
- Download dos modelos TFLite deslocado para depois de `flutter analyze`, reduzindo trabalho desperdiçado quando a análise falha.
- Validação local de destinos de imports/exports/parts e contrato dos gates CI (`tool/check_import_targets.py`, `tool/check_ci_contract.py`).
- O empacotamento só aceita APKs cuja identificação e versão no `output-metadata.json` correspondam ao release solicitado.
- Dez testes Python de infraestrutura, incluindo injeção de falhas para garantir que os verificadores reprovem alterações perigosas.
- Teste Dart de regressão para amostra GPS com idade de 2 minutos e precisão de 7 m.
- Versionamento do aplicativo e referências internas sincronizados para `1.0.222+222`.

**Limitações:** Sem SDK Flutter/Dart/Android disponível neste ambiente, não foram executados `flutter analyze`, `flutter test`, Gradle nem testes em aparelho. Os checadores Python são parciais e não garantem compilação. A 1.0.221 não teve sucesso definitivo do workflow #185 comprovado pelos arquivos anexados.

**Próximos critérios:** aprovação do GitHub Actions para esta versão, APK assinado e instalado, regressões GPS/UI e medição de bateria em dispositivo. Próxima versão planejada: 1.0.223, confiabilidade de telemetria e apresentação de leituras antigas.
