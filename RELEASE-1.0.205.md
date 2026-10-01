# Vigia IA 1.0.205+205

Melhorias do módulo de rádio online.

## Alterações

- **Player:** `MediaPlayer` substituído por Media3/ExoPlayer; HLS, redirecionamentos http/https, foco de áudio e wake lock tratados pelo ExoPlayer.
- **Tocando agora:** metadados ICY no painel, na notificação e na `MediaSession` (tela de bloqueio, sistema, fones).
- **Robustez:** reconexão automática, espera pela rede (`registerDefaultNetworkCallback`), vigia de conexão de 30 s e retomada ao vivo depois de pausas longas.
- **Playlists:** `.pls` e `.m3u` resolvidas por `RadioStreamResolver`.
- **Catálogo:** descoberta de servidores por DNS, filtro por verificação de saúde do catálogo, contagem de cliques e cache das últimas buscas.
- **Painel:** estações instáveis marcadas e levadas ao fim da lista; Anterior/Próxima corrigidos.
- **Build:** dependências Media3 em `android/app/build.gradle.kts` e em `tool/bootstrap_android.sh`.

## Pendente de confirmação

O ambiente de edição não tem Flutter, Kotlin nem acesso à internet. `flutter analyze`, `flutter test`, a resolução das dependências Media3 e a compilação Kotlin precisam ser confirmados pelo workflow, e o comportamento do player só em aparelho. Nenhuma lista fixa de estações foi embutida porque as URLs não puderam ser verificadas.
