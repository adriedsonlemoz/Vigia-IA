# Vigia IA — Release 1.0.231+231

Data: 12/10/2026 · versionCode 231 · quarta versão do ciclo de estabilização anterior à refatoração gradual

## Novidades

- Mapa offline diferencia cobertura desconhecida, área fora do pacote e zoom acima da faixa de detalhe; não considera a caixa geográfica de um trajeto como cobertura integral do MBTiles.
- Gestor de mapas informa as limitações de MBTiles antigos sem área conhecida e de corredores importados/baixados.
- Monitor de rede diminui a frequência de sondagens enquanto offline, retornando à frequência normal quando a conexão é recuperada.
- A rota viária conhecida permanece visível e não dispara consulta duplicada de DNS quando não há internet.

## Compatibilidade e limitações

- Não altera o formato de pacotes MBTiles, permissões Android, esquemas ou dependências.
- Sem rede, rotas salvas são exibidas; **não há cálculo/recalculo viário offline autônomo**.
- Para corredores MBTiles, o retângulo de limites é apenas metadado geográfico, não prova de presença de todos os tiles.
- Requer validação pelo GitHub Actions de Flutter Analyze, Dart tests e assemble Android; teste acumulado em celular é o próximo marco, antes de 1.0.232+.
