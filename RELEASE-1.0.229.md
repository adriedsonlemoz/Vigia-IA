# Vigia IA — Release 1.0.229+229

Data: 12/10/2026 · versionCode 229 · segunda versão do ciclo de quatro

## Entrega

- Prévia compara alternativas por distância e tempo; bicicleta calcula tempo com o ritmo salvo e permite editar velocidade sem repetir obrigatoriamente o diálogo em cada consulta.
- Sem dados de relevo, qualidade ou risco das vias disponíveis no modelo atual, a interface não apresenta valores inventados.
- Paradas diárias próximas à rota são medidas pelo segmento e não apenas pelo vértice da geometria, com afastamento em linha reta e aviso de acesso/serviços não verificados.
- Paradas geométricas continuam quando não há localidades adequadas, sem inventar estabelecimentos de apoio.
- Visualizar a rota não inicia navegação, gravação nem TTS. Apenas o botão Iniciar aciona navegação; `SavedBikeRouteService` mantém schema 1 para última rota.

## Limitações e validação

- Checagens preventivas Python/ZIP: ver relatório da versão.
- Testes Flutter Dart adicionados; `flutter analyze`, `flutter test`, compilação Gradle e instalação Android aguardam CI/aparelho, SDK ausente localmente.
- O acesso viário das localidades requer roteamento de desvio real ainda não implementado, e nenhum serviço mapeado é considerado aberto sem confirmação.
- Teste manual combinado continua na 1.0.231, após revisar rádio/Bike (230) e offline/autonomia (231).
