import '../models/update_release.dart';

class UpdateNewsCatalog {
  const UpdateNewsCatalog(this.releases);

  final List<UpdateRelease> releases;

  /// A popup de Novidades e exclusiva da versao empacotada atual.
  /// O historico completo continua na tela Sobre > Mudancas.
  static const currentVersion =
      AppBuildVersion(version: '1.0.201', build: 201);

  static const current = UpdateNewsCatalog(<UpdateRelease>[
    UpdateRelease(
      version: AppBuildVersion(version: '1.0.201', build: 201),
      changes: <String>[
        'Teste das configurações do provedor de mapa agora inicializa o ambiente Flutter antes de acessar o armazenamento do aplicativo.',
        'Compatibilidade de testes reforçada sem alterar mapa atual, Google Maps, GPS, rotas, POIs ou mapas offline.',
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
