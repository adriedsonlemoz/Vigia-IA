# Relatório técnico — Vigia IA 1.0.236+236

Data: 2026-10-15. Base: `VigiaIA-v1.0.235-235-source.zip`. Escopo: somente seletor visual de alternativas de navegação e correção pontual em verificações preventivas.

## 1. Responsabilidade extraída

- Código original: `_RouteAlternativesButton`, membro passivo `StatelessWidget` da tela de mapa.
- Destino: `lib/widgets/map_route_alternatives_button.dart`, classe pública `MapRouteAlternativesButton`, 116 linhas totais.
- **Linhas do arquivo principal:** 11.066 antes, **10.957 depois**; **109 linhas originais extraídas**. A redução líquida coincide com as linhas deslocadas porque houve um import adicional e a eliminação do separador entre classes.
- Interface pública: lista de rotas, índice selecionado, cores, versão compacta, callbacks de formatar distância/tempo/diferença e `onSelected`; sem novos controladores ou dependências de tela/estado.
- Corpo visual comparado por hash SHA-256 após renomear o identificador público: `6f52155e3ed30aaf39943c4f9e8fefc98930a57449cd4b83fb4646c30b207fb3`.

## 2. Segurança e compatibilidade

- O menu conserva os ícones de seleção, o número de alternativas, textos, constrangimentos de tamanho, `PopupMenuPosition.over`, desabilitação em rota única e callback com o índice.
- GPS, câmera, IA local, rádio, Bike, ESP32, bancos, preferências, MBTiles, gravação, cálculo de roteamento, schema e permissões não foram modificados.
- Nenhum novo `State`, `Timer`, `addListener`, `StreamSubscription`, inicialização de rede ou outro consumidor de bateria foi adicionado.

## 3. Bugs e verificadores

- Nenhum bug funcional de navegação demonstrado ou alterado. Bug confirmado de ferramenta: `tool/check_map_radio_219.py` comparava com `1.0.235+234`, valor inconsistente com a versão válida 1.0.235+235. A checagem foi tornada dinâmica em relação ao padrão versão/build e reintegrada à execução do gate.
- Verificações históricas dos recursos 137 e 199 atualizadas para procurar o botão no novo arquivo, conferindo também a integração com `_NavigationBanner`.
- Arquivo novo `tool/check_map_refactor_236.py` verifica integridade de transposição e contratos; `test/map_route_alternatives_button_test.dart` contém cinco testes de widget.

## 4. Validação

- `tool/verify_project.sh`: **aprovado**, com **36 testes Python**; contratos 1.0.233 (18), 1.0.234 (16), 1.0.235 (14) e 1.0.236 (**17**) passaram. Verificador `tool/check_map_radio_219.py` corrigido e reativado passou. Checagens de imports locais, CI e catálogo de áudio incluídas no gate.
- Sintaxe: **2 JSON**, **10 XML**, **3 YAML** válidos; scripts Python analisados por `ast.parse`; versionamento e Gradle `flutter.versionCode`/`flutter.versionName` sincronizados. Integridade ZIP verificada após empacotamento: **806 arquivos e CRC integral aprovado**.
- Pendentes: `flutter analyze --fatal-infos --fatal-warnings`, `flutter test`, APK/Android e teste físico. Flutter/Android SDK indisponível no ambiente local.

## 5. Próxima etapa

Após aprovação de CI e teste físico, considerar extração de `_NavigationMetricCell` e `_NavigationPoiChip` em um agrupamento coeso de elementos visuais de navegação. Não mover estado ou áudio/GPS sem cobertura de integração e medição de consumo.
