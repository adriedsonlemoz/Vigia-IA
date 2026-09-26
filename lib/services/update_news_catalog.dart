import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.176', build: 176);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: currentVersion,
      changes: <String>[
        'O Vigia IA agora pode aprender sua média de pedal com percursos Bike válidos gravados no aparelho.',
        'No planejamento de bicicleta, você pode usar a média aprendida no tempo estimado sem perder sua média manual.',
        'O histórico Bike pode ser limpo a qualquer momento pela própria tela de planejamento.',
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
