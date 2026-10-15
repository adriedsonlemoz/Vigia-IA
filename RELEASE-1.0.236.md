# Vigia IA 1.0.236+236

Data: 2026-10-15. Etapa 4 da refatoração incremental iniciada na 1.0.232.

## Escopo

- Alternativas de navegação agora apresentadas pelo widget independente `MapRouteAlternativesButton` (`lib/widgets/map_route_alternatives_button.dart`). A seleção, ordenação, distâncias, durações e comparações seguem fornecidas pela tela principal.
- 109 linhas originais de apresentação movidas. Arquivo principal: 11.066 → 10.957 linhas. Nenhuma mudança intencional de aparência, navegação ou funcionamento offline.
- Corrigido verificador legado mapa/rádio que esperava um build inexistente; gate preventivo atualizado para executá-lo.
- Cinco testes Flutter novos de interação e contratos estáticos de não regressão. Compilação e testes Flutter/Android ainda exigem CI.

## Compatibilidade

- Nenhuma alteração de schemas, permissões, dependências, preferências salvas, recursos de vídeo/IA/ESP32, gravação ou uso de GPS.
- Base funcional de referência 1.0.232 preservada, assim como as versões 1.0.233–235.
- versionName=1.0.236/versionCode=236 herdados do `pubspec.yaml` pelo Gradle Flutter.

## Verificações pendentes

- Flutter analyze com fatal-infos/fatal-warnings; Flutter test (incluindo widget novo); Gradle/APK; interação em aparelho.
- A aprovação dos testes Python não é garantia de compilação nem de autonomia medida.
