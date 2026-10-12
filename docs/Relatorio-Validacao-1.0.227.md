# Vigia IA 1.0.227+227 — Diagnóstico e correção do workflow Android APK #188

**Data:** 12/10/2026  
**Base de correção:** `VigiaIA-v1.0.226+226-source.zip`  
**Log analisado:** `Vigia-IA-Android-APK-188-logs.zip`  
**Nova entrega:** código-fonte completo 1.0.227+227, versionCode 227.

## Resultado do workflow #188

O GitHub Actions executou a versão **1.0.226+226**, com Flutter **3.44.9** e JDK 17:

- `bash tool/verify_project.sh`: **aprovado, 25 testes Python**.
- `flutter analyze --fatal-infos --fatal-warnings`: **aprovado**, `No issues found!` (14,3 s).
- `flutter test --reporter expanded --coverage`: **429 testes aprovados e 1 falhou**. O teste com falha foi `test/map_poi_details_sheet_test.dart`, caso `ficha sem metadados exibe origem e aviso de serviço não verificado`.
- Exceções Flutter: `RenderFlex overflowed by 60 pixels on the right` e `RenderFlex overflowed by 35 pixels on the right`, ambas geradas em `lib/widgets/map_poi_details_sheet.dart:360`, `_InfoPill` (`Row`/`Text` sem restrição flexível).
- O teste chamava `tester.takeException()` e encontrou dois overflows. Os passos Android/Gradle, assinatura e geração dos APKs **não foram executados**.

**Causa:** `Wrap` limita a largura disponível da etiqueta, mas o `Text` era um filho sem flexibilidade no `Row`, tentando ocupar sua largura natural e ultrapassando as restrições de layout. Trata-se de falha de interface, não erro da asserção do teste nem do gerador de APK.

## Correção efetiva

1. `_InfoPill` em `lib/widgets/map_poi_details_sheet.dart` usa `Flexible(child: Text(..., softWrap: true))`, conservando o texto completo e permitindo múltiplas linhas.
2. Rodapé preserva `onShowOnMap` e `onNavigate`, mas organiza as duas ações verticalmente quando a largura interna é menor que 310 dp ou o texto ultrapassa escala de 1,3x; nas demais dimensões continua em linha.
3. Novo teste de widget com **320/360/412 dp e texto 1,0x/1,5x**, cobrindo exatamente os rótulos afetados e eventuais outras exceções de layout.
4. `tool/check_build188_poi_layout.py` e `tool/test_build188_poi_layout.py` introduzem **quatro testes Python**, incluindo mutações que removem a flexibilidade, a responsividade e cenários de tela pequena; o gate passou a rodar em `tool/verify_project.sh`.
5. Versionamento, AppMetadata, `pubspec.yaml`, `app_identity.json`, `github-manager.json`, User-Agents, tela Mudanças, pop-up Novidades, README, CHANGELOG, ARCHITECTURE, VALIDATION, release notes e verificadores sincronizados.
6. Câmeras, IA local, rádio, ESP32, modelos e demais módulos existentes preservados, sem alterações nas permissões Android, serviços, armazenamento ou esquema de dados.

## Verificações realmente executadas neste ambiente

| Verificação | Resultado |
|---|---|
| `bash tool/verify_project.sh` | **Aprovado** |
| Testes Python (`tool/test_*.py`) | **29/29 aprovados**, 4 novos do #188 |
| `python3 tool/check_version_sync.py` | **Aprovado**, versão 1.0.227+227 |
| Checagens do layout #188 | **Aprovadas estruturalmente** |
| `python3 -m compileall -q tool` | **Aprovado** |
| Workflow YAML | **Validado por parser YAML** |
| JSON no projeto | **2 arquivos válidos** |
| XML no projeto | **10 arquivos válidos** |
| Arquivos de base removidos | **Nenhum** |
| `flutter analyze` na versão 1.0.227 | **NÃO executado localmente**: SDK Flutter ausente |
| `flutter test`/widget test na versão 1.0.227 | **NÃO executado localmente**: SDK Flutter ausente |
| APK/Gradle/assinatura | **NÃO executados localmente**: SDK Android/Flutter ausente |
| Teste no aparelho | **Pendente de CI totalmente aprovado** |

**Limitação:** uma checagem textual de `Flexible` não comprova que o renderizador Flutter deixará de acusar overflow. O teste widget adicionado e a suíte completa precisam rodar no CI, assim como o APK.

## Arquivos modificados em relação à 1.0.226

- `ARCHITECTURE.md`
- `BACKLOG-ESTABILIZACAO-1.0.222.md`
- `CHANGELOG.md`
- `README.md`
- `VALIDATION.md`
- `app_identity.json`
- `github-manager.json`
- `lib/core/app_metadata.dart`
- `lib/screens/app_info_screen_components.dart`
- `lib/services/map_cycling_route_service.dart`
- `lib/services/map_destination_search_service.dart`
- `lib/services/map_weather_service.dart`
- `lib/services/offline_map_service.dart`
- `lib/services/route_explorer_service.dart`
- `lib/services/update_news_catalog.dart`
- `lib/widgets/map_navigation_3d_view.dart`
- `lib/widgets/map_poi_details_sheet.dart`
- `pubspec.yaml`
- `test/app_metadata_test.dart`
- `test/map_poi_details_sheet_test.dart`
- `tool/check_map_radio_219.py`
- `tool/verify_project.sh`

## Novos arquivos

- `RELEASE-1.0.227.md`
- `tool/check_build188_poi_layout.py`
- `tool/test_build188_poi_layout.py`

## Próxima prioridade

Publicar o código-fonte **1.0.227+227** no repositório correto e executar o workflow. Exigir aprovação do `flutter analyze`, `flutter test`, Gradle e APK assinado antes da instalação. A reorganização global do HUD foi deslocada para **1.0.228+** para isolar a correção.
