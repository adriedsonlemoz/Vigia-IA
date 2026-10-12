# Vigia IA — Relatório técnico da versão 1.0.222+222

**Data:** 12/10/2026  
**Base examinada:** `VigiaIA-1.0.221-source.zip` e `Relatorio-Auditoria-Vigia-IA-1.0.221.md`.  
**Escopo:** estabilização de integração contínua e guardas de regressão, sem mudança de comportamento dos módulos operacionais.

## 1. Estado real da base

- ZIP original íntegro para extração: 732 arquivos; 244 arquivos `.dart` em `lib`, 111 arquivos `.dart` em `test`.
- `lib/screens/map_monitoring_screen.dart` tem **11.424 linhas**; não foi modificado nesta versão.
- A versão original é `1.0.221+221`, com `app_identity.json`, `github-manager.json`, `lib/core/app_metadata.dart` e tela Sobre sincronizados.
- O `bash tool/verify_project.sh` original **passou**; isso não é prova de Flutter analyze/test/build.
- Os modelos `.tflite` no ZIP são placeholders de 23 bytes; o workflow baixa modelos reais de terceiros para teste/build, portanto conexão de rede e os downloads são dependências do CI.
- `pubspec.lock` **não foi incluído no ZIP original**; versões de dependências transitivas podem variar entre builds enquanto não houver lockfile gerado/validado. Não criamos lockfile fictício.
- SDK Flutter/Dart/Android Gradle não estavam instalados no ambiente de validação. O ambiente de execução também não conseguiu resolver `storage.googleapis.com`; não houve download de ferramentas/modelos.
- Não há nos anexos log final de sucesso nem APK do workflow Android APK #185 para a 1.0.221. Uma busca limitada por repositório não identificou de forma verificável a execução correspondente. **Sucesso do build original não está comprovado**.

## 2. Comparação da auditoria com as implementações

| Diagnóstico | Evidência conferida | Situação na 1.0.222 |
|---|---|---|
| GPS antigo versus precisão recente | `MapTelemetryPolicy.freshReadingWindow` = 20 s; qualidade identifica `stale`, mas o HUD exige auditoria específica | Teste de regressão para fix de 2 minutos/7 m acrescentado, sem alterar apresentação no HUD |
| Título incorreto de localidades | `_bestTitle` privilegia `amenity/shop/tourism/city/town/...` em vez de nome canônico; `_dedupeAndSort` ordena depois por distância | Confirmado, adiado à 1.0.224 |
| POIs sem evidência de serviço | `_showPoiDetails` usa `expand: true` e exibe painel mesmo com metadados incompletos | Confirmado, previsto 1.0.225/226 |
| Psi mínimo universal | `BikeSensorSnapshot.minimumTirePressurePsi = 30` e UI usa fallback 30 | Confirmado, previsto 1.0.228 |
| Arquitetura concentrada | Tela do mapa 11.424 linhas | Confirmado, refatoração incremental após estabilidade |
| Checkers não substituem analyze | Original tem muitos testes textuais por `grep`; o CI possui `flutter analyze`/`flutter test`, mas só executados no GitHub | Corrigida ordem de gates; adicionados testes de infraestrutura |

Não foram vistas divergências de contagem com o relatório; as constatações de interface vistas anteriormente nas capturas não foram revalidadas em dispositivo nesta entrega.

## 3. Mudanças implementadas

1. `tool/check_import_targets.py` varre imports, exports e parts com caminho local no código de `lib`, `test` e `integration_test`; não tenta validar símbolos Dart ou dependências externas.
2. `tool/check_ci_contract.py` verifica sequência dos gates de CI, ferramentas fixadas, coerência Gradle, assinatura antes do release e verificação de identidade/versão de APKs.
3. `tool/test_stabilization_contracts.py` executa **10 testes Python**, incluindo mutações simuladas que devem reprovar um pipeline com analisador/testes ausentes, assinatura precoce, Gradle divergente, assinatura não verificada, metadata de APK não checada e imports locais quebrados.
4. `tool/verify_project.sh` executa as checagens adicionais e só imprime sucesso após todas terminarem.
5. Workflow: `flutter pub get` → verificação preventiva → `flutter analyze --fatal-infos --fatal-warnings` → download de modelos → `flutter test --reporter expanded --coverage` → preparação da assinatura → build release → validação das APKs → publicação. Assim, uma ausência de Secrets não impede diagnosticar analyze/test antes da etapa release.
6. O passo de cópia das APKs recusa `applicationId`, `versionName` ou `versionCode` divergentes do pacote solicitado.
7. Adicionado teste Dart de regressão em `test/map_telemetry_policy_test.dart`: amostra de 2 min/7 m deve ser classificada como antiga.
8. Atualizados versionamento para **1.0.222+222**, notas de mudanças, versões do Android no metadata gerado, User-Agents, README, arquitetura, tela Sobre/Mudanças e catálogo Novidades. O relatório original foi copiado para `docs/` e criado backlog com critérios de aceitação.

## 4. Verificações executadas

| Verificação | Resultado |
|---|---|
| `bash tool/verify_project.sh` (1.0.221 original) | **Passou** |
| `bash tool/verify_project.sh` (1.0.222 final) | **Passou** |
| `python3 tool/check_version_sync.py` | **Passou**, 1.0.222+222 |
| `python3 tool/check_import_targets.py` | **Passou**, destinos locais identificáveis existem |
| `python3 tool/check_ci_contract.py` | **Passou**, portas de CI em ordem |
| `python3 -m unittest discover -s tool -p 'test_*.py' -v` | **10/10 passaram** |
| `python3 -m compileall -q tool` | **Passou** |
| Parsing YAML do workflow com PyYAML/BaseLoader | **Passou**; 19 etapas, `on` presente |
| Parsing/sintaxe das 2 rotinas Python embutidas no workflow | **Passou** |
| `flutter analyze` | **Não executado**, Flutter SDK ausente |
| `flutter test` | **Não executado**, Flutter SDK ausente |
| `gradle :app:assembleRelease` | **Não executado**, Android SDK/Gradle ausentes |
| APK assinado e instalado no dispositivo | **Não executado**, nenhum APK gerado aqui |

**Atenção:** mesmo 10/10 testes Python aprovados não garantem que o novo teste Dart compile nem que o Android execute corretamente. São checkers parciais, intencionalmente.

## 5. Riscos e sequência recomendada

**Bloqueio de aprovação do release:** rodar o workflow Android APK sobre a exata versão 1.0.222, conferir que `flutter analyze`, `flutter test`, `:app:assembleRelease` e validação `apksigner` terminem com sucesso; instalar APK e observar startup, mapas, rádio, navegação e permissões em Android real.

**Risco de reprodutibilidade:** o `pubspec.lock` está ausente; obter por `flutter pub get` com SDK pinado, revisar diferenças e incluí-lo em uma próxima atualização depois da validação da cadeia de dependências.

**Risco de compatibilidade AGP:** código usa AGP 9.0.1, Gradle 9.1.0 e Flutter 3.44.9; existem `android.newDsl=false` e `android.builtInKotlin=false` no `android/gradle.properties`, configuração temporária documentada pelo Flutter para AGP 9. Compilação real não verificada. Documentação: https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers .

**Vigência de dados e UI:** preparar a 1.0.223 com teste widget para sensores antigos e HUD; depois buscar títulos/relevância na 1.0.224, pontos úteis confiáveis na 1.0.225, HUD adaptativo na 1.0.226 e demais etapas conforme `BACKLOG-ESTABILIZACAO-1.0.222.md`.
