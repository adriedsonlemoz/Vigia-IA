# Relatório técnico — Vigia IA 1.0.234+234

Data: 2026-10-15. Fonte original: `VigiaIA-v1.0.233-233-source.zip`, mantido separado da entrega.

## Auditoria e delimitação

O arquivo `lib/screens/map_monitoring_screen.dart` continha 11.508 linhas e combinava a composição da tela com estado, navegação, GPS, camadas de mapa e callbacks. A etapa 1 (1.0.233) já havia extraído indicadores de sistema e controles de zoom. Na etapa 2, priorizou-se somente a faixa de telemetria de cinco cartões e seu componente de renderização. A faixa é `StatelessWidget`: não cria estado, temporizadores, listeners, serviços ou recursos de rede; os dados são fornecidos pela tela existente.

## Extração concluída

| Item | Linhas originais deslocadas | Novo arquivo |
| --- | ---: | --- |
| `_MapTelemetryStrip` → `MapTelemetryStrip` (faixa de velocidade, altitude, bússola, GPS e clima) | 168 | `lib/widgets/map_telemetry_strip.dart` |
| `_MapTelemetryCard` (cartão interno privado) | 114 | `lib/widgets/map_telemetry_strip.dart` |
| **Total** | **282** | **290 linhas com imports e comentário de ownership** |

**Arquivo principal:** 11.508 → 11.227 linhas, redução líquida de 281 devido ao novo import. **Foram movidas 282 linhas**, não descartadas. Um SHA-256 do trecho de classes normalizado, comparado com a base original 1.0.233, confirmou transposição exata; só o prefixo privado foi removido do nome da faixa, para permitir import por outra biblioteca. `_MapTelemetryCard` permanece privado.

### Integração

- Um único `MapTelemetryStrip(...)` substituiu o `_MapTelemetryStrip(...)` existente. Foram preservados os cinco inputs e callbacks, valores ausentes, indicação de GPS envelhecido, política de clima atual, tooltips, cores, tamanhos e versões compacta/expandida.
- Nenhuma classe duplicada, dependência circular, nova instância de serviço, novo listener nem alteração de lifecycle foram introduzidos.
- `map_monitoring_offline_support.dart` continua `part` do arquivo principal: o gerenciamento offline permanece intacto nesta etapa.
- Não houve alteração de schemas de dados, nomes de chaves, permissões, configuração de mapas, gravação de trajetos, câmeras, rádios, áudio, IA, módulos Bike/ESP32 e notificações.
- O controle de versão Android herda `flutter.versionName` e `flutter.versionCode` de `pubspec.yaml`, agora `1.0.234+234`.

## Testes e bugs

- `tool/verify_project.sh`: **aprovado**, com **36 testes Python** internos e validadores legados.
- `tool/check_map_refactor_233.py`: **18 contratos aprovados**, preservando a etapa anterior.
- `tool/check_map_refactor_234.py`: **16 contratos aprovados**, cobrindo hash de transposição, import, chamada única, cards, callbacks, stale GPS/clima, ausência de estado e integração.
- `tool/check_version_sync.py`: **aprovado**, incluindo metadados, catálogo Novidades e histórico de Sobre.
- Novo `test/map_telemetry_strip_test.dart`: **5 casos Flutter escritos, não executados**: valores e fontes, callbacks, GPS antigo, clima antigo e layout compacto.
- **Bugs funcionais comprovados:** nenhum nesta etapa. Três verificações legadas procuravam texto de componentes no arquivo antigo; foram **corrigidos os caminhos das verificações** para consultar o novo módulo e a montagem na tela, sem desativar testes.

**Limitação de execução:** Flutter SDK e Android SDK indisponíveis neste ambiente. `flutter analyze --fatal-infos --fatal-warnings`, `flutter test` (incluindo os cinco novos casos), Gradle/APK e testes de dispositivo **não executados**. A aprovação preventiva não atesta compilação nem ausência de regressões de layout.

## Critérios para próxima etapa

1. Executar o workflow Android e analisar o resultado da versão 1.0.234 antes de nova extração.
2. Comparar em dispositivo os cinco cartões em modos compacto/expandido, GPS atual/antigo, clima online/ESP32, orientação e retorno à tela, sem disparos desnecessários em segundo plano.
3. Versão 1.0.235, se os testes acima forem satisfatórios: auditar um cartão de informações de rota ou outro widget passivo e extrair apenas uma responsabilidade; evitar alterar controladores e subscrições sem testes de ciclo de vida.
4. Medir consumo com método repetível antes de atribuir qualquer ganho de bateria.
