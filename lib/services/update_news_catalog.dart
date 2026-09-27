import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.188', build: 188);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.188', build: 188),
      changes: <String>[
        'Mapa com painel escuro de leitura rápida, locais próximos e rota no topo.',
        'Toque no nome de um local para abrir seus detalhes; adicione uma parada ou inicie a navegação pelo cartão.',
        'A tela de novidades aparece após a abertura inicial e aguarda sua confirmação.',
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
