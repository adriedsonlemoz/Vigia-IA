import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.161', build: 161),
      changes: <String>[
        '✨ Novidades da atualização agora mostra somente o que chegou nesta versão, sem misturar conteúdo de versões anteriores.',
        '🧾 O histórico completo continua disponível em Sobre > Mudanças, enquanto a popup fica curta e específica da atualização instalada.',
        '🗺️ A camada opcional de prédios da navegação 3D passa a usar somente APIs públicas de estilo do MapLibre, preservando o mapa vetorial e o acompanhamento.',
      ],
    ),
  ]);

  UpdateRelease? releaseFor(AppBuildVersion installed) {
    for (final release in releases) {
      if (release.version == installed) return release;
    }
    return null;
  }
}
