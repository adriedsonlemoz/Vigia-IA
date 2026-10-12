# Vigia IA — Release 1.0.224+224

Data: 12/10/2026 · versionCode 224

## Alterações

- Correção dos títulos de resultados da pesquisa de cidades e localidades, inclusive cache herdado.
- Ordenação por nome/relevância com preferência regional suave (não impede destinos distantes).
- Agrupamento em correspondências, locais salvos, recentes, região e lugares distantes.
- Deduplicação de identificadores OSM e coordenadas muito próximas, preservando homônimos distantes.
- Busca digitada permanece inteiramente local. Nominatim só é usado após envio explícito; uso de viewbox aproximada, intervalo mínimo e cache da sessão.
- Novos testes unitários Dart de relevância, títulos e deduplicação; sem alteração intencional em rádio, câmeras, IA, sensores, gravação e mapas offline.

## Validação

Executar `bash tool/verify_project.sh`, `flutter analyze --fatal-infos --fatal-warnings`, `flutter test` e build Android em CI. O SDK Flutter/Android não está disponível nesta sessão. A validação manual está agrupada com a 1.0.225.

## Limites

A presença de um local no OSM não comprova disponibilidade nem funcionamento; distância da pesquisa é geodésica em linha reta, não distância por rota. Não há serviço Nominatim pago nem infraestrutura própria: tráfego agregado do serviço público depende do cumprimento da política da OSMF. O cache de consultas exatas de 1 hora é apenas da sessão e não garante funcionamento offline para todo destino do mundo; locais já conhecidos e salvos estão disponíveis no índice local.
