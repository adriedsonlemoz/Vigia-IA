import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.180', build: 180);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: currentVersion,
      changes: <String>[
        'O painel de navegação do mapa ficou maior e mais visual, com a próxima manobra em destaque, distância, tempo, média e progresso organizados em blocos.',
        'Durante a navegação, o card também mostra atalhos informativos para água, comida, descanso e parada quando esses pontos existem nos dados reais já carregados.',
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
