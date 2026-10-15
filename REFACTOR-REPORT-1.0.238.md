# Relatório técnico de refatoração — Vigia IA 1.0.238+238

Data: 2026-10-15. Base: código-fonte completo 1.0.237+237 (ZIP de 811 arquivos, CRC válido).

## Escopo e decisão

Foi isolado **somente** o componente visual de gravação em linha no banner de navegação, mantendo a granularidade pequena desta etapa. A barra inferior separada (`_RouteButtonBar`) e seu cronômetro (`_LiveRouteElapsedPill`, que usa timer de 1 segundo) foram deixados no arquivo principal; mover o timer nesta etapa aumentaria o risco sem benefício direto demonstrado.

- **Antes:** `lib/screens/map_monitoring_screen.dart`, classe privada `_NavigationRecordControl`.
- **Depois:** `lib/widgets/map_navigation_record_control.dart`, classe pública `MapNavigationRecordControl`.
- **Tela principal:** 10.843 → **10.772 linhas** (71 linhas originais extraídas, redução líquida de 71, considerando novo import e limites entre classes).
- **Código transposto:** 71 linhas; comparado à base byte a byte após a única renomeação da classe/construtor. SHA-256 normalizado: `077cf1d261036db3bc234c1e75aa1022cb29193eef8ede764d048b24cf323a42`.
- **Pontos de uso:** os dois banners (normal e dockado) passam os mesmos argumentos, com as ações provenientes do estado original.

## Garantias preservadas

- Iniciar a gravação só é clicável com GPS disponível; a ausência de GPS continua exibida ao usuário.
- Gravação em andamento expõe Pausar ou Retomar conforme o estado; menu Encerrar permanece separado de Exportar GPX.
- Exportar GPX só é apresentado no menu quando a rota tem dados suficientes, por meio do `hasRoute` já calculado pela tela.
- Sem nova instância de `MapRouteService`, permissão, acesso de rede, persistência, listener, ciclo de vida, `Timer` ou estado duplicado.
- O mapa, o módulo 3D, as rotas offline, câmeras, rádio, sensores e módulos de IA não receberam alterações funcionais.

## Testes e infraestrutura

- Antes da alteração, `tool/verify_project.sh` passou na 1.0.237+237.
- Após a alteração, `tool/verify_project.sh` passou com **36 testes Python**, além dos contratos históricos e **20 novos contratos** em `tool/check_map_refactor_238.py`.
- Verificador legado 1.0.214 de gravação inline foi redirecionado para conferir a nova classe **e os dois pontos de integração**, sem apagar sua garantia.
- Criados **7 testes Flutter** em `test/map_navigation_record_control_test.dart` (GPS sem fix, início, pausa, retomada, encerrar, exportação e ausência de opção GPX sem rota).
- Versionamento `1.0.238+238`/Android `versionCode 238` sincronizado com `pubspec.yaml`, `AppMetadata`, `app_identity.json`, `github-manager.json`, catálogo Novidades, duas seções Sobre/Mudanças, README, CHANGELOG, RELEASE, ARCHITECTURE, VALIDATION, User-Agents e gate.
- Verificações adicionais: transposição literal conferida em comparação com ZIP anterior; **10 XML, 2 JSON, 3 YAML** válidos; `bash -n` e verificações de imports e versão passaram.

## Limitações e sequência de validação

**Flutter e Android SDK não instalados neste ambiente.** Os sete testes Flutter novos foram escritos, mas **não foram executados**. Não foi possível executar `flutter analyze --fatal-infos --fatal-warnings`, `flutter test` ou `flutter build apk`. O sucesso dos verificadores Python não demonstra que o APK compila nem que o layout foi testado em dispositivo.

No GitHub Actions, confirmar primeiro o analyzer, os testes completos e o APK assinado ou debug. Em aparelho, verificar GPS ausente/ativo, começar e parar gravação, pausar/retomar, exportar GPX, alternar painel dockado/expandido, sistema offline e escalas de texto. Medir bateria separadamente, sem presumir economia de energia nesta extração.

## Bugs

Nenhum bug funcional novo foi reproduzido nem corrigido nesta etapa. Apenas foi atualizada a checagem preventiva da classe após a transposição. Os backups anteriores devem ser mantidos.
