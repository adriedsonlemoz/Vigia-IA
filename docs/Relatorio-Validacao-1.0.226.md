# Vigia IA 1.0.226+226 — Correção Android APK #187

**Data:** 12/10/2026  
**Origem:** `VigiaIA-v1.0.225+225-source.zip`  
**Logs analisados:** `Vigia-IA-Android-APK-187-logs.zip`  
**Entrega:** código-fonte integral 1.0.226+226 (`versionCode 226`)

## Diagnóstico baseado nos logs reais

O workflow #187 executou Flutter 3.44.9 em Ubuntu/JDK 17, fez `flutter pub get` e passou em `bash tool/verify_project.sh`. O próprio log de verificação informa `Versionamento sincronizado: 1.0.224+224`: portanto o GitHub Actions analisou código mais antigo que o ZIP mais recente enviado (1.0.225). Isso **não** demonstra que o ZIP 1.0.225 tenha sido compilado ou testado no CI.

A etapa `flutter analyze --fatal-infos --fatal-warnings` encerrou com exit code 1, apresentando **3 infos** `curly_braces_in_flow_control_structures`:

1. `lib/screens/map_monitoring_screen.dart:1415` (bússola, guarda de leitura recente).
2. `lib/services/map_destination_ranking.dart:52` (migração do título em cache).
3. `lib/services/map_destination_ranking.dart:174` (identificador de OSM).

Depois da falha, `flutter test`, execução Gradle, montagem, assinatura e publicação do APK **não ocorreram**. O upload sem `coverage/lcov.info` é consequência da interrupção antes dos testes, não um defeito independente. Avisos sobre Node.js/punycode não causaram o erro principal.

## Correções

- Encerramento de cada uma das três condições em um bloco `{ ... }` com o mesmo retorno anterior, sem alterar suas condições ou efeitos.
- `tool/check_build187_lints.py` inspeciona as três guardas afetadas antes do analisador, para rejeitar a forma que falhou no #187.
- `tool/test_build187_lints.py` testa a implementação e reproduz as formas com chaves removidas/guarda ausente. São **3 testes novos**.
- Versão, build, metadados GitHub Manager, User-Agent, tela de Mudanças, Novidades, README, CHANGELOG, ARCHITECTURE, VALIDATION, AGENTS e notas do release preservadas/sincronizadas onde aplicável.
- Preservado o restante da versão 1.0.225, inclusive melhorias da versão 1.0.223 (GPS) e 1.0.224 (busca), e os módulos de câmeras/IA/ESP32/rádio.

## Verificação efetivamente executada

| Verificação | Resultado |
|---|---|
| `bash tool/verify_project.sh` | **Aprovado** |
| Testes Python preventivos | **25/25 aprovados**, incluindo os 3 novos |
| Guarda #187 com chaves | **3/3 verificadas estruturalmente** |
| `python3 -m compileall -q tool` | **Aprovado** |
| YAML workflow | **Válido** |
| JSON do projeto | **2 válidos** |
| XML do projeto | **10 válidos** |
| Integridade e paridade de arquivos ZIP | **Verificada** |
| `flutter analyze --fatal-infos --fatal-warnings` | **Não executado localmente**, SDK Flutter indisponível |
| `flutter test`, Gradle, APK e assinatura Android | **Não executados localmente**, SDK indisponível |
| Teste manual no celular | **Pendente de CI verde** |

**Limite:** o teste Python verifica uma classe específica do problema ocorrido, mas não reconhece todos os possíveis erros Dart; apenas o analyzer real confirma a análise integral. Não foi gerado APK.

## Arquivos alterados em relação à 1.0.225

- `ARCHITECTURE.md`
- `BACKLOG-ESTABILIZACAO-1.0.222.md`
- `CHANGELOG.md`
- `README.md`
- `VALIDATION.md`
- `app_identity.json`
- `github-manager.json`
- `lib/core/app_metadata.dart`
- `lib/screens/app_info_screen_components.dart`
- `lib/screens/map_monitoring_screen.dart`
- `lib/services/map_cycling_route_service.dart`
- `lib/services/map_destination_ranking.dart`
- `lib/services/map_destination_search_service.dart`
- `lib/services/map_weather_service.dart`
- `lib/services/offline_map_service.dart`
- `lib/services/route_explorer_service.dart`
- `lib/services/update_news_catalog.dart`
- `lib/widgets/map_navigation_3d_view.dart`
- `pubspec.yaml`
- `test/app_metadata_test.dart`
- `tool/check_map_radio_219.py`
- `tool/verify_project.sh`

## Arquivos adicionados

- `RELEASE-1.0.226.md`
- `tool/check_build187_lints.py`
- `tool/test_build187_lints.py`

Nenhum arquivo existente foi removido. Os documentos históricos de releases antigas continuam na origem.

## Próximas prioridades

1. Publicar/executar o workflow sobre **1.0.226+226**, confirmar a versão de checkout nos logs e exigir `flutter analyze` / `flutter test` / APK antes de testar no telefone. Se houver novos logs, corrigir na **1.0.227+227**.
2. Fazer o teste manual do ciclo acumulado quando houver APK válido, com GPS envelhecido, busca de Santo Antônio/Iguatama, modo avião, POIs, fonte e serviço não verificado.
3. Retomar refatoração incremental do HUD e diálogos a partir da **1.0.227**; o buildfix 226 deliberadamente não introduziu reorganização visual.
