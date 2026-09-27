import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.199', build: 199);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.199', build: 199),
      changes: <String>[
        'Google Maps agora pode ser escolhido como provedor opcional sem remover o mapa atual.',
        'Satélite, híbrido, terreno, marcadores, pontos e rotas do Vigia acompanham o novo provedor.',
        'O mapa atual continua sendo o padrão e os mapas offline permanecem disponíveis.',
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
